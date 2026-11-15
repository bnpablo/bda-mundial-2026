/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-14
 Script       : 67_Test_SP_Importacion_Arbitros_Csv_OK.sql
 Objetivo     : Testing exitoso de 66_SP_Importacion_Arbitros_Csv.sql (relacion 1:1).
                Sigue el orden de una importacion real:
                  Paso 0  estado inicial (sin arbitros importados)
                  Paso 1  la tabla antes de importar
                  Paso 2  importar el archivo y ver los arbitros cargados
                  Paso 3  importar el mismo archivo otra vez: no duplica
                  Paso 4  el mismo archivo con un arbitro mas: agrega solo ese
                  Paso 5  formato y modificacion, con un texto de prueba
                  Paso 6  limpieza de los datos que son solo de prueba
                Cada paso es un lote aparte y no usa variables de otro paso: se puede
                ejecutar el script entero o seleccionar un paso y ejecutarlo solo.
                El script se puede repetir: el paso 0 vuelve a dejar todo como al
                principio. Los arbitros del archivo real quedan cargados.
 Requisito    : ejecutar despues de 66 y de 51 (pais ITA). Debe existir
                C:\Importar\referees.csv.
 Cantidades   : dependen de los paises cargados, porque la importacion no crea paises.
                Con los paises de los tests anteriores (orden numerico): 156 nuevos y
                337 con error. Con los 31 paises de 99_Datos_Aceptacion.sql: 317 nuevos
                y 176 con error.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
GO

PRINT '=== Paso 0: estado inicial ===';
-- Quita los arbitros importados en una corrida anterior (codigo R-) y los de prueba (TEST-CSV-), salvo los que
-- tengan designaciones. Resultado esperado: Importados 0.
DECLARE @idBaja INT;
WHILE EXISTS (SELECT 1 FROM Arbitraje.Arbitro a
              WHERE (a.CodigoExterno LIKE 'R-%' OR a.CodigoExterno LIKE 'TEST-CSV-%')
                AND NOT EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral d WHERE d.IdArbitro = a.IdArbitro))
BEGIN
    SELECT @idBaja = MAX(a.IdArbitro)
    FROM Arbitraje.Arbitro a
    WHERE (a.CodigoExterno LIKE 'R-%' OR a.CodigoExterno LIKE 'TEST-CSV-%')
      AND NOT EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral d WHERE d.IdArbitro = a.IdArbitro);
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @idBaja;
END;
GO

PRINT '=== Paso 1: la tabla antes de importar ===';
-- Resultado esperado: Importados 0. EnLaTabla son los arbitros que cargaron otros scripts (3 despues del 51).
SELECT COUNT(*) AS EnLaTabla,
       ISNULL(SUM(CASE WHEN CodigoExterno LIKE 'R-%' THEN 1 ELSE 0 END), 0) AS Importados
FROM Arbitraje.Arbitro;
GO

PRINT '=== Paso 2: importar el archivo ===';
-- Resultado esperado: Leidas 493. Nuevas y ConError suman 493 (156 y 337, o 317 y 176: ver Cantidades).
-- Despues del resumen sale la lista de filas rechazadas, cada una con su motivo, y el error 50004, que avisa que
-- la importacion fue parcial. Importados pasa de 0 a la cantidad de Nuevas. Al final, los primeros 10 importados.
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\referees.csv';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT COUNT(*) AS EnLaTabla,
       ISNULL(SUM(CASE WHEN CodigoExterno LIKE 'R-%' THEN 1 ELSE 0 END), 0) AS Importados
FROM Arbitraje.Arbitro;

SELECT TOP (10) a.CodigoExterno, a.Apellido, a.Nombre, p.CodigoIso3 AS Pais, a.Categoria
FROM Arbitraje.Arbitro a
JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno LIKE 'R-%'
ORDER BY a.CodigoExterno;
GO

PRINT '=== Paso 3: importar el mismo archivo otra vez no duplica ===';
-- Resultado esperado: Nuevas 0 y SinCambios igual a las Nuevas del paso 2. EnLaTabla e Importados no cambian.
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\referees.csv';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT COUNT(*) AS EnLaTabla,
       ISNULL(SUM(CASE WHEN CodigoExterno LIKE 'R-%' THEN 1 ELSE 0 END), 0) AS Importados
FROM Arbitraje.Arbitro;
GO

PRINT '=== Paso 4: el mismo archivo con un arbitro mas ===';
-- Se lee el archivo, se le agrega al final la fila de un arbitro nuevo (R-900) y se importa ese contenido.
-- Resultado esperado: Leidas 494 y Nuevas 1; los demas quedan SinCambios o ConError como antes. Importados sube
-- en 1 y se ve el arbitro nuevo.
-- Para hacerlo a mano: pegar esta linea al final de C:\Importar\referees.csv y ejecutar de nuevo el paso 2.
-- 494,R-900,Prueba,Julio,0,Italy,CF-6,Union of European Football Associations,UEFA,not available
DECLARE @csv VARCHAR(MAX);
EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\referees.csv', @Contenido = @csv OUTPUT;
SET @csv = @csv + CHAR(10)
         + '494,R-900,Prueba,Julio,0,Italy,CF-6,Union of European Football Associations,UEFA,not available';

BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @csv;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT COUNT(*) AS EnLaTabla,
       ISNULL(SUM(CASE WHEN CodigoExterno LIKE 'R-%' THEN 1 ELSE 0 END), 0) AS Importados
FROM Arbitraje.Arbitro;

SELECT a.CodigoExterno, a.Apellido, a.Nombre, p.CodigoIso3 AS Pais, a.Categoria
FROM Arbitraje.Arbitro a
JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno = 'R-900';
GO

PRINT '=== Paso 5: formato y modificacion, con un texto de prueba ===';
-- Se importa un texto con 2 arbitros; el apellido del segundo tiene una coma entre comillas.
-- Resultado esperado: Leidas 2 y Nuevas 2. TEST-CSV-02 queda con el apellido "Rossi, Jr". Entran con categoria
-- FIFA y sin fecha de nacimiento, que el archivo no trae.
DECLARE @enc VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
DECLARE @texto VARCHAR(MAX), @idTest INT;
DECLARE @idPaisIta INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ITA');

SET @texto = @enc + CHAR(10)
           + '1,TEST-CSV-01,Bianchi,Luca,0,Italy,CF-6,Union of European Football Associations,UEFA,not available' + CHAR(10)
           + '2,TEST-CSV-02,"Rossi, Jr",Paolo,0,Italy,CF-6,Union of European Football Associations,UEFA,not available' + CHAR(13) + CHAR(10);
EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @texto;

SELECT a.CodigoExterno, a.Nombre, a.Apellido, p.CodigoIso3 AS Pais, a.Categoria, a.FechaNacimiento
FROM Arbitraje.Arbitro a
JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno LIKE 'TEST-CSV-%'
ORDER BY a.CodigoExterno;

-- Con el ABM se le carga a TEST-CSV-01 la categoria Confederacion y una fecha de nacimiento. Despues se importa
-- una fila suya con otro nombre (Lucas) y otro pais (Netherlands).
-- Resultado esperado: Leidas 1 y Actualizadas 1. TEST-CSV-01 queda con Lucas y NED, y conserva Confederacion y
-- 1980-05-20, que el archivo no trae.
SELECT @idTest = IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = 'TEST-CSV-01';
EXEC Arbitraje.usp_Arbitro_Modificacion @IdArbitro = @idTest, @CodigoExterno = 'TEST-CSV-01', @Nombre = 'Luca',
     @Apellido = 'Bianchi', @IdPais = @idPaisIta, @Categoria = 'Confederacion', @FechaNacimiento = '1980-05-20';

SET @texto = @enc + CHAR(10)
           + '1,TEST-CSV-01,Bianchi,Lucas,0,Netherlands,CF-6,Union of European Football Associations,UEFA,not available' + CHAR(10);
EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @texto;

SELECT a.CodigoExterno, a.Nombre, a.Apellido, p.CodigoIso3 AS Pais, a.Categoria, a.FechaNacimiento
FROM Arbitraje.Arbitro a
JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno = 'TEST-CSV-01';
GO

PRINT '=== Paso 6: limpieza de los datos de prueba ===';
-- Se dan de baja los arbitros que son solo de prueba: los TEST-CSV- y el R-900 del paso 4.
-- Resultado esperado: DePrueba 0. Importados vuelve a la cantidad del paso 2: los arbitros del archivo real quedan
-- cargados.
DECLARE @idBaja INT;
WHILE EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%' OR CodigoExterno = 'R-900')
BEGIN
    SELECT @idBaja = MAX(IdArbitro) FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%' OR CodigoExterno = 'R-900';
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @idBaja;
END;

SELECT COUNT(*) AS EnLaTabla,
       ISNULL(SUM(CASE WHEN CodigoExterno LIKE 'R-%' THEN 1 ELSE 0 END), 0) AS Importados,
       ISNULL(SUM(CASE WHEN CodigoExterno LIKE 'TEST-CSV-%' OR CodigoExterno = 'R-900' THEN 1 ELSE 0 END), 0) AS DePrueba
FROM Arbitraje.Arbitro;
GO
