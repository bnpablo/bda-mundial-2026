/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-11
 Script       : 80_Test_SP_Importacion_Scraping_Campanias_OK.sql
 Objetivo     : Testing exitoso de 79_SP_Importacion_Scraping_Campanias.sql
                (relacion 1:1). Escribe archivos de prueba en C:\Importar.
 Requisito    : ejecutar despues de 79. Sin C:\Importar\dossier.html, la prueba 4
                se omite.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @texto VARCHAR(MAX), @leido VARCHAR(MAX), @pagina VARCHAR(MAX), @hayArchivo BIT = 1;

BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\dossier.html', @Contenido = @pagina OUTPUT;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50003 THROW;
    SET @hayArchivo = 0;
END CATCH

PRINT '=== Prueba 1: guardar un archivo y volver a leerlo ===';
-- Resultado esperado: Iguales 1. Los acentos y la enie se conservan.
SET @texto = 'Campaña de prueba: año, acción, pingüino.';
EXEC Importacion.usp_GuardarArchivo @NombreArchivo = 'C:\Importar\prueba_guardar.txt', @Contenido = @texto;
EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\prueba_guardar.txt', @Contenido = @leido OUTPUT;
SELECT @leido AS Leido, CASE WHEN @leido = @texto THEN 1 ELSE 0 END AS Iguales;

PRINT '=== Prueba 2: scraping de un texto con la estructura de la pagina ===';
-- Resultado esperado: Campanias 2 y el archivo C:\Importar\prueba_scraping.xml. Las comillas y el \u00f1 del JSON
-- quedan bien en el XML.
SET @texto = '<html><head><script>const OTRA = 1; const CAMPANAS_INICIALES = ['
           + '{"id":"a","titulo":"Campa\u00f1a Uno","anunciante":"Marca A","marca":"","agencia":"Agencia A","productora":"","orden":1},'
           + '{"id":"b","titulo":"Campania \"Dos\"","anunciante":"Marca B & Hijos","marca":"B","agencia":"","productora":"Prod B","orden":2}];'
           + '</script></head><body></body></html>';
EXEC Importacion.usp_ScrapearCampanias @Contenido = @texto, @ArchivoXml = 'C:\Importar\prueba_scraping.xml';

PRINT '=== Prueba 3: el XML generado se puede leer con .nodes() ===';
-- Resultado esperado: 2 filas, en el orden de la pagina: Marca A con Campaña Uno y Marca B & Hijos con Campania "Dos".
EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\prueba_scraping.xml', @Contenido = @leido OUTPUT;
SELECT c.value('(Id/text())[1]', 'VARCHAR(200)') AS Id,
       c.value('(Anunciante/text())[1]', 'VARCHAR(200)') AS Anunciante,
       c.value('(Titulo/text())[1]', 'VARCHAR(200)') AS Titulo
FROM (SELECT CAST(@leido AS XML) AS Documento) d
CROSS APPLY d.Documento.nodes('/Campanias/Campania') AS t(c);

PRINT '=== Prueba 4: scraping de la pagina real descargada ===';
-- Resultado esperado: la cantidad de campanias de la pagina y el archivo C:\Importar\campanias.xml. Despues, las
-- primeras 5 campanias leidas del archivo.
IF @hayArchivo = 1
BEGIN
    BEGIN TRY
        EXEC Importacion.usp_ScrapearCampanias @ArchivoHtml = 'C:\Importar\dossier.html', @ArchivoXml = 'C:\Importar\campanias.xml';
        EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\campanias.xml', @Contenido = @leido OUTPUT;
        SELECT TOP 5 c.value('(Anunciante/text())[1]', 'VARCHAR(200)') AS Anunciante,
                     c.value('(Titulo/text())[1]', 'VARCHAR(200)') AS Titulo
        FROM (SELECT CAST(@leido AS XML) AS Documento) d
        CROSS APPLY d.Documento.nodes('/Campanias/Campania') AS t(c);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
    END CATCH
END
ELSE
    SELECT 'Prueba omitida: falta C:\Importar\dossier.html' AS Resultado;
GO
