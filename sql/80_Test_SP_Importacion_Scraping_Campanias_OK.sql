/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-14
 Script       : 80_Test_SP_Importacion_Scraping_Campanias_OK.sql
 Objetivo     : Testing exitoso de 79_SP_Importacion_Scraping_Campanias.sql
                (relacion 1:1) y de la importacion completa de las campanias reales:
                la pagina descargada pasa a un XML y ese XML se importa.
                  Paso 1  guardar un archivo y volver a leerlo
                  Paso 2  scraping de un texto de prueba
                  Paso 3  las tablas antes de importar
                  Paso 4  scraping de la pagina real e importacion del XML generado
                  Paso 5  importar el mismo XML otra vez: no duplica
                  Paso 6  el mismo XML con una campania mas: agrega solo esa
                  Paso 7  vuelta al estado inicial
                Cada paso es un lote aparte. Se puede ejecutar el script entero o un
                paso solo; el paso 7 necesita que antes se haya ejecutado el paso 3
                en la misma ventana, porque el paso 3 anota en #inicio hasta donde
                llegaban las tablas. Para repetir la secuencia desde el principio,
                ejecutar antes el paso 7.
                Las campanias importadas no quedan cargadas: compiten por los espacios
                de los partidos y cambiarian los resultados de los tests de
                publicidad (97) y de los datos de aceptacion (99).
 Requisito    : ejecutar despues de 79 y de 69. Deben existir el pais ARG y
                C:\Importar\dossier.html. Escribe archivos en C:\Importar.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
GO

PRINT '=== Paso 1: guardar un archivo y volver a leerlo ===';
-- Resultado esperado: Iguales 1. Los acentos y la enie se conservan.
DECLARE @texto VARCHAR(MAX) = 'Campaña de prueba: año, acción, pingüino.', @leido VARCHAR(MAX);
EXEC Importacion.usp_GuardarArchivo @NombreArchivo = 'C:\Importar\prueba_guardar.txt', @Contenido = @texto;
EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\prueba_guardar.txt', @Contenido = @leido OUTPUT;
SELECT @leido AS Leido, CASE WHEN @leido = @texto THEN 1 ELSE 0 END AS Iguales;
GO

PRINT '=== Paso 2: scraping de un texto de prueba ===';
-- El texto tiene la misma estructura que la pagina: un arreglo JSON dentro del codigo.
-- Resultado esperado: Campanias 2 y el archivo C:\Importar\prueba_scraping.xml. Al leer el XML salen 2 filas, en
-- el orden de la pagina: Marca A con Campaña Uno y Marca B & Hijos con Campania "Dos". Las comillas y el \u00f1
-- del JSON quedan bien en el XML.
DECLARE @texto VARCHAR(MAX), @leido VARCHAR(MAX);
SET @texto = '<html><head><script>const OTRA = 1; const CAMPANAS_INICIALES = ['
           + '{"id":"a","titulo":"Campa\u00f1a Uno","anunciante":"Marca A","marca":"","agencia":"Agencia A","productora":"","orden":1},'
           + '{"id":"b","titulo":"Campania \"Dos\"","anunciante":"Marca B & Hijos","marca":"B","agencia":"","productora":"Prod B","orden":2}];'
           + '</script></head><body></body></html>';
EXEC Importacion.usp_ScrapearCampanias @Contenido = @texto, @ArchivoXml = 'C:\Importar\prueba_scraping.xml';

EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\prueba_scraping.xml', @Contenido = @leido OUTPUT;
SELECT c.value('(Id/text())[1]', 'VARCHAR(200)') AS Id,
       c.value('(Anunciante/text())[1]', 'VARCHAR(200)') AS Anunciante,
       c.value('(Titulo/text())[1]', 'VARCHAR(200)') AS Titulo
FROM (SELECT CAST(@leido AS XML) AS Documento) d
CROSS APPLY d.Documento.nodes('/Campanias/Campania') AS t(c);
GO

PRINT '=== Paso 3: las tablas antes de importar ===';
-- Se anota en #inicio el ultimo Id de cada tabla, para poder volver a este estado en el paso 7.
-- Resultado esperado: las cantidades que dejaron otros scripts.
DROP TABLE IF EXISTS #inicio;
SELECT (SELECT ISNULL(MAX(IdAnunciante), 0) FROM Publicidad.Anunciante) AS MaxAnunciante,
       (SELECT ISNULL(MAX(IdCampania), 0) FROM Publicidad.Campania)     AS MaxCampania,
       (SELECT ISNULL(MAX(IdPieza), 0) FROM Publicidad.Pieza)           AS MaxPieza
INTO #inicio;

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania)   AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza)      AS Piezas;
GO

PRINT '=== Paso 4: scraping de la pagina real e importacion del XML generado ===';
-- Resultado esperado: el scraping informa las campanias de la pagina (24 al 14/11/2026) y genera
-- C:\Importar\campanias.xml. La importacion de ese archivo da Leidas 24, Nuevas 24 y sin errores. Las tres
-- cantidades suben: 24 campanias, 24 piezas y un anunciante por cada marca nueva (21). Al final, las ultimas 10
-- campanias cargadas, con las fechas del Mundial.
BEGIN TRY
    EXEC Importacion.usp_ScrapearCampanias @ArchivoHtml = 'C:\Importar\dossier.html', @ArchivoXml = 'C:\Importar\campanias.xml';
    EXEC Importacion.usp_ImportarCampaniasXml @NombreArchivo = 'C:\Importar\campanias.xml';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania)   AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza)      AS Piezas;

SELECT TOP (10) a.Nombre AS Anunciante, c.Nombre AS Campania, c.FechaInicio, c.FechaFin
FROM Publicidad.Campania c
JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
ORDER BY c.IdCampania DESC;
GO

PRINT '=== Paso 5: importar el mismo XML otra vez no duplica ===';
-- Resultado esperado: Leidas 24, Nuevas 0 y SinCambios 24. Las tres cantidades quedan igual que en el paso 4.
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @NombreArchivo = 'C:\Importar\campanias.xml';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania)   AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza)      AS Piezas;
GO

PRINT '=== Paso 6: el mismo XML con una campania mas ===';
-- Se lee el XML generado, se le agrega una campania al final y se importa ese contenido.
-- Resultado esperado: Leidas 25, Nuevas 1 y SinCambios 24. Suben en 1 las tres cantidades y se ve la campania nueva.
-- Para hacerlo a mano: pegar este elemento antes de </Campanias> en C:\Importar\campanias.xml y ejecutar el paso 5.
-- <Campania><Anunciante>Anunciante Nuevo</Anunciante><Titulo>Campania agregada</Titulo></Campania>
DECLARE @xml VARCHAR(MAX);
BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\campanias.xml', @Contenido = @xml OUTPUT;
    SET @xml = REPLACE(@xml, '</Campanias>',
               '<Campania><Anunciante>Anunciante Nuevo</Anunciante><Titulo>Campania agregada</Titulo></Campania></Campanias>');
    EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @xml;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania)   AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza)      AS Piezas;

SELECT a.Nombre AS Anunciante, c.Nombre AS Campania, c.FechaInicio, c.FechaFin
FROM Publicidad.Campania c
JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
WHERE c.Nombre = 'Campania agregada';
GO

PRINT '=== Paso 7: vuelta al estado inicial ===';
-- Se da de baja, con los SP de la Entrega 5, todo lo que se cargo despues del paso 3.
-- Resultado esperado: las mismas cantidades que en el paso 3.
IF OBJECT_ID('tempdb..#inicio') IS NULL
    SELECT 'Falta ejecutar el paso 3 en esta ventana: no se sabe hasta donde llegaban las tablas.' AS Aviso;
ELSE
BEGIN
    DECLARE @idBaja INT;
    WHILE EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza > (SELECT MaxPieza FROM #inicio))
    BEGIN
        SELECT @idBaja = MAX(IdPieza) FROM Publicidad.Pieza;
        EXEC Publicidad.usp_Pieza_Baja @IdPieza = @idBaja;
    END;
    WHILE EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdCampania > (SELECT MaxCampania FROM #inicio))
    BEGIN
        SELECT @idBaja = MAX(IdCampania) FROM Publicidad.Campania;
        EXEC Publicidad.usp_Campania_Baja @IdCampania = @idBaja;
    END;
    WHILE EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante > (SELECT MaxAnunciante FROM #inicio))
    BEGIN
        SELECT @idBaja = MAX(IdAnunciante) FROM Publicidad.Anunciante;
        EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = @idBaja;
    END;
    DROP TABLE #inicio;
END;

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania)   AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza)      AS Piezas;
GO
