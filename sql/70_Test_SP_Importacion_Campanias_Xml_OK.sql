/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-14
 Script       : 70_Test_SP_Importacion_Campanias_Xml_OK.sql
 Objetivo     : Testing exitoso de 69_SP_Importacion_Campanias_Xml.sql (relacion
                1:1), con un XML de prueba escrito en el script. Sigue el orden de
                una importacion:
                  Paso 0  estado inicial (sin campanias de prueba)
                  Paso 1  las tablas antes de importar
                  Paso 2  importar 3 campanias y verlas cargadas
                  Paso 3  importar lo mismo otra vez: no duplica
                  Paso 4  el mismo XML con una campania mas: agrega solo esa
                  Paso 5  un XML con declaracion, espacios y datos de mas
                  Paso 6  vuelta al estado inicial
                Cada paso es un lote aparte y no usa variables de otro paso: se puede
                ejecutar el script entero o un paso solo. Los anunciantes de prueba
                empiezan con "Test": asi se reconocen y se quitan al terminar.
                La importacion del XML real, el que genera el scraping, esta en
                80_Test_SP_Importacion_Scraping_Campanias_OK.sql.
 Requisito    : ejecutar despues de 69 y de 51 (pais URY).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
GO

PRINT '=== Paso 0: estado inicial ===';
-- Quita las campanias de prueba que hayan quedado de una corrida anterior. Resultado esperado: DePrueba 0.
DECLARE @idBaja INT;
WHILE EXISTS (SELECT 1 FROM Publicidad.Pieza p JOIN Publicidad.Campania c ON c.IdCampania = p.IdCampania
              JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'Test %')
BEGIN
    SELECT @idBaja = MAX(p.IdPieza) FROM Publicidad.Pieza p JOIN Publicidad.Campania c ON c.IdCampania = p.IdCampania
    JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'Test %';
    EXEC Publicidad.usp_Pieza_Baja @IdPieza = @idBaja;
END;
WHILE EXISTS (SELECT 1 FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
              WHERE a.Nombre LIKE 'Test %')
BEGIN
    SELECT @idBaja = MAX(c.IdCampania) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
    WHERE a.Nombre LIKE 'Test %';
    EXEC Publicidad.usp_Campania_Baja @IdCampania = @idBaja;
END;
WHILE EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %')
BEGIN
    SELECT @idBaja = MAX(IdAnunciante) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %';
    EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = @idBaja;
END;
GO

PRINT '=== Paso 1: las tablas antes de importar ===';
-- Resultado esperado: CampaniasDePrueba 0 y AnunciantesDePrueba 0. Campanias y Anunciantes son los de otros scripts.
SELECT (SELECT COUNT(*) FROM Publicidad.Campania) AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
        WHERE a.Nombre LIKE 'Test %') AS CampaniasDePrueba,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %') AS AnunciantesDePrueba;
GO

PRINT '=== Paso 2: importar 3 campanias ===';
-- Resultado esperado: Leidas 3, Nuevas 3 y sin errores. CampaniasDePrueba 3 y AnunciantesDePrueba 2. Cada campania
-- queda con las fechas del Mundial y una pieza en 'es' de 30 segundos, con URY como pais de interes. El &amp; del
-- XML se lee como &.
DECLARE @xml VARCHAR(MAX) = '<Campanias>'
    + '<Campania><Id>test-1</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Uno</Titulo></Campania>'
    + '<Campania><Id>test-2</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Dos</Titulo></Campania>'
    + '<Campania><Id>test-3</Id><Anunciante>Test Bancos &amp; Seguros</Anunciante><Titulo>Test Campania Tres</Titulo></Campania>'
    + '</Campanias>';
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @xml, @CodigoPais = 'URY';

SELECT (SELECT COUNT(*) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
        WHERE a.Nombre LIKE 'Test %') AS CampaniasDePrueba,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %') AS AnunciantesDePrueba;

SELECT a.Nombre AS Anunciante, c.Nombre AS Campania, c.FechaInicio, c.FechaFin, p.Idioma, p.DuracionSegundos, pa.CodigoIso3 AS Pais
FROM Publicidad.Campania c
JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
JOIN Publicidad.Pieza p ON p.IdCampania = c.IdCampania
JOIN Publicidad.PiezaPais pp ON pp.IdPieza = p.IdPieza
JOIN Torneo.Pais pa ON pa.IdPais = pp.IdPais
WHERE a.Nombre LIKE 'Test %'
ORDER BY c.IdCampania;
GO

PRINT '=== Paso 3: importar lo mismo otra vez no duplica ===';
-- Resultado esperado: Leidas 3, Nuevas 0 y SinCambios 3. Siguen CampaniasDePrueba 3 y AnunciantesDePrueba 2.
DECLARE @xml VARCHAR(MAX) = '<Campanias>'
    + '<Campania><Id>test-1</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Uno</Titulo></Campania>'
    + '<Campania><Id>test-2</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Dos</Titulo></Campania>'
    + '<Campania><Id>test-3</Id><Anunciante>Test Bancos &amp; Seguros</Anunciante><Titulo>Test Campania Tres</Titulo></Campania>'
    + '</Campanias>';
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @xml, @CodigoPais = 'URY';

SELECT (SELECT COUNT(*) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
        WHERE a.Nombre LIKE 'Test %') AS CampaniasDePrueba,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %') AS AnunciantesDePrueba;
GO

PRINT '=== Paso 4: el mismo XML con una campania mas ===';
-- Se agrega al final una cuarta campania, de un anunciante que ya existe.
-- Resultado esperado: Leidas 4, Nuevas 1 y SinCambios 3. CampaniasDePrueba 4. El anunciante no se repite: siguen
-- AnunciantesDePrueba 2.
DECLARE @xml VARCHAR(MAX) = '<Campanias>'
    + '<Campania><Id>test-1</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Uno</Titulo></Campania>'
    + '<Campania><Id>test-2</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Dos</Titulo></Campania>'
    + '<Campania><Id>test-3</Id><Anunciante>Test Bancos &amp; Seguros</Anunciante><Titulo>Test Campania Tres</Titulo></Campania>'
    + '<Campania><Id>test-4</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Cuatro</Titulo></Campania>'
    + '</Campanias>';
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @xml, @CodigoPais = 'URY';

SELECT (SELECT COUNT(*) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
        WHERE a.Nombre LIKE 'Test %') AS CampaniasDePrueba,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %') AS AnunciantesDePrueba;
GO

PRINT '=== Paso 5: un XML con declaracion, espacios y datos de mas ===';
-- Resultado esperado: Leidas 1 y Nuevas 1. Se ignoran la declaracion, los espacios y los elementos que no se usan.
-- Queda "Test Campania Cinco" de "Test Bebidas".
DECLARE @xml VARCHAR(MAX) = '<?xml version="1.0" encoding="utf-8"?>' + CHAR(13) + CHAR(10)
    + '<Campanias><Campania><Id>test-5</Id><Anunciante>  Test Bebidas  </Anunciante>'
    + '<Titulo> Test Campania Cinco </Titulo><Agencia>Agencia</Agencia></Campania></Campanias>';
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @xml, @CodigoPais = 'URY';

SELECT c.Nombre AS Campania, a.Nombre AS Anunciante
FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
WHERE c.Nombre = 'Test Campania Cinco';
GO

PRINT '=== Paso 6: vuelta al estado inicial ===';
-- Se dan de baja las piezas, las campanias y los anunciantes de prueba, con los SP de la Entrega 5.
-- Resultado esperado: CampaniasDePrueba 0 y AnunciantesDePrueba 0. Campanias y Anunciantes, como en el paso 1.
DECLARE @idBaja INT;
WHILE EXISTS (SELECT 1 FROM Publicidad.Pieza p JOIN Publicidad.Campania c ON c.IdCampania = p.IdCampania
              JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'Test %')
BEGIN
    SELECT @idBaja = MAX(p.IdPieza) FROM Publicidad.Pieza p JOIN Publicidad.Campania c ON c.IdCampania = p.IdCampania
    JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante WHERE a.Nombre LIKE 'Test %';
    EXEC Publicidad.usp_Pieza_Baja @IdPieza = @idBaja;
END;
WHILE EXISTS (SELECT 1 FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
              WHERE a.Nombre LIKE 'Test %')
BEGIN
    SELECT @idBaja = MAX(c.IdCampania) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
    WHERE a.Nombre LIKE 'Test %';
    EXEC Publicidad.usp_Campania_Baja @IdCampania = @idBaja;
END;
WHILE EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %')
BEGIN
    SELECT @idBaja = MAX(IdAnunciante) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %';
    EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = @idBaja;
END;

SELECT (SELECT COUNT(*) FROM Publicidad.Campania) AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
        WHERE a.Nombre LIKE 'Test %') AS CampaniasDePrueba,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE Nombre LIKE 'Test %') AS AnunciantesDePrueba;
GO
