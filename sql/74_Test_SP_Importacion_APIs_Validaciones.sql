/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 74_Test_SP_Importacion_APIs_Validaciones.sql
 Objetivo     : Testing de las validaciones de 72_SP_Importacion_APIs.sql (relacion
                1:1). Cada caso invalido muestra el numero de error y el mensaje. Al
                terminar vuelve a dejar el PBI de los paises como estaba.
 Requisito    : ejecutar despues de 73.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @paisesAntes TABLE (Orden INT IDENTITY(1, 1), IdPais INT, Codigo CHAR(3), Nombre VARCHAR(80), Confederacion VARCHAR(10),
                            Huso VARCHAR(60), Pib DECIMAL(18, 2), Anio INT);
INSERT INTO @paisesAntes (IdPais, Codigo, Nombre, Confederacion, Huso, Pib, Anio)
SELECT IdPais, CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib FROM Torneo.Pais;

DECLARE @i INT = 1, @n INT;
DECLARE @idPais INT, @codigo CHAR(3), @nombre VARCHAR(80), @confederacion VARCHAR(10), @huso VARCHAR(60), @pib DECIMAL(18, 2), @anio INT;
DECLARE @convertido DECIMAL(18, 2);

PRINT '=== Prueba 1: pais inexistente ===';
-- Resultado esperado: error 50001: "El pais indicado no existe."
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'XXX', @Contenido = '[]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: dentro de una transaccion abierta ===';
-- Resultado esperado: error 50001: "La importacion no se puede ejecutar dentro de una transaccion abierta."
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[]';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: el contenido no es JSON ===';
-- Resultado esperado: error 50003: "El contenido no es un JSON valido."
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = 'esto no es JSON';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: la API rechaza el codigo ===';
-- Resultado esperado: tabla de errores con el numero 50003 y el mensaje de la API; despues, error 50004.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA',
         @Contenido = '[{"message":[{"id":"120","key":"Invalid value","value":"The provided parameter value is not valid"}]}]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: la respuesta no trae datos del pais ===';
-- Resultado esperado: tabla de errores con "La respuesta de la API no trae datos de este pais."; despues, error 50004.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1,"total":0},null]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: valor que no es numerico ===';
-- Resultado esperado: tabla de errores con "El valor o el anio que trae la API no son numericos."; despues, error 50004.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2025","value":"abc"}]]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: el SP de la Entrega 5 rechaza un PBI negativo y un anio fuera de rango ===';
-- Resultado esperado: dos tablas de errores con el numero 50001: "El PIB per capita no puede ser negativo." y "Si se
-- informa el PIB, el anio debe estar entre 1960 y el anio actual."; despues de cada una, error 50004.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2025","value":-5}]]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    EXEC Importacion.usp_ImportarPib @CodigoIso3 = 'ITA', @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2099","value":100}]]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: importacion parcial entre varios paises ===';
-- Resultado esperado: Actualizadas 1 (ITA, con 12345.00) y el resto en la tabla de errores: NED con un valor no numerico
-- y los demas sin datos en la respuesta. Al final, error 50004.
BEGIN TRY
    EXEC Importacion.usp_ImportarPib
         @Contenido = '[{"page":1},[{"countryiso3code":"ITA","date":"2026","value":12345},{"countryiso3code":"NLD","date":"2026","value":"abc"}]]';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT CodigoIso3, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE CodigoIso3 IN ('ITA', 'NED') ORDER BY CodigoIso3;

PRINT '=== Prueba 9: varios datos invalidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: monto, moneda de origen y moneda de destino.
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = -1, @MonedaDestino = 'A1', @MonedaOrigen = 'XX';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: la misma moneda de origen y de destino ===';
-- Resultado esperado: error 50001: "La moneda de origen y la de destino deben ser distintas."
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = 100, @MonedaDestino = 'USD';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: la respuesta no es JSON ===';
-- Resultado esperado: error 50003: "La respuesta de la API no es un JSON valido."
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = 100, @MonedaDestino = 'ARS', @Contenido = 'no es JSON';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 12: la respuesta es de otras monedas ===';
-- Resultado esperado: error 50003: "La respuesta de la API no corresponde a USD y ARS."
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = 100, @MonedaDestino = 'ARS',
         @Contenido = '{"date":"2026-11-05","base":"USD","quote":"EUR","rate":0.9}';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: cotizacion invalida ===';
-- Resultado esperado: dos veces error 50003: "La respuesta de la API no trae una cotizacion y una fecha validas." MontoConvertido en NULL.
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = 100, @MonedaDestino = 'ARS', @MontoConvertido = @convertido OUTPUT,
         @Contenido = '{"date":"2026-11-05","base":"USD","quote":"ARS","rate":"abc"}';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje, @convertido AS MontoConvertido;
END CATCH
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = 100, @MonedaDestino = 'ARS', @MontoConvertido = @convertido OUTPUT,
         @Contenido = '{"date":"2026-11-05","base":"USD","quote":"ARS","rate":0}';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje, @convertido AS MontoConvertido;
END CATCH

PRINT '=== Prueba 14: moneda que la API no conoce ===';
-- Resultado esperado: error 50003: la API responde con un estado HTTP distinto de 200.
BEGIN TRY
    EXEC Importacion.usp_ConvertirMonto @Monto = 100, @MonedaDestino = 'ZZZ';
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
