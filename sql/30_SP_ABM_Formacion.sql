/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-10
 Script       : 30_SP_ABM_Formacion.sql
 Objetivo     : Crea los SP de alta, baja y modificacion de Alineacion y
                Sustitucion (esquema Formacion). Cada SP valida todo primero
                e informa en UN solo mensaje (THROW 50001) todas las condiciones
                incumplidas; despues opera dentro de una transaccion.
                Se puede ejecutar mas de una vez (CREATE OR ALTER).
 Depende de   : 03_Tablas_Formacion.sql y 20_SP_ABM_Seleccion.sql
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 ALINEACION
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Formacion.usp_Alineacion_Alta
    @IdPartido      INT,
    @IdJugador      INT,
    @EsTitular      BIT,
    @PosicionCancha VARCHAR(10),
    @IdAlineacion   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxTitulares INT = 11, @maxConvocados INT = 26;
    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @partidoExiste BIT = 0, @jugadorExiste BIT = 0, @pertenece BIT = 0;
    DECLARE @idSeleccionLocal INT, @idSeleccionVisitante INT, @fechaPartido DATE;
    DECLARE @idSeleccionJugador INT, @fechaBaja DATE;
    DECLARE @titulares INT, @convocados INT;

    SELECT @partidoExiste = 1,
           @idSeleccionLocal = p.IdSeleccionLocal,
           @idSeleccionVisitante = p.IdSeleccionVisitante,
           @fechaPartido = CAST(p.FechaHoraUtc AS DATE)
    FROM Torneo.Partido p
    WHERE p.IdPartido = @IdPartido;

    SELECT @jugadorExiste = 1,
           @idSeleccionJugador = j.IdSeleccion,
           @fechaBaja = j.FechaBaja
    FROM Torneo.Jugador j
    WHERE j.IdJugador = @IdJugador;

    IF @partidoExiste = 0
        SET @errores += N'El partido indicado no existe. ';

    IF @jugadorExiste = 0
        SET @errores += N'El jugador indicado no existe. ';

    IF @EsTitular IS NULL
        SET @errores += N'Debe indicarse si el jugador es titular. ';

    IF @PosicionCancha IS NULL OR @PosicionCancha NOT IN ('POR', 'DEF', 'MED', 'DEL')
        SET @errores += N'La posicion en cancha debe ser POR, DEF, MED o DEL. ';

    IF @partidoExiste = 1 AND @jugadorExiste = 1
    BEGIN
        -- Las selecciones del partido pueden ser NULL (cruce por definir), por eso se usa CASE
        SET @pertenece = CASE WHEN @idSeleccionJugador = @idSeleccionLocal
                                OR @idSeleccionJugador = @idSeleccionVisitante THEN 1 ELSE 0 END;

        IF @pertenece = 0
            SET @errores += N'El jugador no pertenece a ninguna de las dos selecciones del partido. ';

        IF @fechaBaja IS NOT NULL AND @fechaBaja <= @fechaPartido
            SET @errores += N'El jugador estaba dado de baja a la fecha del partido. ';

        IF EXISTS (SELECT 1 FROM Formacion.Alineacion WHERE IdPartido = @IdPartido AND IdJugador = @IdJugador)
            SET @errores += N'El jugador ya esta en la alineacion de este partido. ';

        IF @pertenece = 1
        BEGIN
            -- COUNT nunca devuelve NULL, por eso no hace falta ISNULL
            SELECT @titulares = COUNT(CASE WHEN a.EsTitular = 1 THEN 1 END),
                   @convocados = COUNT(*)
            FROM Formacion.Alineacion a
            JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @IdPartido AND j.IdSeleccion = @idSeleccionJugador;

            IF @EsTitular = 1 AND @titulares >= @maxTitulares
                SET @errores += CONCAT(N'La seleccion ya tiene ', @maxTitulares, N' titulares en este partido. ');
            IF @convocados >= @maxConvocados
                SET @errores += CONCAT(N'La seleccion ya tiene el maximo de ', @maxConvocados, N' convocados para este partido. ');
        END
    END

    IF @errores <> N''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Formacion.Alineacion (IdPartido, IdJugador, EsTitular, PosicionCancha)
        VALUES (@IdPartido, @IdJugador, @EsTitular, @PosicionCancha);

        SET @IdAlineacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Solo se puede modificar condicion de titular y posicion. Para cambiar partido/jugador: baja + alta.
CREATE OR ALTER PROCEDURE Formacion.usp_Alineacion_Modificacion
    @IdAlineacion   INT,
    @EsTitular      BIT,
    @PosicionCancha VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxTitulares INT = 11;
    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @alineacionExiste BIT = 0;
    DECLARE @idPartido INT, @idSeleccion INT, @titularActual BIT, @titulares INT;

    SELECT @alineacionExiste = 1,
           @idPartido = a.IdPartido,
           @idSeleccion = j.IdSeleccion,
           @titularActual = a.EsTitular
    FROM Formacion.Alineacion a
    JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
    WHERE a.IdAlineacion = @IdAlineacion;

    IF @alineacionExiste = 0
        SET @errores += N'La alineacion indicada no existe. ';

    IF @EsTitular IS NULL
        SET @errores += N'Debe indicarse si el jugador es titular. ';

    IF @PosicionCancha IS NULL OR @PosicionCancha NOT IN ('POR', 'DEF', 'MED', 'DEL')
        SET @errores += N'La posicion en cancha debe ser POR, DEF, MED o DEL. ';

    IF @alineacionExiste = 1 AND @EsTitular IS NOT NULL AND @titularActual <> @EsTitular
    BEGIN
        IF EXISTS (SELECT 1
                   FROM Formacion.Sustitucion
                   WHERE IdAlineacionSale = @IdAlineacion OR IdAlineacionEntra = @IdAlineacion)
            SET @errores += N'No se puede cambiar la condicion de titular: el jugador participa de una sustitucion. ';

        IF @EsTitular = 1
        BEGIN
            SELECT @titulares = COUNT(*)
            FROM Formacion.Alineacion a
            JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idPartido AND j.IdSeleccion = @idSeleccion AND a.EsTitular = 1;

            IF @titulares >= @maxTitulares
                SET @errores += CONCAT(N'La seleccion ya tiene ', @maxTitulares, N' titulares en este partido. ');
        END
    END

    IF @errores <> N''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Formacion.Alineacion
        SET EsTitular = @EsTitular, PosicionCancha = @PosicionCancha
        WHERE IdAlineacion = @IdAlineacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real. Si hay goles o tarjetas que referencian la alineacion, la clave
-- foranea frena el DELETE (error 547) y se informa con un mensaje claro.
CREATE OR ALTER PROCEDURE Formacion.usp_Alineacion_Baja
    @IdAlineacion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM Formacion.Alineacion WHERE IdAlineacion = @IdAlineacion)
        SET @errores += N'La alineacion indicada no existe. ';
    ELSE IF EXISTS (SELECT 1
                    FROM Formacion.Sustitucion
                    WHERE IdAlineacionSale = @IdAlineacion OR IdAlineacionEntra = @IdAlineacion)
        SET @errores += N'No se puede eliminar: el jugador participa de una sustitucion. ';

    IF @errores <> N''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Formacion.Alineacion WHERE IdAlineacion = @IdAlineacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, N'No se puede eliminar la alineacion: otros registros (goles o tarjetas) dependen de ella. ', 1;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 SUSTITUCION (con la logica de cambios)
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Formacion.usp_Sustitucion_Alta
    @IdAlineacionSale  INT,
    @IdAlineacionEntra INT,
    @Periodo           VARCHAR(30),
    @Minuto            INT,
    @Motivo            VARCHAR(20),
    @MinutoAdicional   INT = 0,
    @NumeroVentana     INT = NULL,
    @IdSustitucion     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxCambios INT = 5;
    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @saleExiste BIT = 0, @entraExiste BIT = 0;
    DECLARE @partidoSale INT, @selSale INT, @titSale BIT;
    DECLARE @partidoEntra INT, @selEntra INT, @titEntra BIT;
    DECLARE @cambios INT;

    SELECT @saleExiste = 1, @partidoSale = a.IdPartido, @selSale = j.IdSeleccion, @titSale = a.EsTitular
    FROM Formacion.Alineacion a
    JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
    WHERE a.IdAlineacion = @IdAlineacionSale;

    SELECT @entraExiste = 1, @partidoEntra = a.IdPartido, @selEntra = j.IdSeleccion, @titEntra = a.EsTitular
    FROM Formacion.Alineacion a
    JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
    WHERE a.IdAlineacion = @IdAlineacionEntra;

    -- Datos del momento del cambio
    IF @Periodo IS NULL OR LTRIM(RTRIM(@Periodo)) = ''
        SET @errores += N'El periodo es obligatorio. ';

    IF @Minuto IS NULL OR @Minuto NOT BETWEEN 0 AND 120
        SET @errores += N'El minuto debe estar entre 0 y 120. ';

    IF @MinutoAdicional IS NULL OR @MinutoAdicional < 0
        SET @errores += N'El minuto adicional no puede ser negativo. ';

    IF @Motivo IS NULL OR LTRIM(RTRIM(@Motivo)) = ''
        SET @errores += N'El motivo es obligatorio. ';

    -- Jugadores involucrados
    IF @saleExiste = 0
        SET @errores += N'La alineacion del jugador que sale no existe. ';

    IF @entraExiste = 0
        SET @errores += N'La alineacion del jugador que entra no existe. ';

    IF @IdAlineacionSale = @IdAlineacionEntra
        SET @errores += N'El jugador que sale y el que entra deben ser distintos. ';

    IF @saleExiste = 1 AND @entraExiste = 1 AND @IdAlineacionSale <> @IdAlineacionEntra
    BEGIN
        IF @partidoSale <> @partidoEntra
        BEGIN
            SET @errores += N'Los dos jugadores deben ser del mismo partido. ';
        END
        ELSE
        BEGIN
            IF @selSale <> @selEntra
                SET @errores += N'Los dos jugadores deben pertenecer a la misma seleccion. ';

            IF @titEntra = 1
                SET @errores += N'El jugador que entra debe ser suplente. ';

            IF @titSale = 0
               AND NOT EXISTS (SELECT 1 FROM Formacion.Sustitucion WHERE IdAlineacionEntra = @IdAlineacionSale)
                SET @errores += N'El jugador que sale es suplente y todavia no ingreso al campo. ';

            IF EXISTS (SELECT 1 FROM Formacion.Sustitucion WHERE IdAlineacionSale = @IdAlineacionSale)
                SET @errores += N'El jugador que sale ya fue reemplazado. ';

            IF EXISTS (SELECT 1 FROM Formacion.Sustitucion WHERE IdAlineacionEntra = @IdAlineacionEntra)
                SET @errores += N'El jugador que entra ya ingreso en otra sustitucion. ';

            SELECT @cambios = COUNT(*)
            FROM Formacion.Sustitucion su
            JOIN Formacion.Alineacion asale ON asale.IdAlineacion = su.IdAlineacionSale
            JOIN Torneo.Jugador jsale       ON jsale.IdJugador = asale.IdJugador
            WHERE asale.IdPartido = @partidoSale AND jsale.IdSeleccion = @selSale;

            IF @cambios >= @maxCambios
                SET @errores += CONCAT(N'La seleccion ya uso el maximo de ', @maxCambios, N' cambios en este partido. ');
        END
    END

    IF @errores <> N''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Formacion.Sustitucion
            (IdAlineacionSale, IdAlineacionEntra, Periodo, Minuto, MinutoAdicional, NumeroVentana, Motivo)
        VALUES
            (@IdAlineacionSale, @IdAlineacionEntra, @Periodo, @Minuto, @MinutoAdicional, @NumeroVentana, @Motivo);

        SET @IdSustitucion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Solo datos del momento del cambio. Para cambiar quien sale/entra: baja + alta.
CREATE OR ALTER PROCEDURE Formacion.usp_Sustitucion_Modificacion
    @IdSustitucion   INT,
    @Periodo         VARCHAR(30),
    @Minuto          INT,
    @Motivo          VARCHAR(20),
    @MinutoAdicional INT = 0,
    @NumeroVentana   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM Formacion.Sustitucion WHERE IdSustitucion = @IdSustitucion)
        SET @errores += N'La sustitucion indicada no existe. ';

    IF @Periodo IS NULL OR LTRIM(RTRIM(@Periodo)) = ''
        SET @errores += N'El periodo es obligatorio. ';

    IF @Minuto IS NULL OR @Minuto NOT BETWEEN 0 AND 120
        SET @errores += N'El minuto debe estar entre 0 y 120. ';

    IF @MinutoAdicional IS NULL OR @MinutoAdicional < 0
        SET @errores += N'El minuto adicional no puede ser negativo. ';

    IF @Motivo IS NULL OR LTRIM(RTRIM(@Motivo)) = ''
        SET @errores += N'El motivo es obligatorio. ';

    IF @errores <> N''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Formacion.Sustitucion
        SET Periodo = @Periodo, Minuto = @Minuto, MinutoAdicional = @MinutoAdicional,
            NumeroVentana = @NumeroVentana, Motivo = @Motivo
        WHERE IdSustitucion = @IdSustitucion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Formacion.usp_Sustitucion_Baja
    @IdSustitucion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @sustitucionExiste BIT = 0, @idEntra INT;

    SELECT @sustitucionExiste = 1, @idEntra = IdAlineacionEntra
    FROM Formacion.Sustitucion
    WHERE IdSustitucion = @IdSustitucion;

    IF @sustitucionExiste = 0
        SET @errores += N'La sustitucion indicada no existe. ';
    -- Si el jugador que entro volvio a salir, no se puede anular el cambio que lo hizo entrar
    ELSE IF EXISTS (SELECT 1 FROM Formacion.Sustitucion WHERE IdAlineacionSale = @idEntra)
        SET @errores += N'No se puede eliminar: el jugador que entro fue reemplazado luego. ';

    IF @errores <> N''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Formacion.Sustitucion WHERE IdSustitucion = @IdSustitucion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO