/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-11
 Script       : 79_SP_Importacion_Scraping_Campanias.sql
 Objetivo     : Scraping de las campanias publicitarias del Mundial publicadas en
                https://dossiermundial.netlify.app/:
                  Importacion.usp_GuardarArchivo     guarda un texto en un archivo.
                  Importacion.usp_ScrapearCampanias  extrae las campanias de la
                                                     pagina descargada y las guarda
                                                     en un archivo XML.
 Prerrequisito: 63_SP_Importacion_Comun.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Importacion.usp_GuardarArchivo
 Guarda @Contenido en @NombreArchivo con ADODB.Stream, en UTF-8. Si el archivo ya
 existe, lo reemplaza. Error 50003 si no se pudo guardar.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_GuardarArchivo
    @NombreArchivo VARCHAR(260),
    @Contenido     VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- De a 4000 caracteres, igual que usp_LeerArchivo.
    DECLARE @caracteresPorEscritura INT = 4000;
    -- 2: crea el archivo o reemplaza el que existe.
    DECLARE @reemplazar INT = 2;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @objeto INT, @hr INT = 0, @posicion BIGINT = 1, @largo BIGINT;
    DECLARE @trozo VARCHAR(8000), @fuente VARCHAR(255), @descripcion VARCHAR(255), @mensaje VARCHAR(2000);

    IF @NombreArchivo IS NULL OR LTRIM(RTRIM(@NombreArchivo)) = ''
        SET @errores += 'El nombre del archivo es obligatorio. ';

    IF @Contenido IS NULL OR @Contenido = ''
        SET @errores += 'El contenido a guardar es obligatorio. ';

    IF (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') = 0
        SET @errores += 'Ole Automation Procedures esta deshabilitado: ejecutar 07_Configuracion_Importacion.sql. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SET @largo = DATALENGTH(@Contenido);

    -- Los sp_OA* no generan una excepcion: devuelven @hr, por eso cada paso corre solo si el anterior funciono.
    EXEC @hr = sp_OACreate 'ADODB.Stream', @objeto OUT;
    IF @hr = 0 EXEC @hr = sp_OASetProperty @objeto, 'Type', 2;
    IF @hr = 0 EXEC @hr = sp_OASetProperty @objeto, 'Charset', 'utf-8';
    IF @hr = 0 EXEC @hr = sp_OAMethod @objeto, 'Open';

    WHILE @hr = 0 AND @posicion <= @largo
    BEGIN
        SET @trozo = SUBSTRING(@Contenido, @posicion, @caracteresPorEscritura);
        EXEC @hr = sp_OAMethod @objeto, 'WriteText', NULL, @trozo;
        SET @posicion += @caracteresPorEscritura;
    END;

    IF @hr = 0 EXEC @hr = sp_OAMethod @objeto, 'SaveToFile', NULL, @NombreArchivo, @reemplazar;

    IF @hr <> 0
    BEGIN
        EXEC sp_OAGetErrorInfo @objeto, @fuente OUT, @descripcion OUT;
        SET @mensaje = 'No se pudo guardar el archivo ' + @NombreArchivo + '. Detalle: ' + ISNULL(@descripcion, 'sin detalle') + ' ';
    END

    IF @objeto IS NOT NULL
        EXEC sp_OADestroy @objeto;

    IF @mensaje IS NOT NULL
        THROW 50003, @mensaje, 1;
END
GO

/*------------------------------------------------------------------------------
 Importacion.usp_ScrapearCampanias
 Recibe la pagina ya descargada (@ArchivoHtml) o su texto (@Contenido, para
 probar sin archivo) y genera @ArchivoXml con un elemento Campania por campania.
 - La pagina no tiene tablas: las campanias estan en un arreglo JSON de su codigo,
   asignado a CAMPANAS_INICIALES. Se recorta ese arreglo y se lee con OPENJSON.
 - El XML se arma con FOR XML y se guarda con usp_GuardarArchivo.
 Errores: 50001 parametros invalidos; 50003 archivo inaccesible o pagina con otra
 estructura.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_ScrapearCampanias
    @ArchivoHtml VARCHAR(260) = NULL,
    @ArchivoXml  VARCHAR(260) = NULL,
    @Contenido   VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @marca VARCHAR(50) = 'CAMPANAS_INICIALES';
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @posicionMarca BIGINT, @inicio BIGINT, @fin BIGINT, @cantidad INT;
    DECLARE @json VARCHAR(MAX), @xml VARCHAR(MAX);

    IF @ArchivoHtml IS NULL AND @Contenido IS NULL
        SET @errores += 'Hay que indicar el archivo de la pagina o su contenido. ';
    ELSE IF @ArchivoHtml IS NOT NULL AND @Contenido IS NOT NULL
        SET @errores += 'Hay que indicar el archivo de la pagina o su contenido, no los dos. ';
    ELSE IF @ArchivoHtml IS NOT NULL AND RIGHT(RTRIM(@ArchivoHtml), 5) <> '.html'
        SET @errores += 'El archivo de la pagina debe tener extension .html. ';

    IF @ArchivoXml IS NULL OR LTRIM(RTRIM(@ArchivoXml)) = ''
        SET @errores += 'El nombre del archivo XML a generar es obligatorio. ';
    ELSE IF RIGHT(RTRIM(@ArchivoXml), 4) <> '.xml'
        SET @errores += 'El archivo a generar debe tener extension .xml. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @ArchivoHtml IS NOT NULL
        EXEC Importacion.usp_LeerArchivo @NombreArchivo = @ArchivoHtml, @Contenido = @Contenido OUTPUT;

    -- El arreglo empieza en el primer [ despues de la marca y termina en el primer }]; que le sigue.
    SET @posicionMarca = CHARINDEX(@marca, @Contenido);
    IF @posicionMarca > 0
        SET @inicio = CHARINDEX('[', @Contenido, @posicionMarca);
    IF @inicio > 0
        SET @fin = CHARINDEX('}];', @Contenido, @inicio);

    IF ISNULL(@fin, 0) = 0
        THROW 50003, 'No se encontro el arreglo de campanias: la pagina cambio su estructura. ', 1;

    SET @json = SUBSTRING(@Contenido, @inicio, @fin - @inicio + 2);

    IF ISJSON(@json) = 0
        THROW 50003, 'El arreglo de campanias no es un JSON valido: la pagina cambio su estructura. ', 1;

    SELECT @cantidad = COUNT(*) FROM OPENJSON(@json);

    SET @xml = CAST((SELECT j.Id, j.Anunciante, j.Titulo, j.Marca, j.Agencia, j.Productora
                     FROM OPENJSON(@json) WITH (
                              Id         VARCHAR(200) '$.id',
                              Anunciante VARCHAR(200) '$.anunciante',
                              Titulo     VARCHAR(200) '$.titulo',
                              Marca      VARCHAR(200) '$.marca',
                              Agencia    VARCHAR(200) '$.agencia',
                              Productora VARCHAR(200) '$.productora',
                              Orden      INT          '$.orden') j
                     ORDER BY j.Orden
                     FOR XML PATH('Campania'), ROOT('Campanias'), TYPE) AS VARCHAR(MAX));

    EXEC Importacion.usp_GuardarArchivo @NombreArchivo = @ArchivoXml, @Contenido = @xml;

    SELECT @cantidad AS Campanias, @ArchivoXml AS ArchivoGenerado;
END
GO
