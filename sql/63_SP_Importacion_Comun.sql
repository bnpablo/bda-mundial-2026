/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 63_SP_Importacion_Comun.sql
 Objetivo     : Procedimientos que comparten los procesos de importacion:
                  Importacion.usp_LeerArchivo  devuelve un archivo como texto.
                  Importacion.usp_ObtenerUrl   devuelve la respuesta de una URL.
 Prerrequisito: 07_Configuracion_Importacion.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Importacion.usp_LeerArchivo
 Lee un archivo de texto UTF-8 con ADODB.Stream, que recibe la ruta en una
 variable: no hace falta SQL dinamico. El objeto corre con la cuenta del servicio,
 que tiene que poder leer el archivo. Error 50003 si no se puede leer o esta vacio.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_LeerArchivo
    @NombreArchivo VARCHAR(260),
    @Contenido     VARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- De a 4000 caracteres: una variable de salida no admite textos largos e INSERT ... EXEC los corta en 2048 bytes.
    DECLARE @caracteresPorLectura INT = 4000;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @objeto INT, @hr INT = 0, @finArchivo INT = 0;
    DECLARE @trozo VARCHAR(8000), @fuente VARCHAR(255), @descripcion VARCHAR(255), @mensaje VARCHAR(2000);

    SET @Contenido = '';

    IF @NombreArchivo IS NULL OR LTRIM(RTRIM(@NombreArchivo)) = ''
        SET @errores += 'El nombre del archivo es obligatorio. ';

    IF (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') = 0
        SET @errores += 'Ole Automation Procedures esta deshabilitado: ejecutar 07_Configuracion_Importacion.sql. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    -- Los sp_OA* no generan una excepcion: devuelven @hr, por eso cada paso corre solo si el anterior funciono.
    EXEC @hr = sp_OACreate 'ADODB.Stream', @objeto OUT;
    IF @hr = 0 EXEC @hr = sp_OASetProperty @objeto, 'Type', 2;
    IF @hr = 0 EXEC @hr = sp_OASetProperty @objeto, 'Charset', 'utf-8';
    IF @hr = 0 EXEC @hr = sp_OAMethod @objeto, 'Open';
    IF @hr = 0 EXEC @hr = sp_OAMethod @objeto, 'LoadFromFile', NULL, @NombreArchivo;
    IF @hr = 0 EXEC @hr = sp_OAGetProperty @objeto, 'EOS', @finArchivo OUT;

    WHILE @hr = 0 AND @finArchivo = 0
    BEGIN
        EXEC @hr = sp_OAMethod @objeto, 'ReadText', @trozo OUT, @caracteresPorLectura;
        IF @hr = 0
        BEGIN
            SET @Contenido += @trozo;
            EXEC @hr = sp_OAGetProperty @objeto, 'EOS', @finArchivo OUT;
        END
    END;

    IF @hr <> 0
    BEGIN
        EXEC sp_OAGetErrorInfo @objeto, @fuente OUT, @descripcion OUT;
        SET @mensaje = 'No se pudo leer el archivo ' + @NombreArchivo + '. Detalle: ' + ISNULL(@descripcion, 'sin detalle') + ' ';
    END
    ELSE IF @Contenido = ''
        SET @mensaje = 'El archivo ' + @NombreArchivo + ' esta vacio. ';

    IF @objeto IS NOT NULL
        EXEC sp_OADestroy @objeto;

    IF @mensaje IS NOT NULL
        THROW 50003, @mensaje, 1;
END
GO

/*------------------------------------------------------------------------------
 Importacion.usp_ObtenerUrl
 Hace un GET con MSXML2.XMLHTTP. Error 50003 si no se pudo hacer el pedido, el
 estado HTTP no es 200 o la respuesta esta vacia o puede estar cortada.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_ObtenerUrl
    @Url       VARCHAR(400),
    @Respuesta VARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @largoMaximo INT = 2048;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @objeto INT, @hr INT = 0, @estado INT;
    DECLARE @fuente VARCHAR(255), @descripcion VARCHAR(255), @mensaje VARCHAR(2000);
    DECLARE @tmpRespuesta TABLE (Texto VARCHAR(MAX));

    SET @Respuesta = NULL;

    IF @Url IS NULL OR LTRIM(RTRIM(@Url)) = ''
        SET @errores += 'La URL es obligatoria. ';
    ELSE IF @Url NOT LIKE 'http://%' AND @Url NOT LIKE 'https://%'
        SET @errores += 'La URL debe empezar con http:// o https://. ';

    IF (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') = 0
        SET @errores += 'Ole Automation Procedures esta deshabilitado: ejecutar 07_Configuracion_Importacion.sql. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    EXEC @hr = sp_OACreate 'MSXML2.XMLHTTP', @objeto OUT;
    IF @hr = 0 EXEC @hr = sp_OAMethod @objeto, 'open', NULL, 'GET', @Url, 'false';
    IF @hr = 0 EXEC @hr = sp_OAMethod @objeto, 'send';
    IF @hr = 0 EXEC @hr = sp_OAGetProperty @objeto, 'status', @estado OUT;

    IF @hr = 0 AND @estado = 200
    BEGIN
        INSERT INTO @tmpRespuesta (Texto)
        EXEC @hr = sp_OAGetProperty @objeto, 'responseText';

        SELECT @Respuesta = Texto FROM @tmpRespuesta;
    END;

    IF @hr <> 0
    BEGIN
        EXEC sp_OAGetErrorInfo @objeto, @fuente OUT, @descripcion OUT;
        SET @mensaje = 'No se pudo consultar la URL ' + @Url + '. Detalle: ' + ISNULL(@descripcion, 'sin detalle') + ' ';
    END
    ELSE IF @estado <> 200
        SET @mensaje = 'La URL ' + @Url + ' respondio con el estado HTTP ' + CAST(@estado AS VARCHAR(5)) + '. ';
    ELSE IF ISNULL(@Respuesta, '') = ''
        SET @mensaje = 'La URL ' + @Url + ' devolvio una respuesta vacia. ';
    -- INSERT ... EXEC corta el texto en 2048 bytes: una respuesta de ese largo puede estar incompleta.
    ELSE IF DATALENGTH(@Respuesta) >= @largoMaximo
        SET @mensaje = 'La respuesta de la URL ' + @Url + ' llega a ' + CAST(@largoMaximo AS VARCHAR(5)) + ' bytes y puede estar cortada. ';

    IF @objeto IS NOT NULL
        EXEC sp_OADestroy @objeto;

    IF @mensaje IS NOT NULL
    BEGIN
        SET @Respuesta = NULL;
        THROW 50003, @mensaje, 1;
    END
END
GO
