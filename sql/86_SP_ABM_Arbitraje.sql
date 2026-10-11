/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 86_SP_ABM_Arbitraje.sql
 Objetivo     : Procedimientos de alta, baja y modificacion de Arbitro,
                ArbitroIdioma y DesignacionArbitral. Cada SP informa en un unico
                mensaje todas las validaciones que no se cumplen (error 50001).
                El conflicto de nacionalidad (arbitro del mismo pais que una de las
                selecciones del partido) se informa aparte con el error 50002.
                La modificacion es completa: se envian todos los datos y se
                reemplazan todos.
 Prerrequisito: 04_Tablas_Arbitraje_Incidencia.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 ARBITRO
 CodigoExterno es obligatorio: la columna es UNIQUE (para el upsert de las
 importaciones) y SQL Server admite un solo NULL en una columna UNIQUE.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Arbitraje.usp_Arbitro_Alta
    @CodigoExterno   VARCHAR(30),
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @IdPais          INT,
    @Categoria       VARCHAR(20),
    @FechaNacimiento DATE = NULL,
    @IdArbitro       INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe un arbitro con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @Categoria IS NULL OR @Categoria NOT IN ('FIFA', 'Confederacion')
        SET @errores += 'La categoria debe ser FIFA o Confederacion. ';

    IF @FechaNacimiento > DATEADD(YEAR, -18, CAST(GETDATE() AS DATE))
        SET @errores += 'El arbitro debe ser mayor de 18 anios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Arbitraje.Arbitro (CodigoExterno, Nombre, Apellido, FechaNacimiento, IdPais, Categoria)
        VALUES (LTRIM(RTRIM(@CodigoExterno)), LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Apellido)), @FechaNacimiento,
                @IdPais, @Categoria);

        SET @IdArbitro = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Modificacion completa. Si cambia el pais, el arbitro no puede quedar con la
-- misma nacionalidad que una seleccion de un partido no finalizado en el que ya
-- esta designado (error 50002).
CREATE OR ALTER PROCEDURE Arbitraje.usp_Arbitro_Modificacion
    @IdArbitro       INT,
    @CodigoExterno   VARCHAR(30),
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @IdPais          INT,
    @Categoria       VARCHAR(20),
    @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro)
        SET @errores += 'El arbitro indicado no existe. ';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro
                    WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdArbitro <> @IdArbitro)
        SET @errores += 'Ya existe otro arbitro con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @Categoria IS NULL OR @Categoria NOT IN ('FIFA', 'Confederacion')
        SET @errores += 'La categoria debe ser FIFA o Confederacion. ';

    IF @FechaNacimiento > DATEADD(YEAR, -18, CAST(GETDATE() AS DATE))
        SET @errores += 'El arbitro debe ser mayor de 18 anios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF EXISTS (SELECT 1
               FROM Arbitraje.DesignacionArbitral d
               JOIN Torneo.Partido p ON p.IdPartido = d.IdPartido
               JOIN Torneo.Seleccion s ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
               WHERE d.IdArbitro = @IdArbitro
                 AND p.Estado <> 'Finalizado'
                 AND s.IdPais = @IdPais)
        THROW 50002, 'Con el nuevo pais el arbitro tendria la misma nacionalidad que una seleccion de un partido en el que esta designado. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Arbitraje.Arbitro
        SET CodigoExterno   = LTRIM(RTRIM(@CodigoExterno)),
            Nombre          = LTRIM(RTRIM(@Nombre)),
            Apellido        = LTRIM(RTRIM(@Apellido)),
            FechaNacimiento = @FechaNacimiento,
            IdPais          = @IdPais,
            Categoria       = @Categoria
        WHERE IdArbitro = @IdArbitro;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si el arbitro no tiene designaciones (el historial
-- no se pierde). Sus idiomas se borran por la clave foranea ON DELETE CASCADE.
CREATE OR ALTER PROCEDURE Arbitraje.usp_Arbitro_Baja
    @IdArbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro)
        SET @errores += 'El arbitro indicado no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral WHERE IdArbitro = @IdArbitro)
        SET @errores += 'El arbitro tiene designaciones registradas. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar el arbitro: otros registros dependen de el. ', 1;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 ARBITRO IDIOMA
 La clave es (IdArbitro, Idioma): la modificacion cambia un idioma por otro.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Arbitraje.usp_ArbitroIdioma_Alta
    @IdArbitro INT,
    @Idioma    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro)
        SET @errores += 'El arbitro indicado no existe. ';

    IF @Idioma IS NULL OR LTRIM(RTRIM(@Idioma)) = ''
        SET @errores += 'El idioma es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroIdioma
                    WHERE IdArbitro = @IdArbitro AND Idioma = LTRIM(RTRIM(@Idioma)))
        SET @errores += 'El arbitro ya tiene registrado ese idioma. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Arbitraje.ArbitroIdioma (IdArbitro, Idioma)
        VALUES (@IdArbitro, LTRIM(RTRIM(@Idioma)));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Arbitraje.usp_ArbitroIdioma_Modificacion
    @IdArbitro   INT,
    @Idioma      VARCHAR(10),
    @IdiomaNuevo VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM Arbitraje.ArbitroIdioma WHERE IdArbitro = @IdArbitro AND Idioma = @Idioma)
        SET @errores += 'El arbitro no tiene registrado el idioma a modificar. ';

    IF @IdiomaNuevo IS NULL OR LTRIM(RTRIM(@IdiomaNuevo)) = ''
        SET @errores += 'El idioma nuevo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroIdioma
                    WHERE IdArbitro = @IdArbitro AND Idioma = LTRIM(RTRIM(@IdiomaNuevo)))
        SET @errores += 'El arbitro ya tiene registrado el idioma nuevo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Arbitraje.ArbitroIdioma
        SET Idioma = LTRIM(RTRIM(@IdiomaNuevo))
        WHERE IdArbitro = @IdArbitro
          AND Idioma = @Idioma;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Arbitraje.usp_ArbitroIdioma_Baja
    @IdArbitro INT,
    @Idioma    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM Arbitraje.ArbitroIdioma WHERE IdArbitro = @IdArbitro AND Idioma = @Idioma)
        SET @errores += 'El arbitro no tiene registrado ese idioma. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Arbitraje.ArbitroIdioma
        WHERE IdArbitro = @IdArbitro
          AND Idioma = @Idioma;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 DESIGNACION ARBITRAL
 - No se designan arbitros en un partido Finalizado.
 - Cada rol se cubre una sola vez por partido y un arbitro cumple un solo rol.
 - Conflicto de nacionalidad (error 50002): el arbitro no puede ser del mismo
   pais que una de las selecciones del partido. Se controla despues de las
   validaciones de datos.
 - El informe post-partido y la sancion se cargan con el partido Finalizado; a
   partir de ese momento ya no se cambian ni el arbitro ni el rol.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Arbitraje.usp_DesignacionArbitral_Alta
    @IdPartido     INT,
    @IdArbitro     INT,
    @RolArbitral   VARCHAR(20),
    @IdDesignacion INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estadoPartido VARCHAR(20), @idPaisArbitro INT;

    SELECT @estadoPartido = Estado FROM Torneo.Partido WHERE IdPartido = @IdPartido;
    SELECT @idPaisArbitro = IdPais FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro;

    IF @estadoPartido IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @estadoPartido = 'Finalizado'
        SET @errores += 'No se pueden designar arbitros en un partido Finalizado. ';

    IF @idPaisArbitro IS NULL
        SET @errores += 'El arbitro indicado no existe. ';

    IF @RolArbitral IS NULL OR @RolArbitral NOT IN ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR')
        SET @errores += 'El rol debe ser Principal, Asistente 1, Asistente 2, Cuarto o VAR. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral WHERE IdPartido = @IdPartido AND RolArbitral = @RolArbitral)
        SET @errores += 'Ese rol ya esta cubierto en el partido. ';

    IF EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral WHERE IdPartido = @IdPartido AND IdArbitro = @IdArbitro)
        SET @errores += 'El arbitro ya tiene otro rol en el partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF EXISTS (SELECT 1
               FROM Torneo.Partido p
               JOIN Torneo.Seleccion s ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
               WHERE p.IdPartido = @IdPartido
                 AND s.IdPais = @idPaisArbitro)
        THROW 50002, 'Conflicto de nacionalidad: el arbitro es del mismo pais que una de las selecciones del partido. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Arbitraje.DesignacionArbitral (IdPartido, IdArbitro, RolArbitral)
        VALUES (@IdPartido, @IdArbitro, @RolArbitral);

        SET @IdDesignacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Modificacion completa. Antes de que termine el partido se puede cambiar el
-- arbitro o el rol, y el informe y la sancion van en NULL. Con el partido
-- Finalizado el arbitro y el rol tienen que ser los mismos, y se cargan el
-- informe post-partido y la sancion.
CREATE OR ALTER PROCEDURE Arbitraje.usp_DesignacionArbitral_Modificacion
    @IdDesignacion      INT,
    @IdArbitro          INT,
    @RolArbitral        VARCHAR(20),
    @InformePostPartido VARCHAR(500) = NULL,
    @Sancion            VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idPartido INT, @estadoPartido VARCHAR(20), @idArbitroActual INT, @rolActual VARCHAR(20), @idPaisArbitro INT;

    SELECT @idPartido       = d.IdPartido,
           @estadoPartido   = p.Estado,
           @idArbitroActual = d.IdArbitro,
           @rolActual       = d.RolArbitral
    FROM Arbitraje.DesignacionArbitral d
    JOIN Torneo.Partido p ON p.IdPartido = d.IdPartido
    WHERE d.IdDesignacion = @IdDesignacion;

    SELECT @idPaisArbitro = IdPais FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro;

    IF @idPartido IS NULL
        SET @errores += 'La designacion indicada no existe. ';

    IF @idPaisArbitro IS NULL
        SET @errores += 'El arbitro indicado no existe. ';

    IF @RolArbitral IS NULL OR @RolArbitral NOT IN ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR')
        SET @errores += 'El rol debe ser Principal, Asistente 1, Asistente 2, Cuarto o VAR. ';

    IF @estadoPartido = 'Finalizado'
    BEGIN
        IF @IdArbitro <> @idArbitroActual OR @RolArbitral <> @rolActual
            SET @errores += 'Con el partido finalizado no se pueden cambiar el arbitro ni el rol. ';
    END
    ELSE IF @idPartido IS NOT NULL
    BEGIN
        IF @InformePostPartido IS NOT NULL OR @Sancion IS NOT NULL
            SET @errores += 'El informe post-partido y la sancion se cargan cuando el partido esta Finalizado. ';

        IF EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral
                   WHERE IdPartido = @idPartido AND RolArbitral = @RolArbitral AND IdDesignacion <> @IdDesignacion)
            SET @errores += 'Ese rol ya esta cubierto en el partido. ';

        IF EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral
                   WHERE IdPartido = @idPartido AND IdArbitro = @IdArbitro AND IdDesignacion <> @IdDesignacion)
            SET @errores += 'El arbitro ya tiene otro rol en el partido. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @estadoPartido <> 'Finalizado'
       AND EXISTS (SELECT 1
                   FROM Torneo.Partido p
                   JOIN Torneo.Seleccion s ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
                   WHERE p.IdPartido = @idPartido
                     AND s.IdPais = @idPaisArbitro)
        THROW 50002, 'Conflicto de nacionalidad: el arbitro es del mismo pais que una de las selecciones del partido. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Arbitraje.DesignacionArbitral
        SET IdArbitro          = @IdArbitro,
            RolArbitral        = @RolArbitral,
            InformePostPartido = NULLIF(LTRIM(RTRIM(@InformePostPartido)), ''),
            Sancion            = NULLIF(LTRIM(RTRIM(@Sancion)), '')
        WHERE IdDesignacion = @IdDesignacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si el partido no esta Finalizado (la designacion de
-- un partido jugado forma parte del historial).
CREATE OR ALTER PROCEDURE Arbitraje.usp_DesignacionArbitral_Baja
    @IdDesignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estadoPartido VARCHAR(20);

    SELECT @estadoPartido = p.Estado
    FROM Arbitraje.DesignacionArbitral d
    JOIN Torneo.Partido p ON p.IdPartido = d.IdPartido
    WHERE d.IdDesignacion = @IdDesignacion;

    IF @estadoPartido IS NULL
        SET @errores += 'La designacion indicada no existe. ';
    ELSE IF @estadoPartido = 'Finalizado'
        SET @errores += 'El partido esta finalizado: la designacion forma parte del historial y no se elimina. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Arbitraje.DesignacionArbitral WHERE IdDesignacion = @IdDesignacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
