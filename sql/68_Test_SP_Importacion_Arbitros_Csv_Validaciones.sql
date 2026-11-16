/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-15
 Script       : 68_Test_SP_Importacion_Arbitros_Csv_Validaciones.sql
 Objetivo     : Testing de las validaciones de 66_SP_Importacion_Arbitros_Csv.sql
                (relacion 1:1). Cada caso invalido muestra el numero de error y el
                mensaje. Incluye la importacion con errores parciales.
                Cada prueba es un lote aparte y no usa variables de otra prueba: se
                puede ejecutar el script entero o seleccionar una prueba y ejecutarla
                sola. Las pruebas 8 y 9 quitan al final los arbitros de prueba que
                cargaron.
 Requisito    : ejecutar despues de 67 y de 51 (pais ITA y partido INC-P6, Colombia -
                Ecuador, que queda Programado). Se puede repetir. La prueba 8 usa
                Senegal como pais no cargado: despues de 99_Datos_Aceptacion.sql
                Senegal ya esta cargado y su resultado cambia (ver la prueba).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
GO

PRINT '=== Prueba 1: sin nombre de archivo ni contenido ===';
-- Resultado esperado: error 50001: "Hay que indicar el nombre del archivo o el contenido."
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 2: nombre de archivo y contenido a la vez ===';
-- Resultado esperado: error 50001: "Hay que indicar el nombre del archivo o el contenido, no los dos."
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\referees.csv', @Contenido = 'a,b';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 3: el archivo no es CSV ===';
-- Resultado esperado: error 50001: "El archivo debe tener extension .csv."
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\referees.xlsx';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 4: dentro de una transaccion abierta ===';
-- Resultado esperado: error 50001: "La importacion no se puede ejecutar dentro de una transaccion abierta."
DECLARE @enc VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @enc;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 5: archivo inexistente ===';
-- Resultado esperado: error 50003: "No se pudo leer el archivo ...".
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = 'C:\Importar\no_existe.csv';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 6: otro CSV, con encabezado distinto ===';
-- Resultado esperado: error 50003: "El encabezado del archivo no es el esperado...".
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = 'fecha,clae2,w_median';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 7: solo el encabezado ===';
-- Resultado esperado: error 50003: "El archivo no tiene filas de datos."
DECLARE @enc VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @enc;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO

PRINT '=== Prueba 8: importacion con errores parciales ===';
-- Resultado esperado: Leidas 10, Nuevas 1 (TEST-CSV-20) y ConError 9: 11 columnas; 3 columnas; codigo vacio; apellido y
-- nombre vacios; codigo repetido; pais sin equivalencia; pais no cargado; codigo de mas de 30 caracteres; comillas sin
-- cerrar (0 columnas). Al final, error 50004 y la lista de los arbitros de prueba que entraron.
-- Si ya se ejecuto 99_Datos_Aceptacion.sql, Senegal esta cargado y la fila 9 (TEST-CSV-25) entra: Nuevas 2 y ConError 8.
DECLARE @enc VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
DECLARE @resto VARCHAR(100) = ',CF-6,Union of European Football Associations,UEFA,not available';
DECLARE @texto VARCHAR(MAX), @idBaja INT;

SET @texto = @enc + CHAR(10)
           + '1,TEST-CSV-20,Valido,Uno,0,Italy' + @resto + CHAR(10)
           + '2,TEST-CSV-21,Perez,Juan,0,Italy' + @resto + ',extra' + CHAR(10)
           + '3,TEST-CSV-22,Gomez' + CHAR(10)
           + '4,,Lopez,Ana,1,Italy' + @resto + CHAR(10)
           + '5,TEST-CSV-23,,,0,Italy' + @resto + CHAR(10)
           + '6,TEST-CSV-20,Repetido,Dos,0,Italy' + @resto + CHAR(10)
           + '7,TEST-CSV-24,Ivanov,Lev,0,Soviet Union' + @resto + CHAR(10)
           + '8,TEST-CSV-25,Diop,Ali,0,Senegal' + @resto + CHAR(10)
           + '9,CODIGO-DE-MAS-DE-TREINTA-CARACTERES,Largo,Tres,0,Italy' + @resto + CHAR(10)
           + '10,TEST-CSV-26,"Sin cerrar,Cuatro,0,Italy' + @resto + CHAR(10);
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @texto;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT CodigoExterno, Nombre, Apellido FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%';

-- Limpieza: se quitan los arbitros de prueba que entraron.
WHILE EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%')
BEGIN
    SELECT @idBaja = MAX(IdArbitro) FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%';
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @idBaja;
END;
GO

PRINT '=== Prueba 9: conflicto de nacionalidad informado por el SP de modificacion ===';
-- Se da de alta un arbitro italiano (TEST-CSV-28) y se lo designa en INC-P6 (Colombia - Ecuador), que todavia no se
-- jugo. El archivo lo pasa a Colombia: quedaria dirigiendo a su propio pais, y el SP de modificacion de la Entrega 5
-- lo rechaza con el error 50002.
-- Resultado esperado: Leidas 2, Nuevas 1 y ConError 1, con el numero 50002. TEST-CSV-28 sigue en ITA y TEST-CSV-27
-- entra aunque esta despues de la fila que fallo. Al final, error 50004.
DECLARE @enc VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
DECLARE @resto VARCHAR(100) = ',CF-6,Union of European Football Associations,UEFA,not available';
DECLARE @texto VARCHAR(MAX), @idBaja INT, @idArbitro28 INT, @idDesignacion28 INT;
DECLARE @idPaisIta INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ITA');
DECLARE @idP6 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P6');

EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'TEST-CSV-28', @Nombre = 'Marco', @Apellido = 'Conflicto',
     @IdPais = @idPaisIta, @Categoria = 'FIFA', @IdArbitro = @idArbitro28 OUTPUT;
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @idP6, @IdArbitro = @idArbitro28, @RolArbitral = 'VAR',
     @IdDesignacion = @idDesignacion28 OUTPUT;

SET @texto = @enc + CHAR(10)
           + '1,TEST-CSV-28,Conflicto,Marco,0,Colombia' + @resto + CHAR(10)
           + '2,TEST-CSV-27,Despues,Cinco,0,Italy' + @resto + CHAR(10);
BEGIN TRY
    EXEC Importacion.usp_ImportarArbitrosCsv @Contenido = @texto;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT a.CodigoExterno, p.CodigoIso3 AS Pais
FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno IN ('TEST-CSV-27', 'TEST-CSV-28')
ORDER BY a.CodigoExterno;

-- Limpieza: se quita la designacion de prueba y despues los arbitros de prueba.
EXEC Arbitraje.usp_DesignacionArbitral_Baja @IdDesignacion = @idDesignacion28;

WHILE EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%')
BEGIN
    SELECT @idBaja = MAX(IdArbitro) FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%';
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @idBaja;
END;

-- Resultado esperado: 0.
SELECT COUNT(*) AS ArbitrosDePrueba FROM Arbitraje.Arbitro WHERE CodigoExterno LIKE 'TEST-CSV-%';
GO
