/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-11
 Script       : 70_Test_SP_Importacion_Campanias_Xml_OK.sql
 Objetivo     : Testing exitoso de 69_SP_Importacion_Campanias_Xml.sql (relacion
                1:1). Al terminar elimina lo que cargo.
 Requisito    : ejecutar despues de 69 y de 51 (pais URY), en el orden numerico.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @maximoAnunciante INT = (SELECT ISNULL(MAX(IdAnunciante), 0) FROM Publicidad.Anunciante);
DECLARE @maximoCampania INT = (SELECT ISNULL(MAX(IdCampania), 0) FROM Publicidad.Campania);
DECLARE @maximoPieza INT = (SELECT ISNULL(MAX(IdPieza), 0) FROM Publicidad.Pieza);
DECLARE @anunciantesAntes INT = (SELECT COUNT(*) FROM Publicidad.Anunciante);
DECLARE @campaniasAntes INT = (SELECT COUNT(*) FROM Publicidad.Campania);
DECLARE @tres VARCHAR(MAX), @otra VARCHAR(MAX), @idBaja INT;

SET @tres = '<Campanias>'
          + '<Campania><Id>test-1</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Uno</Titulo></Campania>'
          + '<Campania><Id>test-2</Id><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Dos</Titulo></Campania>'
          + '<Campania><Id>test-3</Id><Anunciante>Test Bancos &amp; Seguros</Anunciante><Titulo>Test Campania Tres</Titulo></Campania>'
          + '</Campanias>';

PRINT '=== Prueba 1: alta de campanias desde un texto XML ===';
-- Resultado esperado: Leidas 3, Nuevas 3 y sin errores. Cada campania con fechas del Mundial y una pieza en 'es' de
-- 30 segundos, con URY como pais de interes. El &amp; se lee como &.
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @tres, @CodigoPais = 'URY';
SELECT a.Nombre AS Anunciante, c.Nombre AS Campania, c.FechaInicio, c.FechaFin, p.Idioma, p.DuracionSegundos, pa.CodigoIso3 AS Pais
FROM Publicidad.Campania c
JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
JOIN Publicidad.Pieza p ON p.IdCampania = c.IdCampania
JOIN Publicidad.PiezaPais pp ON pp.IdPieza = p.IdPieza
JOIN Torneo.Pais pa ON pa.IdPais = pp.IdPais
WHERE c.IdCampania > @maximoCampania
ORDER BY c.IdCampania;

PRINT '=== Prueba 2: importar lo mismo otra vez no genera duplicados ===';
-- Resultado esperado: Leidas 3, Nuevas 0 y SinCambios 3. Siguen 3 campanias y 2 anunciantes nuevos.
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @tres, @CodigoPais = 'URY';
SELECT (SELECT COUNT(*) FROM Publicidad.Campania WHERE IdCampania > @maximoCampania) AS CampaniasNuevas,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE IdAnunciante > @maximoAnunciante) AS AnunciantesNuevos;

PRINT '=== Prueba 3: una campania nueva de un anunciante que ya existe ===';
-- Resultado esperado: Leidas 2, Nuevas 1 y SinCambios 1. El anunciante no se repite: siguen 2 anunciantes nuevos.
SET @otra = '<Campanias>'
          + '<Campania><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Uno</Titulo></Campania>'
          + '<Campania><Anunciante>Test Bebidas</Anunciante><Titulo>Test Campania Cuatro</Titulo></Campania>'
          + '</Campanias>';
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @otra, @CodigoPais = 'URY';
SELECT (SELECT COUNT(*) FROM Publicidad.Campania WHERE IdCampania > @maximoCampania) AS CampaniasNuevas,
       (SELECT COUNT(*) FROM Publicidad.Anunciante WHERE IdAnunciante > @maximoAnunciante) AS AnunciantesNuevos;

PRINT '=== Prueba 4: un XML con declaracion, espacios y datos de mas ===';
-- Resultado esperado: Leidas 1 y Nuevas 1. Se ignoran la declaracion, los espacios y los elementos que no se usan.
SET @otra = '<?xml version="1.0" encoding="utf-8"?>' + CHAR(13) + CHAR(10)
          + '<Campanias><Campania><Id>test-5</Id><Anunciante>  Test Bebidas  </Anunciante>'
          + '<Titulo> Test Campania Cinco </Titulo><Agencia>Agencia</Agencia></Campania></Campanias>';
EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @otra, @CodigoPais = 'URY';
SELECT c.Nombre AS Campania, a.Nombre AS Anunciante
FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
WHERE c.Nombre = 'Test Campania Cinco';

WHILE EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza > @maximoPieza)
BEGIN
    SELECT @idBaja = MAX(IdPieza) FROM Publicidad.Pieza;
    EXEC Publicidad.usp_Pieza_Baja @IdPieza = @idBaja;
END;

WHILE EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdCampania > @maximoCampania)
BEGIN
    SELECT @idBaja = MAX(IdCampania) FROM Publicidad.Campania;
    EXEC Publicidad.usp_Campania_Baja @IdCampania = @idBaja;
END;

WHILE EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante > @maximoAnunciante)
BEGIN
    SELECT @idBaja = MAX(IdAnunciante) FROM Publicidad.Anunciante;
    EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = @idBaja;
END;

-- Resultado esperado: la misma cantidad de anunciantes y de campanias que antes de empezar el test.
SELECT @anunciantesAntes AS AnunciantesAntes, (SELECT COUNT(*) FROM Publicidad.Anunciante) AS AnunciantesDespues,
       @campaniasAntes AS CampaniasAntes, (SELECT COUNT(*) FROM Publicidad.Campania) AS CampaniasDespues;
GO
