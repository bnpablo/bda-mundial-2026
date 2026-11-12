/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 73_Test_SP_Importacion_APIs_OK.sql
 Objetivo     : Testing exitoso de 72_SP_Importacion_APIs.sql (relacion 1:1). Al
                terminar vuelve a dejar el PBI de los paises como estaba.
 Requisito    : ejecutar despues de 72, de 51 (paises ITA, NED y POR) y de 61 (tarifa),
                en el orden numerico.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @paisesAntes TABLE (Orden INT IDENTITY(1, 1), IdPais INT, Codigo CHAR(3), Nombre VARCHAR(80), Confederacion VARCHAR(10),
                            Huso VARCHAR(60), Pib DECIMAL(18, 2), Anio INT);
INSERT INTO @paisesAntes (IdPais, Codigo, Nombre, Confederacion, Huso, Pib, Anio)
SELECT IdPais, CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib FROM Torneo.Pais;

DECLARE @api VARCHAR(MAX) = '[{"page":1},['
    + '{"countryiso3code":"ITA","date":"2024","value":40000.5},'
    + '{"countryiso3code":"NLD","date":"2024","value":70000.25},'
    + '{"countryiso3code":"PRT","date":"2024","value":30000.75}]]';
DECLARE @i INT = 1, @n INT;
DECLARE @idPais INT, @codigo CHAR(3), @nombre VARCHAR(80), @confederacion VARCHAR(10), @huso VARCHAR(60), @pib DECIMAL(18, 2), @anio INT;
DECLARE @monto DECIMAL(18, 2), @convertido DECIMAL(18, 2), @cotizacion DECIMAL(18, 8), @fecha DATE;

PRINT '=== Prueba 1: actualizar el PBI de un pais ===';
-- Resultado esperado: Leidas 1, Actualizadas 1 y sin errores. ITA queda con 40000.50 y el anio 2024.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = @api;
SELECT CodigoIso3, Nombre, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';

PRINT '=== Prueba 2: importar lo mismo otra vez no cambia nada ===';
-- Resultado esperado: Actualizadas 0 y SinCambios 1.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = @api;

PRINT '=== Prueba 3: los codigos FIFA NED y POR se buscan como NLD y PRT ===';
-- Resultado esperado: Actualizadas 1 en cada uno. NED queda con 70000.25 y POR con 30000.75.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'NED', @Contenido = @api;
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'POR', @Contenido = @api;
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 IN ('NED', 'POR') ORDER BY CodigoIso3;

PRINT '=== Prueba 4: un dato de un anio anterior no pisa uno mas nuevo ===';
-- Resultado esperado: Actualizadas 0 y SinCambios 1. ITA sigue con 40000.50 y el anio 2024.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2020","value":1000}]]';
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';

PRINT '=== Prueba 5: un dato mas nuevo o corregido se aplica, y conserva el resto del pais ===';
-- Resultado esperado: Actualizadas 1 en cada uno. ITA queda con 42000.00 y el anio 2025, con su nombre, confederacion y huso.
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2025","value":41000}]]';
EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2025","value":42000}]]';
SELECT CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';

PRINT '=== Prueba 6: convertir un monto con una cotizacion fija ===';
-- Resultado esperado: 1000.00 USD a 1500.5 da 1500500.00 ARS, con fecha 2026-11-05.
EXEC Importacion.usp_ConvertirMonto @Monto = 1000, @MonedaDestino = 'ARS', @MontoConvertido = @convertido OUTPUT,
     @Cotizacion = @cotizacion OUTPUT, @FechaCotizacion = @fecha OUTPUT,
     @Contenido = '{"date":"2026-11-05","base":"USD","quote":"ARS","rate":1500.5}';
SELECT 1000.00 AS Monto, @cotizacion AS Cotizacion, @fecha AS Fecha, @convertido AS MontoConvertido;

PRINT '=== Prueba 7: PBI real de un pais ===';
-- Resultado esperado: sin errores. ARG queda con el valor que informa la API.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ARG';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 = 'ARG';

PRINT '=== Prueba 8: PBI real de todos los paises cargados ===';
-- Resultado esperado: Leidas igual a la cantidad de paises y ConError 0, incluidos NED y POR.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais ORDER BY CodigoIso3;

PRINT '=== Prueba 9: convertir una tarifa real de USD a ARS y a EUR, con la cotizacion del momento ===';
-- Resultado esperado: el monto de la tarifa en cada moneda, con la cotizacion y su fecha.
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

SELECT @n = COUNT(*) FROM @paisesAntes;
WHILE @i <= @n
BEGIN
    SELECT @idPais = IdPais, @codigo = Codigo, @nombre = Nombre, @confederacion = Confederacion, @huso = Huso, @pib = Pib, @anio = Anio
    FROM @paisesAntes WHERE Orden = @i;
    EXEC Torneo.usp_Pais_Modificacion @IdPais = @idPais, @CodigoIso3 = @codigo, @Nombre = @nombre, @Confederacion = @confederacion,
         @HusoHorario = @huso, @PibPerCapitaUsd = @pib, @AnioPib = @anio;
    SET @i += 1;
END;

-- Resultado esperado: 0 paises con un PBI distinto del que tenian antes del test.
SELECT COUNT(*) AS PaisesDistintos
FROM @paisesAntes a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE ISNULL(a.Pib, -1) <> ISNULL(p.PibPerCapitaUsd, -1) OR ISNULL(a.Anio, -1) <> ISNULL(p.AnioPib, -1);
GO
