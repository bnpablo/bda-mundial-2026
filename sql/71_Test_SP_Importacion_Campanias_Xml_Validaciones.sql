/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-11
 Script       : 71_Test_SP_Importacion_Campanias_Xml_Validaciones.sql
 Objetivo     : Testing de las validaciones de 69_SP_Importacion_Campanias_Xml.sql
                (relacion 1:1). Cada caso invalido muestra el numero de error y el
                mensaje. Incluye la importacion con errores parciales. Al terminar
                elimina lo que cargo.
 Requisito    : ejecutar despues de 70.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @maximoAnunciante INT = (SELECT ISNULL(MAX(IdAnunciante), 0) FROM Publicidad.Anunciante);
DECLARE @maximoCampania INT = (SELECT ISNULL(MAX(IdCampania), 0) FROM Publicidad.Campania);
DECLARE @maximoPieza INT = (SELECT ISNULL(MAX(IdPieza), 0) FROM Publicidad.Pieza);
DECLARE @texto VARCHAR(MAX), @idBaja INT;

PRINT '=== Prueba 1: sin nombre de archivo ni contenido ===';
-- Resultado esperado: error 50001: "Hay que indicar el nombre del archivo o el contenido."
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: nombre de archivo y contenido a la vez ===';
-- Resultado esperado: error 50001: "Hay que indicar el nombre del archivo o el contenido, no los dos."
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @NombreArchivo = 'C:\Importar\campanias.xml', @Contenido = '<Campanias/>';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: el archivo no es XML y el pais de interes no existe ===';
-- Resultado esperado: error 50001 con 2 condiciones: la extension .xml y el pais XXX no cargado.
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @NombreArchivo = 'C:\Importar\campanias.csv', @CodigoPais = 'XXX';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: dentro de una transaccion abierta ===';
-- Resultado esperado: error 50001: "La importacion no se puede ejecutar dentro de una transaccion abierta."
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Importacion.usp_ImportarCampaniasXml @Contenido = '<Campanias/>', @CodigoPais = 'URY';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: archivo inexistente ===';
-- Resultado esperado: error 50003: "No se pudo leer el archivo ...".
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @NombreArchivo = 'C:\Importar\no_existe.xml', @CodigoPais = 'URY';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: el contenido no es un XML valido ===';
-- Resultado esperado: error 50003: "El contenido no es un XML valido."
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @Contenido = '<Campanias><Campania>sin cerrar', @CodigoPais = 'URY';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: un XML con otra estructura ===';
-- Resultado esperado: error 50003: "El XML no tiene la estructura esperada...".
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @Contenido = '<Arbitros><Arbitro>Uno</Arbitro></Arbitros>', @CodigoPais = 'URY';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: importacion con errores parciales ===';
-- Resultado esperado: Leidas 5, Nuevas 1 y ConError 4. En la tabla de errores: anunciante vacio, titulo vacio,
-- anunciante de mas de 120 caracteres y titulo de mas de 120 caracteres. Al final, error 50004.
SET @texto = '<Campanias>'
           + '<Campania><Anunciante>Test Parcial</Anunciante><Titulo>Test Campania Valida</Titulo></Campania>'
           + '<Campania><Anunciante></Anunciante><Titulo>Test Sin Anunciante</Titulo></Campania>'
           + '<Campania><Anunciante>Test Parcial</Anunciante></Campania>'
           + '<Campania><Anunciante>' + REPLICATE('A', 121) + '</Anunciante><Titulo>Test Anunciante Largo</Titulo></Campania>'
           + '<Campania><Anunciante>Test Parcial</Anunciante><Titulo>' + REPLICATE('T', 121) + '</Titulo></Campania>'
           + '</Campanias>';
BEGIN TRY
    EXEC Importacion.usp_ImportarCampaniasXml @Contenido = @texto, @CodigoPais = 'URY';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT c.Nombre AS CampaniaCargada FROM Publicidad.Campania c WHERE c.IdCampania > @maximoCampania;

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
GO
