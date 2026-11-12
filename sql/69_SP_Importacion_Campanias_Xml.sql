/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-11
 Script       : 69_SP_Importacion_Campanias_Xml.sql
 Objetivo     : Importa las campanias del archivo XML que genera el scraping de
                79_SP_Importacion_Scraping_Campanias.sql en Publicidad.Anunciante,
                Campania, Pieza y PiezaPais, con los SP de 60_SP_ABM_Publicidad.sql.
 Prerrequisito: 60_SP_ABM_Publicidad.sql y 63_SP_Importacion_Comun.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Importacion.usp_ImportarCampaniasXml
 Recibe @NombreArchivo o @Contenido (el texto, para probar sin archivo).
 - Cada campania se carga con su anunciante (si todavia no existe), una pieza con
   el titulo de la campania y @CodigoPais como pais de interes. La pagina no trae
   fechas, idioma ni duracion: se usan las fechas del Mundial, 'es' y 30 segundos.
 - Upsert por anunciante y nombre de campania: una campania que ya existe queda
   sin cambios, porque el archivo no trae otros datos que se guarden.
 - Cada campania va en su propia transaccion: si falla un paso, no queda a medias.
 Errores: 50001 parametros invalidos; 50003 archivo inaccesible o XML invalido;
 50004 importacion parcial.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_ImportarCampaniasXml
    @NombreArchivo VARCHAR(260) = NULL,
    @Contenido     VARCHAR(MAX) = NULL,
    @CodigoPais    CHAR(3)      = 'ARG'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @fechaInicio DATE = '2026-06-11', @fechaFin DATE = '2026-07-19';
    DECLARE @idioma VARCHAR(10) = 'es', @duracionSegundos INT = 30;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @i INT = 1, @cantidadFilas INT;
    DECLARE @nuevas INT = 0, @sinCambios INT = 0, @conError INT;
    DECLARE @mensaje VARCHAR(2000), @documento XML, @idPais INT, @finDeclaracion INT;

    DECLARE @anunciante VARCHAR(400), @titulo VARCHAR(400);
    DECLARE @idAnunciante INT, @idCampania INT, @idPieza INT;

    -- Sin transaccion general: un ROLLBACK desharia tambien las campanias validas.
    IF @@TRANCOUNT > 0
        SET @errores += 'La importacion no se puede ejecutar dentro de una transaccion abierta. ';

    IF @NombreArchivo IS NULL AND @Contenido IS NULL
        SET @errores += 'Hay que indicar el nombre del archivo o el contenido. ';
    ELSE IF @NombreArchivo IS NOT NULL AND @Contenido IS NOT NULL
        SET @errores += 'Hay que indicar el nombre del archivo o el contenido, no los dos. ';
    ELSE IF @NombreArchivo IS NOT NULL AND RIGHT(RTRIM(@NombreArchivo), 4) <> '.xml'
        SET @errores += 'El archivo debe tener extension .xml. ';

    SELECT @idPais = IdPais FROM Torneo.Pais WHERE CodigoIso3 = @CodigoPais;
    IF @idPais IS NULL
        SET @errores += 'El pais de interes ' + ISNULL(@CodigoPais, 'NULL') + ' no esta cargado en Torneo.Pais. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @NombreArchivo IS NOT NULL
        EXEC Importacion.usp_LeerArchivo @NombreArchivo = @NombreArchivo, @Contenido = @Contenido OUTPUT;

    -- Un texto VARCHAR con la declaracion encoding="utf-8" no se puede convertir a XML: se quita la declaracion.
    IF LTRIM(@Contenido) LIKE '<?xml%'
    BEGIN
        SET @finDeclaracion = CHARINDEX('?>', @Contenido);
        SET @Contenido = SUBSTRING(@Contenido, @finDeclaracion + 2, DATALENGTH(@Contenido));
    END;

    SET @documento = TRY_CAST(@Contenido AS XML);

    IF @documento IS NULL
        THROW 50003, 'El contenido no es un XML valido. ', 1;

    IF @documento.exist('/Campanias/Campania') = 0
        THROW 50003, 'El XML no tiene la estructura esperada: una raiz Campanias con elementos Campania. ', 1;

    -- COLLATE DATABASE_DEFAULT: sin esto, las columnas toman la intercalacion de tempdb, que puede ser distinta.
    CREATE TABLE #campanias (
        Orden      INT IDENTITY(1, 1) PRIMARY KEY,
        Anunciante VARCHAR(400) COLLATE DATABASE_DEFAULT,
        Titulo     VARCHAR(400) COLLATE DATABASE_DEFAULT
    );

    CREATE TABLE #errores (
        Fila       INT,
        Anunciante VARCHAR(120)  COLLATE DATABASE_DEFAULT,
        Titulo     VARCHAR(120)  COLLATE DATABASE_DEFAULT,
        Numero     INT,
        Mensaje    VARCHAR(2000) COLLATE DATABASE_DEFAULT
    );

    INSERT INTO #campanias (Anunciante, Titulo)
    SELECT LTRIM(RTRIM(c.value('(Anunciante/text())[1]', 'VARCHAR(400)'))),
           LTRIM(RTRIM(c.value('(Titulo/text())[1]', 'VARCHAR(400)')))
    FROM @documento.nodes('/Campanias/Campania') AS t(c);

    SET @cantidadFilas = @@ROWCOUNT;

    WHILE @i <= @cantidadFilas
    BEGIN
        SELECT @anunciante = Anunciante, @titulo = Titulo
        FROM #campanias
        WHERE Orden = @i;

        SET @errores = '';

        IF ISNULL(@anunciante, '') = ''
            SET @errores += 'El anunciante esta vacio. ';
        ELSE IF LEN(@anunciante) > 120
            SET @errores += 'El anunciante supera los 120 caracteres. ';

        IF ISNULL(@titulo, '') = ''
            SET @errores += 'El titulo de la campania esta vacio. ';
        ELSE IF LEN(@titulo) > 120
            SET @errores += 'El titulo de la campania supera los 120 caracteres. ';

        IF @errores <> ''
            INSERT INTO #errores (Fila, Anunciante, Titulo, Numero, Mensaje)
            VALUES (@i, LEFT(@anunciante, 120), LEFT(@titulo, 120), 50001, @errores);
        ELSE
        BEGIN
            -- Un SELECT sin filas no cambia la variable: sin esto quedaria el valor de la vuelta anterior.
            SET @idAnunciante = NULL;
            SET @idCampania = NULL;

            SELECT @idAnunciante = IdAnunciante FROM Publicidad.Anunciante WHERE Nombre = @anunciante;
            SELECT @idCampania = IdCampania FROM Publicidad.Campania WHERE IdAnunciante = @idAnunciante AND Nombre = @titulo;

            IF @idCampania IS NOT NULL
                SET @sinCambios += 1;
            ELSE
            BEGIN
                BEGIN TRY
                    BEGIN TRANSACTION;

                    IF @idAnunciante IS NULL
                        EXEC Publicidad.usp_Anunciante_Alta @Nombre = @anunciante, @IdAnunciante = @idAnunciante OUTPUT;

                    EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @idAnunciante, @Nombre = @titulo,
                         @FechaInicio = @fechaInicio, @FechaFin = @fechaFin, @IdCampania = @idCampania OUTPUT;

                    EXEC Publicidad.usp_Pieza_Alta @IdCampania = @idCampania, @Nombre = @titulo, @Idioma = @idioma,
                         @DuracionSegundos = @duracionSegundos, @IdPieza = @idPieza OUTPUT;

                    EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @idPieza, @IdPais = @idPais;

                    COMMIT TRANSACTION;
                    SET @nuevas += 1;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    INSERT INTO #errores (Fila, Anunciante, Titulo, Numero, Mensaje)
                    VALUES (@i, LEFT(@anunciante, 120), LEFT(@titulo, 120), ERROR_NUMBER(), ERROR_MESSAGE());
                END CATCH
            END;
        END;

        SET @i += 1;
    END;

    SELECT @conError = COUNT(*) FROM #errores;

    SELECT @cantidadFilas AS Leidas, @nuevas AS Nuevas, @sinCambios AS SinCambios, @conError AS ConError;

    SELECT Fila, Anunciante, Titulo, Numero, Mensaje FROM #errores ORDER BY Fila;

    IF @conError > 0
    BEGIN
        SET @mensaje = 'Importacion parcial: ' + CAST(@conError AS VARCHAR(10)) + ' de ' + CAST(@cantidadFilas AS VARCHAR(10))
                     + ' campanias con error. Las demas se procesaron. ';
        THROW 50004, @mensaje, 1;
    END
END
GO
