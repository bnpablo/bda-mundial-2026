/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 65_Test_SP_Importacion_Comun_Validaciones.sql
 Objetivo     : Testing de las validaciones de 63_SP_Importacion_Comun.sql (relacion
                1:1). Cada caso invalido muestra el numero de error y el mensaje.
 Requisito    : ejecutar despues de 64.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @contenido VARCHAR(MAX), @respuesta VARCHAR(MAX);

PRINT '=== Prueba 1: nombre de archivo nulo ===';
-- Resultado esperado: error 50001: "El nombre del archivo es obligatorio."
BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = NULL, @Contenido = @contenido OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: nombre de archivo en blanco ===';
-- Resultado esperado: error 50001: "El nombre del archivo es obligatorio."
BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = '   ', @Contenido = @contenido OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: archivo inexistente ===';
-- Resultado esperado: error 50003: "No se pudo leer el archivo ...", con el detalle "File could not be opened."
BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\no_existe.csv', @Contenido = @contenido OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: carpeta inexistente ===';
-- Resultado esperado: error 50003 con el mismo detalle.
BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\CarpetaQueNoExiste\archivo.csv', @Contenido = @contenido OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: URL nula ===';
-- Resultado esperado: error 50001: "La URL es obligatoria."
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = NULL, @Respuesta = @respuesta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: URL sin http ===';
-- Resultado esperado: error 50001: "La URL debe empezar con http:// o https://."
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'api.frankfurter.dev/v2/rate/USD/ARS', @Respuesta = @respuesta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: servidor inexistente ===';
-- Resultado esperado: error 50003: "No se pudo consultar la URL ...".
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'https://servidor-que-no-existe.invalid/', @Respuesta = @respuesta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: la URL responde con un estado distinto de 200 ===';
-- Resultado esperado: error 50003: "La URL ... respondio con el estado HTTP 404."
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'https://api.frankfurter.dev/v2/no-existe', @Respuesta = @respuesta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: una respuesta larga se rechaza porque puede estar cortada ===';
-- Resultado esperado: error 50003: "La respuesta de la URL ... llega a 2048 bytes y puede estar cortada."
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'https://dossiermundial.netlify.app/', @Respuesta = @respuesta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO
