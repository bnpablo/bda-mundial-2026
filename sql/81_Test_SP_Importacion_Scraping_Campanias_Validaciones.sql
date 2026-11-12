/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-11
 Script       : 81_Test_SP_Importacion_Scraping_Campanias_Validaciones.sql
 Objetivo     : Testing de las validaciones de 79_SP_Importacion_Scraping_Campanias.sql
                (relacion 1:1). Cada caso invalido muestra el numero de error y el
                mensaje.
 Requisito    : ejecutar despues de 80.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

PRINT '=== Prueba 1: guardar sin nombre de archivo ni contenido ===';
-- Resultado esperado: error 50001 con 2 condiciones: el nombre y el contenido son obligatorios.
BEGIN TRY
    EXEC Importacion.usp_GuardarArchivo @NombreArchivo = '  ', @Contenido = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: guardar en una carpeta inexistente ===';
-- Resultado esperado: error 50003: "No se pudo guardar el archivo ...".
BEGIN TRY
    EXEC Importacion.usp_GuardarArchivo @NombreArchivo = 'C:\CarpetaQueNoExiste\archivo.xml', @Contenido = '<a/>';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: scraping sin pagina, sin contenido y sin archivo XML ===';
-- Resultado esperado: error 50001 con 2 condiciones: falta la pagina o su contenido, y falta el archivo XML.
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: archivo de la pagina y contenido a la vez ===';
-- Resultado esperado: error 50001: "Hay que indicar el archivo de la pagina o su contenido, no los dos."
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias @ArchivoHtml = 'C:\Importar\dossier.html', @Contenido = 'x',
         @ArchivoXml = 'C:\Importar\prueba_scraping.xml';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: extensiones equivocadas ===';
-- Resultado esperado: error 50001 con 2 condiciones: la pagina debe ser .html y el archivo a generar, .xml.
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias @ArchivoHtml = 'C:\Importar\dossier.txt', @ArchivoXml = 'C:\Importar\campanias.csv';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: archivo de la pagina inexistente ===';
-- Resultado esperado: error 50003: "No se pudo leer el archivo ...".
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias @ArchivoHtml = 'C:\Importar\no_existe.html', @ArchivoXml = 'C:\Importar\prueba_scraping.xml';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: una pagina sin el arreglo de campanias ===';
-- Resultado esperado: error 50003: "No se encontro el arreglo de campanias: la pagina cambio su estructura."
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias @Contenido = '<html><body><table><tr><td>Otra pagina</td></tr></table></body></html>',
         @ArchivoXml = 'C:\Importar\prueba_scraping.xml';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: el arreglo no es un JSON valido ===';
-- Resultado esperado: error 50003: "El arreglo de campanias no es un JSON valido: la pagina cambio su estructura."
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias @Contenido = '<script>const CAMPANAS_INICIALES = [{id: a, titulo: sin comillas}];</script>',
         @ArchivoXml = 'C:\Importar\prueba_scraping.xml';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO
