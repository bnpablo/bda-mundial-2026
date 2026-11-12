/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 67_Test_SP_Importacion_Arbitros_Csv_OK.sql
 Objetivo     : Testing exitoso de 66_SP_Importacion_Arbitros_Csv.sql (relacion 1:1).
                Al terminar elimina los arbitros que cargo.
 Requisito    : ejecutar despues de 66 y de 51 (paises ITA, URY y NED), en el orden
                numerico. Debe existir C:\Importar\referees.csv.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @enc VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
DECLARE @maximoAntes INT = (SELECT ISNULL(MAX(IdArbitro), 0) FROM Arbitraje.Arbitro);
DECLARE @cantidadAntes INT = (SELECT COUNT(*) FROM Arbitraje.Arbitro);
DECLARE @tres VARCHAR(MAX), @cambio VARCHAR(MAX), @idTest INT, @idPaisIta INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ITA');
DECLARE @idBaja INT;

SET @tres = @enc + CHAR(10)
          + '1,TEST-CSV-01,Bianchi,Luca,0,Italy,CF-6,Union of European Football Associations,UEFA,not available' + CHAR(10)
          + '2,TEST-CSV-02,"Rossi, Jr",Paolo,0,Italy,CF-6,Union of European Football Associations,UEFA,not available' + CHAR(13) + CHAR(10)
          + '3,TEST-CSV-03,Pereira,Mario,0,Uruguay,CF-4,"Confederacion, de prueba",CONMEBOL,not available' + CHAR(10);

PRINT '=== Prueba 1: alta de arbitros desde un texto CSV ===';
-- Resultado esperado: Leidas 3, Nuevas 3 y sin errores. El apellido de TEST-CSV-02 conserva la coma. Categoria FIFA.
EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @tres;
SELECT a.CodigoExterno, a.Nombre, a.Apellido, p.CodigoIso3 AS Pais, a.Categoria, a.FechaNacimiento
FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno LIKE 'TEST-CSV-%'
ORDER BY a.CodigoExterno;

PRINT '=== Prueba 2: importar lo mismo otra vez no genera duplicados ===';
-- Resultado esperado: Leidas 3, Nuevas 0, Actualizadas 0 y SinCambios 3. Siguen siendo 3 arbitros.
EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @tres;
SELECT COUNT(*) AS ArbitrosDePrueba FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%';

PRINT '=== Prueba 3: una modificacion conserva los datos que el archivo no trae ===';
-- Resultado esperado: Actualizadas 1. TEST-CSV-01 queda con Lucas, NED, Confederacion y la fecha 1980-05-20.
SELECT @idTest = IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = 'TEST-CSV-01';
EXEC Arbitraje.usp_Arbitro_Modificacion @IdArbitro = @idTest, @CodigoExterno = 'TEST-CSV-01', @Nombre = 'Luca', @Apellido = 'Bianchi',
     @IdPais = @idPaisIta, @Categoria = 'Confederacion', @FechaNacimiento = '1980-05-20';
SET @cambio = @enc + CHAR(10)
            + '1,TEST-CSV-01,Bianchi,Lucas,0,Netherlands,CF-6,Union of European Football Associations,UEFA,not available' + CHAR(10);
EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @cambio;
SELECT a.CodigoExterno, a.Nombre, a.Apellido, p.CodigoIso3 AS Pais, a.Categoria, a.FechaNacimiento
FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno = 'TEST-CSV-01';

PRINT '=== Prueba 4: importar el archivo real, con el nombre como parametro ===';
-- Resultado esperado: Leidas 493 y Nuevas + ConError = 493. Al final, error 50004.
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\referees.csv';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT TOP 5 a.CodigoExterno, a.Nombre, a.Apellido, p.CodigoIso3 AS Pais
FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno LIKE 'R-%' AND a.Apellido LIKE 'A%'
ORDER BY a.CodigoExterno;

PRINT '=== Prueba 5: la importacion real tampoco duplica ===';
-- Resultado esperado: Nuevas 0, y la misma cantidad de arbitros con codigo R- antes y despues.
SELECT COUNT(*) AS ArbitrosRealesAntes FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'R-%';
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\referees.csv';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT COUNT(*) AS ArbitrosRealesDespues FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'R-%';

WHILE EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE IdArbitro > @maximoAntes)
BEGIN
    SELECT @idBaja = MAX(IdArbitro) FROM Arbitraje.Arbitro;
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @idBaja;
END;

-- Resultado esperado: la misma cantidad de arbitros que antes de empezar el test.
SELECT @cantidadAntes AS CantidadAntes, COUNT(*) AS CantidadDespues FROM Arbitraje.Arbitro;
GO
