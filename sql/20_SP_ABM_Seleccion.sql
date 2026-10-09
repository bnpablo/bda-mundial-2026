/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 20_SP_ABM_Seleccion.sql
 Objetivo     : Procedimientos de alta, baja y modificacion de Seleccion, Jugador
                (convocatoria) y CuerpoTecnico. Cada SP informa en un unico
                mensaje todas las validaciones que no se cumplen. Los limites del
                reglamento (selecciones por grupo, minimo y maximo de convocados)
                son constantes declaradas al inicio de cada SP.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 SELECCION
 CodigoExterno es obligatorio: la columna es UNIQUE y SQL Server admite un solo
 NULL en una columna UNIQUE. El grupo se guarda en mayuscula.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Seleccion_Alta
    @CodigoExterno VARCHAR(30),
    @IdPais        INT,
    @Grupo         VARCHAR(5),
    @IdSeleccion   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxPorGrupo INT = 4;
    DECLARE @errores VARCHAR(2000) = '';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe una seleccion con ese codigo externo. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdPais = @IdPais)
        SET @errores += 'El pais ya tiene una seleccion registrada. ';

    IF @Grupo IS NULL OR @Grupo NOT IN ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L')
        SET @errores += 'El grupo debe ser una letra de la A a la L. ';
    ELSE IF (SELECT COUNT(*) FROM Torneo.Seleccion WHERE Grupo = @Grupo) >= @maxPorGrupo
        SET @errores += 'El grupo ' + UPPER(@Grupo) + ' ya tiene el maximo de '
                      + CAST(@maxPorGrupo AS VARCHAR(5)) + ' selecciones. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Seleccion (CodigoExterno, IdPais, Grupo)
        VALUES (LTRIM(RTRIM(@CodigoExterno)), @IdPais, UPPER(@Grupo));

        SET @IdSeleccion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Torneo.usp_Seleccion_Modificacion
    @IdSeleccion   INT,
    @CodigoExterno VARCHAR(30),
    @IdPais        INT,
    @Grupo         VARCHAR(5)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxPorGrupo INT = 4;
    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Seleccion
                    WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdSeleccion <> @IdSeleccion)
        SET @errores += 'Ya existe otra seleccion con ese codigo externo. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdPais = @IdPais AND IdSeleccion <> @IdSeleccion)
        SET @errores += 'El pais ya tiene otra seleccion registrada. ';

    IF @Grupo IS NULL OR @Grupo NOT IN ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L')
        SET @errores += 'El grupo debe ser una letra de la A a la L. ';
    ELSE IF (SELECT COUNT(*) FROM Torneo.Seleccion WHERE Grupo = @Grupo AND IdSeleccion <> @IdSeleccion) >= @maxPorGrupo
        SET @errores += 'El grupo ' + UPPER(@Grupo) + ' ya tiene el maximo de '
                      + CAST(@maxPorGrupo AS VARCHAR(5)) + ' selecciones. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Seleccion
        SET CodigoExterno = LTRIM(RTRIM(@CodigoExterno)),
            IdPais        = @IdPais,
            Grupo         = UPPER(@Grupo)
        WHERE IdSeleccion = @IdSeleccion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: solo si la seleccion no tiene jugadores, cuerpo tecnico ni partidos.
CREATE OR ALTER PROCEDURE Torneo.usp_Seleccion_Baja
    @IdSeleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdSeleccion = @IdSeleccion)
            SET @errores += 'La seleccion tiene jugadores registrados. ';
        IF EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE IdSeleccion = @IdSeleccion)
            SET @errores += 'La seleccion tiene integrantes del cuerpo tecnico registrados. ';
        IF EXISTS (SELECT 1 FROM Torneo.Partido
                   WHERE IdSeleccionLocal = @IdSeleccion OR IdSeleccionVisitante = @IdSeleccion)
            SET @errores += 'La seleccion tiene partidos registrados. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar la seleccion: otros registros dependen de ella. ', 1;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 JUGADOR (convocatoria)
 - El dorsal es unico dentro de la seleccion, aunque el jugador que lo tenia ya
   este dado de baja (lo exige la restriccion UQ_Jugador_Seleccion_Dorsal).
 - Un jugador nuevo siempre queda convocado (sin fecha de baja). Las bajas y los
   reemplazos de ultimo momento se registran con los procedimientos de la logica
   de convocatoria (83_SP_Negocio_Convocatoria.sql).
 - La convocatoria no puede superar @maxConvocados jugadores activos.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Jugador_Alta
    @CodigoExterno    VARCHAR(30),
    @Nombre           VARCHAR(80),
    @Apellido         VARCHAR(80),
    @IdPais           INT,
    @IdSeleccion      INT,
    @Dorsal           INT,
    @PosicionHabitual VARCHAR(5),
    @ClubOrigen       VARCHAR(120),
    @FechaAlta        DATE,
    @FechaNacimiento  DATE = NULL,
    @IdJugador        INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxConvocados INT = 26;
    DECLARE @errores VARCHAR(2000) = '';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe un jugador con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @FechaNacimiento IS NOT NULL AND @FechaNacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais (nacionalidad) indicado no existe. ';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';
    ELSE
    BEGIN
        IF @Dorsal IS NOT NULL
           AND EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdSeleccion = @IdSeleccion AND Dorsal = @Dorsal)
            SET @errores += 'Ese dorsal ya fue asignado en la seleccion. ';

        IF (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @IdSeleccion AND FechaBaja IS NULL) >= @maxConvocados
            SET @errores += 'La seleccion ya tiene el maximo de ' + CAST(@maxConvocados AS VARCHAR(5))
                          + ' convocados. ';
    END;

    IF @Dorsal IS NULL OR @Dorsal NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal debe estar entre 1 y 99. ';

    IF @PosicionHabitual IS NULL OR @PosicionHabitual NOT IN ('POR', 'DEF', 'MED', 'DEL')
        SET @errores += 'La posicion habitual debe ser POR, DEF, MED o DEL. ';

    IF @ClubOrigen IS NULL OR LTRIM(RTRIM(@ClubOrigen)) = ''
        SET @errores += 'El club de origen es obligatorio. ';

    IF @FechaAlta IS NULL
        SET @errores += 'La fecha de alta en la convocatoria es obligatoria. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Jugador (CodigoExterno, Nombre, Apellido, FechaNacimiento, IdPais, IdSeleccion, Dorsal,
                                    PosicionHabitual, ClubOrigen, FechaAlta)
        VALUES (LTRIM(RTRIM(@CodigoExterno)), LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Apellido)), @FechaNacimiento,
                @IdPais, @IdSeleccion, @Dorsal, @PosicionHabitual, LTRIM(RTRIM(@ClubOrigen)), @FechaAlta);

        SET @IdJugador = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Modificacion completa de los datos personales y de convocatoria. No cambia la
-- seleccion (para eso: baja y nueva alta) ni toca la baja de ultimo momento.
CREATE OR ALTER PROCEDURE Torneo.usp_Jugador_Modificacion
    @IdJugador        INT,
    @CodigoExterno    VARCHAR(30),
    @Nombre           VARCHAR(80),
    @Apellido         VARCHAR(80),
    @IdPais           INT,
    @IdSeleccion      INT,
    @Dorsal           INT,
    @PosicionHabitual VARCHAR(5),
    @ClubOrigen       VARCHAR(120),
    @FechaAlta        DATE,
    @FechaNacimiento  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @seleccionActual INT, @fechaBajaActual DATE;

    SELECT @seleccionActual = IdSeleccion, @fechaBajaActual = FechaBaja
    FROM Torneo.Jugador
    WHERE IdJugador = @IdJugador;

    IF @seleccionActual IS NULL
        SET @errores += 'El jugador indicado no existe. ';
    ELSE
    BEGIN
        IF @fechaBajaActual IS NOT NULL
            SET @errores += 'El jugador esta dado de baja y no puede modificarse. ';
        IF @IdSeleccion IS NULL OR @IdSeleccion <> @seleccionActual
            SET @errores += 'No se puede cambiar la seleccion de un jugador: elimine el jugador y registre una nueva alta. ';
        ELSE IF @Dorsal IS NOT NULL
             AND EXISTS (SELECT 1 FROM Torneo.Jugador
                         WHERE IdSeleccion = @IdSeleccion AND Dorsal = @Dorsal AND IdJugador <> @IdJugador)
            SET @errores += 'Ese dorsal ya fue asignado en la seleccion. ';
    END;

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Jugador
                    WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdJugador <> @IdJugador)
        SET @errores += 'Ya existe otro jugador con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @FechaNacimiento IS NOT NULL AND @FechaNacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais (nacionalidad) indicado no existe. ';

    IF @Dorsal IS NULL OR @Dorsal NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal debe estar entre 1 y 99. ';

    IF @PosicionHabitual IS NULL OR @PosicionHabitual NOT IN ('POR', 'DEF', 'MED', 'DEL')
        SET @errores += 'La posicion habitual debe ser POR, DEF, MED o DEL. ';

    IF @ClubOrigen IS NULL OR LTRIM(RTRIM(@ClubOrigen)) = ''
        SET @errores += 'El club de origen es obligatorio. ';

    IF @FechaAlta IS NULL
        SET @errores += 'La fecha de alta en la convocatoria es obligatoria. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Jugador
        SET CodigoExterno    = LTRIM(RTRIM(@CodigoExterno)),
            Nombre           = LTRIM(RTRIM(@Nombre)),
            Apellido         = LTRIM(RTRIM(@Apellido)),
            FechaNacimiento  = @FechaNacimiento,
            IdPais           = @IdPais,
            Dorsal           = @Dorsal,
            PosicionHabitual = @PosicionHabitual,
            ClubOrigen       = LTRIM(RTRIM(@ClubOrigen)),
            FechaAlta        = @FechaAlta
        WHERE IdJugador = @IdJugador;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo de un jugador sin baja de ultimo momento registrada
-- (los jugadores dados de baja quedan como historial de la convocatoria).
-- Alineaciones, goles o tarjetas de otros modulos las frena la clave foranea.
CREATE OR ALTER PROCEDURE Torneo.usp_Jugador_Baja
    @IdJugador INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdJugador IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdJugador = @IdJugador)
        SET @errores += 'El jugador indicado no existe. ';
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdJugador = @IdJugador AND FechaBaja IS NOT NULL)
            SET @errores += 'El jugador tiene una baja de ultimo momento registrada: forma parte del historial y no se elimina. ';
        IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdJugadorReemplazo = @IdJugador)
            SET @errores += 'El jugador es el reemplazo de otro jugador. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Torneo.Jugador WHERE IdJugador = @IdJugador;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar el jugador: otros registros dependen de el. ', 1;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 CUERPO TECNICO
 Cada seleccion tiene un solo director tecnico y varios ayudantes.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_CuerpoTecnico_Alta
    @IdSeleccion     INT,
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @Rol             VARCHAR(30),
    @IdCuerpoTecnico INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @Rol IS NULL OR @Rol NOT IN ('Director tecnico', 'Ayudante')
        SET @errores += 'El rol debe ser Director tecnico o Ayudante. ';
    ELSE IF @Rol = 'Director tecnico'
        AND EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE IdSeleccion = @IdSeleccion AND Rol = 'Director tecnico')
        SET @errores += 'La seleccion ya tiene un director tecnico. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.CuerpoTecnico (IdSeleccion, Nombre, Apellido, Rol)
        VALUES (@IdSeleccion, LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Apellido)), @Rol);

        SET @IdCuerpoTecnico = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Torneo.usp_CuerpoTecnico_Modificacion
    @IdCuerpoTecnico INT,
    @IdSeleccion     INT,
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @Rol             VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdCuerpoTecnico IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico)
        SET @errores += 'El integrante del cuerpo tecnico indicado no existe. ';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @Rol IS NULL OR @Rol NOT IN ('Director tecnico', 'Ayudante')
        SET @errores += 'El rol debe ser Director tecnico o Ayudante. ';
    ELSE IF @Rol = 'Director tecnico'
        AND EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico
                    WHERE IdSeleccion = @IdSeleccion AND Rol = 'Director tecnico'
                      AND IdCuerpoTecnico <> @IdCuerpoTecnico)
        SET @errores += 'La seleccion ya tiene un director tecnico. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.CuerpoTecnico
        SET IdSeleccion = @IdSeleccion,
            Nombre      = LTRIM(RTRIM(@Nombre)),
            Apellido    = LTRIM(RTRIM(@Apellido)),
            Rol         = @Rol
        WHERE IdCuerpoTecnico = @IdCuerpoTecnico;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real. Si el integrante recibio tarjetas (modulo de incidencias),
-- la clave foranea lo impide.
CREATE OR ALTER PROCEDURE Torneo.usp_CuerpoTecnico_Baja
    @IdCuerpoTecnico INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdCuerpoTecnico IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico)
        SET @errores += 'El integrante del cuerpo tecnico indicado no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Torneo.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar el integrante: otros registros dependen de el. ', 1;
        THROW;
    END CATCH
END
GO
