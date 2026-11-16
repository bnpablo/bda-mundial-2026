/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-14
 Script       : 73_Test_SP_Importacion_APIs_OK.sql
 Objetivo     : Testing exitoso de 72_SP_Importacion_APIs.sql (relacion 1:1).
                Sigue el orden de una importacion, con la API real del Banco Mundial:
                  Paso 1  estado inicial: los paises sin PBI
                  Paso 2  importar el PBI real de un pais y verlo cargado
                  Paso 3  importar otra vez: no cambia nada
                  Paso 4  importar todos los paises: se completan solo los que faltan
                  Paso 5  casos con datos fijos (codigos, anios y conservacion)
                  Paso 6  conversion de moneda, fija y con la cotizacion real
                  Paso 7  vuelta al PBI que tenia cada pais
                Cada paso es un lote aparte. Se puede ejecutar el script entero o un
                paso solo; el paso 7 necesita que antes se haya ejecutado el paso 1
                en la misma ventana, porque el paso 1 guarda en #pibInicio el PBI que
                tenia cada pais. Para repetir la secuencia desde el principio,
                ejecutar antes el paso 7.
                El PBI importado no queda cargado: es un criterio para asignar la
                publicidad y cambiaria los resultados de los tests de publicidad (97)
                y de los datos de aceptacion (99).
 Requisito    : ejecutar despues de 72, de 11 (pais ARG), de 51 (paises ITA, NED y
                POR) y de 61 (tarifa). Los pasos 2, 3, 4 y 6 necesitan internet. El
                paso 4 hace una consulta por pais: si la API no responde para alguno,
                ese pais queda como error con su motivo y los demas se cargan.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
GO

PRINT '=== Paso 1: estado inicial, los paises sin PBI ===';
-- Se guarda en #pibInicio el PBI que tiene cada pais, para devolverlo en el paso 7, y se deja a todos sin PBI
-- con el SP de modificacion de pais.
-- Resultado esperado: ConPbi 0.
DROP TABLE IF EXISTS #pibInicio;
SELECT IdPais, PibPerCapitaUsd AS Pib, AnioPib AS Anio
INTO #pibInicio
FROM Torneo.Pais;

DECLARE @idPais INT = 0, @codigo CHAR(3), @nombre VARCHAR(80), @confederacion VARCHAR(10), @huso VARCHAR(60);
WHILE EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais > @idPais AND PibPerCapitaUsd IS NOT NULL)
BEGIN
    SELECT @idPais = MIN(IdPais) FROM Torneo.Pais WHERE IdPais > @idPais AND PibPerCapitaUsd IS NOT NULL;
    SELECT @codigo = CodigoIso3, @nombre = Nombre, @confederacion = Confederacion, @huso = HusoHorario
    FROM Torneo.Pais WHERE IdPais = @idPais;
    EXEC Torneo.usp_Pais_Modificacion @IdPais = @idPais, @CodigoIso3 = @codigo, @Nombre = @nombre,
         @Confederacion = @confederacion, @HusoHorario = @huso, @PibPerCapitaUsd = NULL, @AnioPib = NULL;
END;

SELECT COUNT(*) AS Paises, ISNULL(SUM(CASE WHEN PibPerCapitaUsd IS NOT NULL THEN 1 ELSE 0 END), 0) AS ConPbi FROM Torneo.Pais;
GO

PRINT '=== Paso 2: importar el PBI real de un pais ===';
-- Resultado esperado: Leidas 1, Actualizadas 1 y sin errores. ARG queda con el valor y el anio que informa la API.
-- ConPbi 1.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ARG';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT CodigoIso3, Nombre, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ARG';
SELECT COUNT(*) AS Paises, ISNULL(SUM(CASE WHEN PibPerCapitaUsd IS NOT NULL THEN 1 ELSE 0 END), 0) AS ConPbi FROM Torneo.Pais;
GO

PRINT '=== Paso 3: importar otra vez no cambia nada ===';
-- Resultado esperado: Leidas 1, Actualizadas 0 y SinCambios 1. ARG sigue con el mismo valor y ConPbi sigue en 1.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ARG';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT CodigoIso3, Nombre, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ARG';
SELECT COUNT(*) AS Paises, ISNULL(SUM(CASE WHEN PibPerCapitaUsd IS NOT NULL THEN 1 ELSE 0 END), 0) AS ConPbi FROM Torneo.Pais;
GO

PRINT '=== Paso 4: importar todos los paises completa solo los que faltan ===';
-- Resultado esperado: Leidas igual a la cantidad de paises. SinCambios 1 (ARG, que ya estaba) y Actualizadas en
-- el resto, incluidos NED y POR, que la API conoce como NLD y PRT. ConPbi igual a Paises.
-- Si la API no responde para algun pais, ese pais sale en la lista de errores con su motivo, ConError lo cuenta
-- y al final aparece el error 50004 (importacion parcial).
BEGIN TRY
    EXEC Importacion.usp_ImportarPib;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT CodigoIso3, Nombre, PibPerCapitaUsd, AnioPib FROM Torneo.Pais ORDER BY CodigoIso3;
SELECT COUNT(*) AS Paises, ISNULL(SUM(CASE WHEN PibPerCapitaUsd IS NOT NULL THEN 1 ELSE 0 END), 0) AS ConPbi FROM Torneo.Pais;
GO

PRINT '=== Paso 5: casos con datos fijos ===';
-- En lugar de consultar la API se pasa la respuesta en @Contenido, para que el resultado sea siempre el mismo.
DECLARE @api VARCHAR(MAX) = '[{"page":1},['
    + '{"countryiso3code":"ITA","date":"2025","value":40000.5},'
    + '{"countryiso3code":"NLD","date":"2025","value":70000.25},'
    + '{"countryiso3code":"PRT","date":"2025","value":30000.75}]]';

-- 5.1 Resultado esperado: Actualizadas 1. ITA queda con 40000.50 y el anio 2025.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = @api;
SELECT CodigoIso3, Nombre, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';

-- 5.2 Los codigos FIFA NED y POR se buscan como NLD y PRT.
-- Resultado esperado: Actualizadas 1 en cada uno. NED queda con 70000.25 y POR con 30000.75.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'NED', @Contenido = @api;
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'POR', @Contenido = @api;
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 IN ('NED', 'POR') ORDER BY CodigoIso3;

-- 5.3 Un dato de un anio anterior no pisa uno mas nuevo.
-- Resultado esperado: Actualizadas 0 y SinCambios 1. ITA sigue con 40000.50 y el anio 2025.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2020","value":1000}]]';
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';

-- 5.4 Un dato mas nuevo, o corregido para el mismo anio, se aplica y conserva el resto del pais.
-- Resultado esperado: Actualizadas 1 en cada uno. ITA queda con 42000.00 y el anio 2026, con su nombre, su
-- confederacion y su huso horario.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2026","value":41000}]]';
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2026","value":42000}]]';
SELECT CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';
GO

PRINT '=== Paso 6: conversion de moneda ===';
DECLARE @monto DECIMAL(18, 2), @convertido DECIMAL(18, 2), @cotizacion DECIMAL(18, 8), @fecha DATE;

-- 6.1 Con una cotizacion fija. Resultado esperado: 1000.00 USD a 1500.5 da 1500500.00 ARS, con fecha 2026-11-05.
EXEC Importacion.usp_ConvertirMonto @Monto = 1000, @MonedaDestino = 'ARS', @MontoConvertido = @convertido OUTPUT,
     @Cotizacion = @cotizacion OUTPUT, @FechaCotizacion = @fecha OUTPUT,
     @Contenido = '{"date":"2026-11-05","base":"USD","quote":"ARS","rate":1500.5}';
SELECT 1000.00 AS Monto, @cotizacion AS Cotizacion, @fecha AS Fecha, @convertido AS MontoConvertido;

-- 6.2 Una tarifa real, de USD a ARS y a EUR, con la cotizacion del momento (API de Frankfurter).
-- Resultado esperado: el monto de la tarifa en cada moneda, con la cotizacion y su fecha. No se guarda nada.
BEGIN TRY
    SELECT TOP 1 @monto = Monto FROM Publicidad.TarifaPublicitaria WHERE Moneda = 'USD' ORDER BY IdTarifa;
    EXEC Importacion.usp_ConvertirMonto @Monto = @monto, @MonedaDestino = 'ARS', @MontoConvertido = @convertido OUTPUT,
         @Cotizacion = @cotizacion OUTPUT, @FechaCotizacion = @fecha OUTPUT;
    SELECT @monto AS TarifaUsd, 'ARS' AS Moneda, @cotizacion AS Cotizacion, @fecha AS Fecha, @convertido AS MontoConvertido;
    EXEC Importacion.usp_ConvertirMonto @Monto = @monto, @MonedaDestino = 'EUR', @MontoConvertido = @convertido OUTPUT,
         @Cotizacion = @cotizacion OUTPUT, @FechaCotizacion = @fecha OUTPUT;
    SELECT @monto AS TarifaUsd, 'EUR' AS Moneda, @cotizacion AS Cotizacion, @fecha AS Fecha, @convertido AS MontoConvertido;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Paso 7: vuelta al PBI que tenia cada pais ===';
-- Cada pais vuelve al PBI que tenia antes del paso 1, con el SP de modificacion de pais.
-- Resultado esperado: PaisesDistintos 0.
IF OBJECT_ID('tempdb..#pibInicio') IS NULL
    SELECT 'Falta ejecutar el paso 1 en esta ventana: no se sabe que PBI tenia cada pais.' AS Aviso;
ELSE
BEGIN
    DECLARE @idPais INT = 0, @codigo CHAR(3), @nombre VARCHAR(80), @confederacion VARCHAR(10), @huso VARCHAR(60);
    DECLARE @pib DECIMAL(18, 2), @anio INT;

    WHILE EXISTS (SELECT 1 FROM #pibInicio i JOIN Torneo.Pais p ON p.IdPais = i.IdPais WHERE i.IdPais > @idPais)
    BEGIN
        SELECT @idPais = MIN(i.IdPais) FROM #pibInicio i JOIN Torneo.Pais p ON p.IdPais = i.IdPais WHERE i.IdPais > @idPais;

        SELECT @codigo = p.CodigoIso3, @nombre = p.Nombre, @confederacion = p.Confederacion, @huso = p.HusoHorario,
               @pib = i.Pib, @anio = i.Anio
        FROM Torneo.Pais p
        JOIN #pibInicio i ON i.IdPais = p.IdPais
        WHERE p.IdPais = @idPais;

        EXEC Torneo.usp_Pais_Modificacion @IdPais = @idPais, @CodigoIso3 = @codigo, @Nombre = @nombre,
             @Confederacion = @confederacion, @HusoHorario = @huso, @PibPerCapitaUsd = @pib, @AnioPib = @anio;
    END;

    SELECT COUNT(*) AS PaisesDistintos
    FROM #pibInicio i JOIN Torneo.Pais p ON p.IdPais = i.IdPais
    WHERE ISNULL(i.Pib, -1) <> ISNULL(p.PibPerCapitaUsd, -1) OR ISNULL(i.Anio, -1) <> ISNULL(p.AnioPib, -1);

    DROP TABLE #pibInicio;
END;
GO
