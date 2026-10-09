/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 80_SP_Negocio_Partidos.sql
 Objetivo     : Logica de negocio de partidos, sedes y resultados. Cada SP valida
                todo primero (un unico mensaje) y despues opera dentro de una
                transaccion:
                  Torneo.usp_RegistrarPartido   registra el partido y, si hace
                                                falta, tambien su sede (Sede y Partido
                                                en una sola transaccion).
                  Torneo.usp_IniciarPartido     Programado -> En juego.
                  Torneo.usp_FinalizarPartido   En juego -> Finalizado, con la
                                                asistencia y el resultado final.
                  Torneo.usp_SuspenderPartido   Programado o En juego -> Suspendido.
                  Torneo.usp_ReprogramarPartido Suspendido -> Programado, con nueva fecha.
                Estados del partido: Programado, En juego, Finalizado, Suspendido.
                El marcador no se carga aca: lo calculan los SP de goles.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Torneo.usp_RegistrarPartido
 Si la sede (por codigo externo) ya existe, se usa; si no existe, se crea con los
 datos de sede informados y se registra el partido. Si el partido no es valido,
 tampoco se crea la sede: todo o nada. Las validaciones de la sede y del partido
 son las de usp_Sede_Alta y usp_Partido_Alta.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_RegistrarPartido
    @CodigoExterno           VARCHAR(30),
    @NumeroPartido           INT,
    @Fase                    VARCHAR(20),
    @FechaHoraUtc            DATETIME2,
    @CodigoExternoSede       VARCHAR(30),
    @IdSeleccionLocal        INT          = NULL,
    @IdSeleccionVisitante    INT          = NULL,
    @EsquemaTacticoLocal     VARCHAR(20)  = NULL,
    @EsquemaTacticoVisitante VARCHAR(20)  = NULL,
    @NombreEstadio           VARCHAR(120) = NULL,
    @Ciudad                  VARCHAR(80)  = NULL,
    @IdPaisSede              INT          = NULL,
    @HusoHorarioSede         VARCHAR(60)  = NULL,
    @CapacidadSede           INT          = NULL,
    @IdPartido               INT          = NULL OUTPUT,
    @IdSede                  INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    SELECT @IdSede = IdSede
    FROM Torneo.Sede
    WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExternoSede));

    IF @CodigoExternoSede IS NULL OR LTRIM(RTRIM(@CodigoExternoSede)) = ''
        SET @errores += 'El codigo externo de la sede es obligatorio. ';
    ELSE IF @IdSede IS NULL
         AND (@NombreEstadio IS NULL OR @Ciudad IS NULL OR @IdPaisSede IS NULL
              OR @HusoHorarioSede IS NULL OR @CapacidadSede IS NULL)
        SET @errores += 'La sede no existe: para crearla hay que informar nombre del estadio, ciudad, pais, huso horario y capacidad. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IdSede IS NULL
            EXEC Torneo.usp_Sede_Alta @CodigoExterno = @CodigoExternoSede, @NombreEstadio = @NombreEstadio,
                 @Ciudad = @Ciudad, @IdPais = @IdPaisSede, @HusoHorario = @HusoHorarioSede,
                 @Capacidad = @CapacidadSede, @IdSede = @IdSede OUTPUT;

        EXEC Torneo.usp_Partido_Alta @CodigoExterno = @CodigoExterno, @NumeroPartido = @NumeroPartido, @Fase = @Fase,
             @IdSede = @IdSede, @FechaHoraUtc = @FechaHoraUtc, @IdSeleccionLocal = @IdSeleccionLocal,
             @IdSeleccionVisitante = @IdSeleccionVisitante, @EsquemaTacticoLocal = @EsquemaTacticoLocal,
             @EsquemaTacticoVisitante = @EsquemaTacticoVisitante, @IdPartido = @IdPartido OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdPartido = NULL;
        SET @IdSede = NULL;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Torneo.usp_IniciarPartido
 Para empezar, el partido tiene que estar Programado, con las dos selecciones
 definidas y cada una con al menos @minConvocados jugadores convocados.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_IniciarPartido
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @minConvocados INT = 23;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(20), @local INT, @visitante INT;

    SELECT @estado = Estado, @local = IdSeleccionLocal, @visitante = IdSeleccionVisitante
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    IF @estado IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE
    BEGIN
        IF @estado <> 'Programado'
            SET @errores += 'Solo se puede iniciar un partido en estado Programado. ';

        IF @local IS NULL OR @visitante IS NULL
            SET @errores += 'El partido necesita las dos selecciones definidas para empezar. ';
        ELSE
        BEGIN
            IF (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @local AND FechaBaja IS NULL) < @minConvocados
                SET @errores += 'La seleccion local tiene menos de ' + CAST(@minConvocados AS VARCHAR(5)) + ' convocados. ';
            IF (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @visitante AND FechaBaja IS NULL) < @minConvocados
                SET @errores += 'La seleccion visitante tiene menos de ' + CAST(@minConvocados AS VARCHAR(5)) + ' convocados. ';
        END;
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Partido SET Estado = 'En juego' WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Torneo.usp_FinalizarPartido
 Cierra el partido: guarda la asistencia y deja el resultado final. Si no se
 registraron goles, el marcador final es 0 a 0. En las fases eliminatorias el
 partido no puede terminar empatado: tiene que haber una definicion por
 penales con ganador (los penales los carga el SP de goles).
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_FinalizarPartido
    @IdPartido  INT,
    @Asistencia INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(20), @fase VARCHAR(20), @capacidad INT;
    DECLARE @golesLocal INT, @golesVisitante INT, @penalesLocal INT, @penalesVisitante INT;

    SELECT @estado = p.Estado, @fase = p.Fase, @capacidad = s.Capacidad,
           @golesLocal = ISNULL(p.GolesLocal, 0), @golesVisitante = ISNULL(p.GolesVisitante, 0),
           @penalesLocal = p.PenalesLocal, @penalesVisitante = p.PenalesVisitante
    FROM Torneo.Partido p
    JOIN Torneo.Sede s ON s.IdSede = p.IdSede
    WHERE p.IdPartido = @IdPartido;

    IF @estado IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE
    BEGIN
        IF @estado <> 'En juego'
            SET @errores += 'Solo se puede finalizar un partido en estado En juego. ';

        IF @Asistencia IS NULL OR @Asistencia <= 0
            SET @errores += 'La asistencia debe ser mayor a cero. ';
        ELSE IF @Asistencia > @capacidad
            SET @errores += 'La asistencia no puede superar la capacidad del estadio (' + CAST(@capacidad AS VARCHAR(12)) + '). ';

        IF @fase <> 'Grupos' AND @golesLocal = @golesVisitante
           AND (@penalesLocal IS NULL OR @penalesVisitante IS NULL OR @penalesLocal = @penalesVisitante)
            SET @errores += 'En una fase eliminatoria el partido no puede terminar empatado: falta la definicion por penales. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Partido
        SET Estado         = 'Finalizado',
            Asistencia     = @Asistencia,
            GolesLocal     = @golesLocal,
            GolesVisitante = @golesVisitante
        WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Suspension: solo un partido Programado o En juego.
CREATE OR ALTER PROCEDURE Torneo.usp_SuspenderPartido
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(20);

    SELECT @estado = Estado FROM Torneo.Partido WHERE IdPartido = @IdPartido;

    IF @estado IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @estado NOT IN ('Programado', 'En juego')
        SET @errores += 'Solo se puede suspender un partido Programado o En juego. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Partido SET Estado = 'Suspendido' WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Reprogramacion: un partido Suspendido vuelve a Programado con una nueva fecha.
-- La hora local se recalcula con el huso de la sede y se respeta el margen entre
-- partidos de la misma sede.
CREATE OR ALTER PROCEDURE Torneo.usp_ReprogramarPartido
    @IdPartido    INT,
    @FechaHoraUtc DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @margenMinutos INT = 180;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(20), @idSede INT, @husoSede VARCHAR(60), @fechaHoraLocal DATETIME2;

    SELECT @estado = p.Estado, @idSede = p.IdSede, @husoSede = s.HusoHorario
    FROM Torneo.Partido p
    JOIN Torneo.Sede s ON s.IdSede = p.IdSede
    WHERE p.IdPartido = @IdPartido;

    IF @estado IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @estado <> 'Suspendido'
        SET @errores += 'Solo se puede reprogramar un partido Suspendido. ';

    IF @FechaHoraUtc IS NULL
        SET @errores += 'La nueva fecha y hora UTC son obligatorias. ';
    ELSE IF @idSede IS NOT NULL
         AND EXISTS (SELECT 1
                     FROM Torneo.Partido
                     WHERE IdSede = @idSede
                       AND IdPartido <> @IdPartido
                       AND ABS(DATEDIFF(MINUTE, FechaHoraUtc, @FechaHoraUtc)) < @margenMinutos)
        SET @errores += 'Ya hay otro partido en esa sede con menos de 180 minutos de diferencia. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SET @fechaHoraLocal = CAST((@FechaHoraUtc AT TIME ZONE 'UTC') AT TIME ZONE @husoSede AS DATETIME2);

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Partido
        SET FechaHoraUtc   = @FechaHoraUtc,
            FechaHoraLocal = @fechaHoraLocal,
            Estado         = 'Programado'
        WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
