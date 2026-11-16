/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 72_SP_Importacion_APIs.sql
 Objetivo     : Procesos que consumen APIs externas:
                  Importacion.usp_ImportarPib     actualiza el PBI per capita de los
                                                  paises (API del Banco Mundial).
                  Importacion.usp_ConvertirMonto  convierte un monto con la cotizacion
                                                  del momento (API Frankfurter).
 Prerrequisito: 10_SP_ABM_Torneo.sql y 63_SP_Importacion_Comun.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Importacion.usp_ImportarPib
 Hace una llamada a la API por cada pais de Torneo.Pais: usp_ObtenerUrl solo
 admite respuestas de menos de 2048 bytes.
 - @CodigoIso3 limita el proceso a un pais. @Contenido reemplaza la respuesta de
   la API, para probar con datos fijos.
 - Solo actualiza paises, con usp_Pais_Modificacion: Nuevas siempre vale 0. Un PBI
   de un anio anterior al guardado no se aplica.
 Errores: 50001 parametros invalidos; 50003 contenido invalido; 50004 importacion
 parcial. Los errores de cada pais se anotan en #errores y el proceso sigue.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_ImportarPib
    @CodigoIso3 VARCHAR(10)  = NULL,
    @Contenido  VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @urlInicio VARCHAR(100) = 'https://api.worldbank.org/v2/country/';
    -- per_page=1: para algunos paises la API ignora mrnev y devuelve toda la serie, del anio mas nuevo al mas viejo.
    DECLARE @urlFin VARCHAR(100) = '/indicator/NY.GDP.PCAP.CD?format=json&mrnev=1&per_page=1';

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @i INT = 1, @cantidadPaises INT;
    DECLARE @actualizadas INT = 0, @sinCambios INT = 0, @conError INT;
    DECLARE @mensaje VARCHAR(2000), @url VARCHAR(400), @respuesta VARCHAR(MAX), @filasApi INT;

    DECLARE @idPais INT, @codigo CHAR(3), @codigoConsulta CHAR(3), @nombre VARCHAR(80), @confederacion VARCHAR(10);
    DECLARE @huso VARCHAR(60), @pibActual DECIMAL(18, 2), @anioActual INT;

    DECLARE @valorTexto VARCHAR(40), @anioTexto VARCHAR(10), @pib DECIMAL(18, 2), @anio INT;

    -- Sin transaccion general: un ROLLBACK de un SP desharia tambien los paises ya actualizados.
    IF @@TRANCOUNT > 0
        SET @errores += 'La importacion no se puede ejecutar dentro de una transaccion abierta. ';

    IF @CodigoIso3 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE CodigoIso3 = @CodigoIso3)
        SET @errores += 'El pais indicado no existe. ';

    IF @Contenido IS NULL
       AND (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') = 0
        SET @errores += 'Ole Automation Procedures esta deshabilitado: ejecutar 07_Configuracion_Importacion.sql. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @Contenido IS NOT NULL AND ISJSON(@Contenido) = 0
        THROW 50003, 'El contenido no es un JSON valido. ', 1;

    -- COLLATE DATABASE_DEFAULT: sin esto, las columnas toman la intercalacion de tempdb, que puede ser distinta.
    CREATE TABLE #paises (
        Orden          INT IDENTITY(1, 1) PRIMARY KEY,
        IdPais         INT,
        Codigo         CHAR(3)     COLLATE DATABASE_DEFAULT,
        CodigoConsulta CHAR(3)     COLLATE DATABASE_DEFAULT,
        Nombre         VARCHAR(80) COLLATE DATABASE_DEFAULT,
        Confederacion  VARCHAR(10) COLLATE DATABASE_DEFAULT,
        HusoHorario    VARCHAR(60) COLLATE DATABASE_DEFAULT,
        Pib            DECIMAL(18, 2),
        Anio           INT
    );

    CREATE TABLE #errores (
        Fila       INT,
        Clave      VARCHAR(30)   COLLATE DATABASE_DEFAULT,
        Numero     INT,
        Mensaje    VARCHAR(2000) COLLATE DATABASE_DEFAULT,
        TextoCrudo VARCHAR(500)  COLLATE DATABASE_DEFAULT
    );

    -- NED y POR son codigos FIFA: la API los conoce por sus codigos ISO.
    INSERT INTO #paises (IdPais, Codigo, CodigoConsulta, Nombre, Confederacion, HusoHorario, Pib, Anio)
    SELECT IdPais, CodigoIso3,
           CASE CodigoIso3 WHEN 'NED' THEN 'NLD' WHEN 'POR' THEN 'PRT' ELSE CodigoIso3 END,
           Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib
    FROM Torneo.Pais
    WHERE @CodigoIso3 IS NULL OR CodigoIso3 = @CodigoIso3
    ORDER BY CodigoIso3;

    SET @cantidadPaises = @@ROWCOUNT;

    WHILE @i <= @cantidadPaises
    BEGIN
        SELECT @idPais = IdPais, @codigo = Codigo, @codigoConsulta = CodigoConsulta, @nombre = Nombre,
               @confederacion = Confederacion, @huso = HusoHorario, @pibActual = Pib, @anioActual = Anio
        FROM #paises
        WHERE Orden = @i;

        -- Un SELECT sin filas no cambia las variables: sin esto quedarian los datos de la vuelta anterior.
        SET @respuesta = NULL;
        SET @valorTexto = NULL;
        SET @anioTexto = NULL;

        BEGIN TRY
            SET @url = @urlInicio + @codigoConsulta + @urlFin;

            IF @Contenido IS NULL
                EXEC Importacion.usp_ObtenerUrl @Url = @url, @Respuesta = @respuesta OUTPUT;
            ELSE
                SET @respuesta = @Contenido;

            IF ISJSON(@respuesta) = 0
                THROW 50003, 'La respuesta de la API no es un JSON valido. ', 1;

            -- Un codigo invalido responde con el estado 200 y un mensaje dentro del JSON.
            SET @mensaje = JSON_VALUE(@respuesta, '$[0].message[0].value');
            IF @mensaje IS NOT NULL
            BEGIN
                SET @mensaje = 'La API rechazo el pedido: ' + @mensaje + '. ';
                THROW 50003, @mensaje, 1;
            END;

            SELECT @valorTexto = Valor, @anioTexto = Anio
            FROM OPENJSON(@respuesta, '$[1]')
                 WITH (Pais  VARCHAR(10) '$.countryiso3code',
                       Anio  VARCHAR(10) '$.date',
                       Valor VARCHAR(40) '$.value')
            WHERE Pais = @codigoConsulta;

            SET @filasApi = @@ROWCOUNT;

            SET @pib = TRY_CONVERT(DECIMAL(18, 2), @valorTexto);
            SET @anio = TRY_CONVERT(INT, @anioTexto);

            IF @filasApi = 0
                THROW 50003, 'La respuesta de la API no trae datos de este pais. ', 1;

            IF @pib IS NULL OR @anio IS NULL
                THROW 50003, 'El valor o el anio que trae la API no son numericos. ', 1;

            IF @anio < @anioActual OR (@anio = @anioActual AND @pib = @pibActual)
                SET @sinCambios += 1;
            ELSE
            BEGIN
                -- La modificacion es completa: se reenvian los datos actuales del pais.
                EXEC Torneo.usp_Pais_Modificacion @IdPais = @idPais, @CodigoIso3 = @codigo, @Nombre = @nombre,
                     @Confederacion = @confederacion, @HusoHorario = @huso, @PibPerCapitaUsd = @pib, @AnioPib = @anio;
                SET @actualizadas += 1;
            END
        END TRY
        BEGIN CATCH
            INSERT INTO #errores (Fila, Clave, Numero, Mensaje, TextoCrudo)
            VALUES (@i, @codigo, ERROR_NUMBER(), ERROR_MESSAGE(), LEFT(@respuesta, 500));
        END CATCH

        SET @i += 1;
    END;

    SELECT @conError = COUNT(*) FROM #errores;

    SELECT @cantidadPaises AS Leidas, 0 AS Nuevas, @actualizadas AS Actualizadas,
           @sinCambios AS SinCambios, @conError AS ConError;

    SELECT Fila, Clave, Numero, Mensaje, TextoCrudo FROM #errores ORDER BY Fila;

    IF @conError > 0
    BEGIN
        SET @mensaje = 'Importacion parcial: ' + CAST(@conError AS VARCHAR(10)) + ' de ' + CAST(@cantidadPaises AS VARCHAR(10))
                     + ' paises con error. Los demas se procesaron. ';
        THROW 50004, @mensaje, 1;
    END
END
GO

/*------------------------------------------------------------------------------
 Importacion.usp_ConvertirMonto
 Convierte un monto con la cotizacion del momento. No guarda nada. Es un SP porque
 una funcion no puede ejecutar los sp_OA*. @Contenido reemplaza la respuesta de la
 API, para probar con datos fijos.
 Errores: 50001 datos invalidos; 50003 API inaccesible o respuesta invalida.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_ConvertirMonto
    @Monto           DECIMAL(18, 2),
    @MonedaDestino   VARCHAR(3),
    @MonedaOrigen    VARCHAR(3)     = 'USD',
    @MontoConvertido DECIMAL(18, 2) = NULL OUTPUT,
    @Cotizacion      DECIMAL(18, 8) = NULL OUTPUT,
    @FechaCotizacion DATE           = NULL OUTPUT,
    @Contenido       VARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @urlInicio VARCHAR(100) = 'https://api.frankfurter.dev/v2/rate/';

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @url VARCHAR(400), @respuesta VARCHAR(MAX), @mensaje VARCHAR(2000);

    SET @MontoConvertido = NULL;
    SET @Cotizacion = NULL;
    SET @FechaCotizacion = NULL;

    IF @Monto IS NULL OR @Monto <= 0
        SET @errores += 'El monto debe ser mayor a cero. ';

    IF @MonedaOrigen IS NULL OR @MonedaOrigen NOT LIKE '[A-Za-z][A-Za-z][A-Za-z]'
        SET @errores += 'La moneda de origen debe tener exactamente 3 letras. ';

    IF @MonedaDestino IS NULL OR @MonedaDestino NOT LIKE '[A-Za-z][A-Za-z][A-Za-z]'
        SET @errores += 'La moneda de destino debe tener exactamente 3 letras. ';
    ELSE IF @MonedaDestino = @MonedaOrigen
        SET @errores += 'La moneda de origen y la de destino deben ser distintas. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @Contenido IS NULL
    BEGIN
        SET @url = @urlInicio + UPPER(@MonedaOrigen) + '/' + UPPER(@MonedaDestino);
        EXEC Importacion.usp_ObtenerUrl @Url = @url, @Respuesta = @respuesta OUTPUT;
    END
    ELSE
        SET @respuesta = @Contenido;

    IF ISJSON(@respuesta) = 0
        THROW 50003, 'La respuesta de la API no es un JSON valido. ', 1;

    IF JSON_VALUE(@respuesta, '$.base') <> UPPER(@MonedaOrigen) OR JSON_VALUE(@respuesta, '$.quote') <> UPPER(@MonedaDestino)
    BEGIN
        SET @mensaje = 'La respuesta de la API no corresponde a ' + UPPER(@MonedaOrigen) + ' y ' + UPPER(@MonedaDestino) + '. ';
        THROW 50003, @mensaje, 1;
    END;

    SET @Cotizacion = TRY_CONVERT(DECIMAL(18, 8), JSON_VALUE(@respuesta, '$.rate'));
    SET @FechaCotizacion = TRY_CONVERT(DATE, JSON_VALUE(@respuesta, '$.date'));

    IF @Cotizacion IS NULL OR @Cotizacion <= 0 OR @FechaCotizacion IS NULL
    BEGIN
        SET @Cotizacion = NULL;
        SET @FechaCotizacion = NULL;
        THROW 50003, 'La respuesta de la API no trae una cotizacion y una fecha validas. ', 1;
    END;

    SET @MontoConvertido = @Monto * @Cotizacion;
END
GO
