/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 83_SP_Negocio_Convocatoria.sql
 Objetivo     : Logica de negocio de la convocatoria y de las altas y bajas de ultimo
                momento. Cada SP valida todo primero (un unico mensaje) y despues
                opera dentro de una transaccion:
                  Torneo.usp_RegistrarSeleccion        crea la seleccion y su director
                                                       tecnico (Seleccion y CuerpoTecnico
                                                       en una sola transaccion).
                  Torneo.usp_RegistrarBajaYReemplazo   da de baja a un jugador (motivo y
                                                       fecha) y registra su reemplazo.
                  Torneo.usp_RegistrarBajaJugador      da de baja a un jugador sin
                                                       reemplazo, si la convocatoria no
                                                       queda por debajo del minimo.
                El alta de un jugador de ultima hora, sin baja previa, se hace con
                Torneo.usp_Jugador_Alta (20_SP_ABM_Seleccion.sql).
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Torneo.usp_RegistrarSeleccion
 Una seleccion siempre se registra con su director tecnico. Si la seleccion o el
 director no son validos, no se crea ninguno de los dos. Las validaciones de la
 seleccion y del cuerpo tecnico son las de usp_Seleccion_Alta y
 usp_CuerpoTecnico_Alta.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_RegistrarSeleccion
    @CodigoExterno    VARCHAR(30),
    @IdPais           INT,
    @Grupo            VARCHAR(5),
    @NombreDirector   VARCHAR(80),
    @ApellidoDirector VARCHAR(80),
    @IdSeleccion      INT = NULL OUTPUT,
    @IdDirector       INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @NombreDirector IS NULL OR LTRIM(RTRIM(@NombreDirector)) = ''
        SET @errores += 'El nombre del director tecnico es obligatorio. ';

    IF @ApellidoDirector IS NULL OR LTRIM(RTRIM(@ApellidoDirector)) = ''
        SET @errores += 'El apellido del director tecnico es obligatorio. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = @CodigoExterno, @IdPais = @IdPais, @Grupo = @Grupo,
             @IdSeleccion = @IdSeleccion OUTPUT;

        EXEC Torneo.usp_CuerpoTecnico_Alta @IdSeleccion = @IdSeleccion, @Nombre = @NombreDirector,
             @Apellido = @ApellidoDirector, @Rol = 'Director tecnico', @IdCuerpoTecnico = @IdDirector OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdSeleccion = NULL;
        SET @IdDirector = NULL;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Torneo.usp_RegistrarBajaYReemplazo
 Baja de ultimo momento con reemplazo. En una sola transaccion:
   1) se registra la baja (fecha y motivo) del jugador;
   2) se da de alta al reemplazo en la misma seleccion (con las validaciones de
      usp_Jugador_Alta: dorsal y codigo no repetidos, datos obligatorios, etc.);
   3) se enlaza la baja con su reemplazo.
 La convocatoria queda con la misma cantidad de jugadores activos. Si el reemplazo
 no es valido, la baja tampoco se registra.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_RegistrarBajaYReemplazo
    @IdJugadorBaja               INT,
    @MotivoBaja                  VARCHAR(100),
    @FechaBaja                   DATE,
    @CodigoExternoReemplazo      VARCHAR(30),
    @NombreReemplazo             VARCHAR(80),
    @ApellidoReemplazo           VARCHAR(80),
    @IdPaisReemplazo             INT,
    @DorsalReemplazo             INT,
    @PosicionReemplazo           VARCHAR(5),
    @ClubReemplazo               VARCHAR(120),
    @FechaNacimientoReemplazo    DATE = NULL,
    @IdJugadorReemplazo          INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idSeleccion INT, @fechaAlta DATE, @fechaBajaActual DATE;

    SELECT @idSeleccion = IdSeleccion, @fechaAlta = FechaAlta, @fechaBajaActual = FechaBaja
    FROM Torneo.Jugador
    WHERE IdJugador = @IdJugadorBaja;

    IF @idSeleccion IS NULL
        SET @errores += 'El jugador indicado no existe. ';
    ELSE IF @fechaBajaActual IS NOT NULL
        SET @errores += 'El jugador ya esta dado de baja. ';

    IF @MotivoBaja IS NULL OR @MotivoBaja NOT IN ('Lesion', 'Enfermedad', 'Otro')
        SET @errores += 'El motivo de la baja debe ser Lesion, Enfermedad u Otro. ';

    IF @FechaBaja IS NULL
        SET @errores += 'La fecha de la baja es obligatoria. ';
    ELSE IF @fechaAlta IS NOT NULL AND @FechaBaja < @fechaAlta
        SET @errores += 'La fecha de la baja no puede ser anterior a la fecha de alta del jugador. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Jugador
        SET FechaBaja  = @FechaBaja,
            MotivoBaja = @MotivoBaja
        WHERE IdJugador = @IdJugadorBaja;

        EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @CodigoExternoReemplazo, @Nombre = @NombreReemplazo,
             @Apellido = @ApellidoReemplazo, @IdPais = @IdPaisReemplazo, @IdSeleccion = @idSeleccion,
             @Dorsal = @DorsalReemplazo, @PosicionHabitual = @PosicionReemplazo, @ClubOrigen = @ClubReemplazo,
             @FechaAlta = @FechaBaja, @FechaNacimiento = @FechaNacimientoReemplazo,
             @IdJugador = @IdJugadorReemplazo OUTPUT;

        UPDATE Torneo.Jugador
        SET IdJugadorReemplazo = @IdJugadorReemplazo
        WHERE IdJugador = @IdJugadorBaja;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdJugadorReemplazo = NULL;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Torneo.usp_RegistrarBajaJugador
 Baja de ultimo momento sin reemplazo: la convocatoria tiene que seguir teniendo
 al menos @minConvocados jugadores activos.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_RegistrarBajaJugador
    @IdJugador  INT,
    @MotivoBaja VARCHAR(100),
    @FechaBaja  DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @minConvocados INT = 23;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idSeleccion INT, @fechaAlta DATE, @fechaBajaActual DATE;

    SELECT @idSeleccion = IdSeleccion, @fechaAlta = FechaAlta, @fechaBajaActual = FechaBaja
    FROM Torneo.Jugador
    WHERE IdJugador = @IdJugador;

    IF @idSeleccion IS NULL
        SET @errores += 'El jugador indicado no existe. ';
    ELSE
    BEGIN
        IF @fechaBajaActual IS NOT NULL
            SET @errores += 'El jugador ya esta dado de baja. ';
        ELSE IF (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @idSeleccion AND FechaBaja IS NULL) - 1 < @minConvocados
            SET @errores += 'La seleccion quedaria con menos de ' + CAST(@minConvocados AS VARCHAR(5))
                          + ' convocados: registre un reemplazo. ';
    END;

    IF @MotivoBaja IS NULL OR @MotivoBaja NOT IN ('Lesion', 'Enfermedad', 'Otro')
        SET @errores += 'El motivo de la baja debe ser Lesion, Enfermedad u Otro. ';

    IF @FechaBaja IS NULL
        SET @errores += 'La fecha de la baja es obligatoria. ';
    ELSE IF @fechaAlta IS NOT NULL AND @FechaBaja < @fechaAlta
        SET @errores += 'La fecha de la baja no puede ser anterior a la fecha de alta del jugador. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Jugador
        SET FechaBaja  = @FechaBaja,
            MotivoBaja = @MotivoBaja
        WHERE IdJugador = @IdJugador;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
