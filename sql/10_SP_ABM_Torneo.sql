/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 10_SP_ABM_Torneo.sql
 Objetivo     : Procedimientos de alta, baja y modificacion de Pais, Sede y Partido.
                Cada SP informa en un unico mensaje todas las validaciones que no
                se cumplen. La baja es un borrado real, permitido solo si ningun
                otro registro depende de la fila.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 PAIS
 El huso horario es un nombre de zona horaria de Windows (por ejemplo
 'Argentina Standard Time'): se valida contra sys.time_zone_info, la misma lista
 que usa AT TIME ZONE.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Pais_Alta
    @CodigoIso3      VARCHAR(10),
    @Nombre          VARCHAR(80),
    @Confederacion   VARCHAR(10),
    @HusoHorario     VARCHAR(60),
    @PibPerCapitaUsd DECIMAL(18, 2) = NULL,
    @AnioPib         INT            = NULL,
    @IdPais          INT            = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @CodigoIso3 IS NULL OR @CodigoIso3 NOT LIKE '[A-Za-z][A-Za-z][A-Za-z]'
        SET @errores += 'El codigo ISO debe tener exactamente 3 letras. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Pais WHERE CodigoIso3 = @CodigoIso3)
        SET @errores += 'Ya existe un pais con ese codigo ISO. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Pais WHERE Nombre = LTRIM(RTRIM(@Nombre)))
        SET @errores += 'Ya existe un pais con ese nombre. ';

    IF @Confederacion IS NULL OR @Confederacion NOT IN ('UEFA', 'CONMEBOL', 'CONCACAF', 'CAF', 'AFC', 'OFC')
        SET @errores += 'La confederacion debe ser UEFA, CONMEBOL, CONCACAF, CAF, AFC u OFC. ';

    IF @HusoHorario IS NULL OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @HusoHorario)
        SET @errores += 'El huso horario debe ser una zona horaria de Windows valida (por ejemplo Argentina Standard Time). ';

    IF @PibPerCapitaUsd IS NOT NULL AND @PibPerCapitaUsd < 0
        SET @errores += 'El PIB per capita no puede ser negativo. ';

    IF @PibPerCapitaUsd IS NOT NULL AND (@AnioPib IS NULL OR @AnioPib NOT BETWEEN 1960 AND YEAR(GETDATE()))
        SET @errores += 'Si se informa el PIB, el anio debe estar entre 1960 y el anio actual. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Pais (CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib)
        VALUES (UPPER(@CodigoIso3), LTRIM(RTRIM(@Nombre)), @Confederacion, @HusoHorario, @PibPerCapitaUsd, @AnioPib);

        SET @IdPais = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Modificacion completa: se envian todos los datos y se reemplazan todos.
CREATE OR ALTER PROCEDURE Torneo.usp_Pais_Modificacion
    @IdPais          INT,
    @CodigoIso3      VARCHAR(10),
    @Nombre          VARCHAR(80),
    @Confederacion   VARCHAR(10),
    @HusoHorario     VARCHAR(60),
    @PibPerCapitaUsd DECIMAL(18, 2) = NULL,
    @AnioPib         INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @CodigoIso3 IS NULL OR @CodigoIso3 NOT LIKE '[A-Za-z][A-Za-z][A-Za-z]'
        SET @errores += 'El codigo ISO debe tener exactamente 3 letras. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Pais WHERE CodigoIso3 = @CodigoIso3 AND IdPais <> @IdPais)
        SET @errores += 'Ya existe otro pais con ese codigo ISO. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Pais WHERE Nombre = LTRIM(RTRIM(@Nombre)) AND IdPais <> @IdPais)
        SET @errores += 'Ya existe otro pais con ese nombre. ';

    IF @Confederacion IS NULL OR @Confederacion NOT IN ('UEFA', 'CONMEBOL', 'CONCACAF', 'CAF', 'AFC', 'OFC')
        SET @errores += 'La confederacion debe ser UEFA, CONMEBOL, CONCACAF, CAF, AFC u OFC. ';

    IF @HusoHorario IS NULL OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @HusoHorario)
        SET @errores += 'El huso horario debe ser una zona horaria de Windows valida (por ejemplo Argentina Standard Time). ';

    IF @PibPerCapitaUsd IS NOT NULL AND @PibPerCapitaUsd < 0
        SET @errores += 'El PIB per capita no puede ser negativo. ';

    IF @PibPerCapitaUsd IS NOT NULL AND (@AnioPib IS NULL OR @AnioPib NOT BETWEEN 1960 AND YEAR(GETDATE()))
        SET @errores += 'Si se informa el PIB, el anio debe estar entre 1960 y el anio actual. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Pais
        SET CodigoIso3      = UPPER(@CodigoIso3),
            Nombre          = LTRIM(RTRIM(@Nombre)),
            Confederacion   = @Confederacion,
            HusoHorario     = @HusoHorario,
            PibPerCapitaUsd = @PibPerCapitaUsd,
            AnioPib         = @AnioPib
        WHERE IdPais = @IdPais;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real. Solo si ninguna sede, seleccion ni jugador usa el pais.
-- Los registros de otros modulos (por ejemplo arbitros) los frena la clave
-- foranea (error 547), que se informa con un mensaje claro.
CREATE OR ALTER PROCEDURE Torneo.usp_Pais_Baja
    @IdPais INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdPais = @IdPais)
            SET @errores += 'El pais tiene sedes registradas. ';
        IF EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdPais = @IdPais)
            SET @errores += 'El pais tiene una seleccion registrada. ';
        IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdPais = @IdPais)
            SET @errores += 'El pais es la nacionalidad de jugadores registrados. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Torneo.Pais WHERE IdPais = @IdPais;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar el pais: otros registros dependen de el. ', 1;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 SEDE
 CodigoExterno es obligatorio: la columna es UNIQUE y SQL Server admite un solo
 NULL en una columna UNIQUE.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Sede_Alta
    @CodigoExterno VARCHAR(30),
    @NombreEstadio VARCHAR(120),
    @Ciudad        VARCHAR(80),
    @IdPais        INT,
    @HusoHorario   VARCHAR(60),
    @Capacidad     INT,
    @IdSede        INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Sede WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe una sede con ese codigo externo. ';

    IF @NombreEstadio IS NULL OR LTRIM(RTRIM(@NombreEstadio)) = ''
        SET @errores += 'El nombre del estadio es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Sede WHERE NombreEstadio = LTRIM(RTRIM(@NombreEstadio)))
        SET @errores += 'Ya existe una sede con ese nombre de estadio. ';

    IF @Ciudad IS NULL OR LTRIM(RTRIM(@Ciudad)) = ''
        SET @errores += 'La ciudad es obligatoria. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @HusoHorario IS NULL OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @HusoHorario)
        SET @errores += 'El huso horario debe ser una zona horaria de Windows valida (por ejemplo Argentina Standard Time). ';

    IF @Capacidad IS NULL OR @Capacidad <= 0
        SET @errores += 'La capacidad debe ser mayor a cero. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Sede (CodigoExterno, NombreEstadio, Ciudad, IdPais, HusoHorario, Capacidad)
        VALUES (LTRIM(RTRIM(@CodigoExterno)), LTRIM(RTRIM(@NombreEstadio)), LTRIM(RTRIM(@Ciudad)),
                @IdPais, @HusoHorario, @Capacidad);

        SET @IdSede = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Torneo.usp_Sede_Modificacion
    @IdSede        INT,
    @CodigoExterno VARCHAR(30),
    @NombreEstadio VARCHAR(120),
    @Ciudad        VARCHAR(80),
    @IdPais        INT,
    @HusoHorario   VARCHAR(60),
    @Capacidad     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSede IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede)
        SET @errores += 'La sede indicada no existe. ';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Sede WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdSede <> @IdSede)
        SET @errores += 'Ya existe otra sede con ese codigo externo. ';

    IF @NombreEstadio IS NULL OR LTRIM(RTRIM(@NombreEstadio)) = ''
        SET @errores += 'El nombre del estadio es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Sede WHERE NombreEstadio = LTRIM(RTRIM(@NombreEstadio)) AND IdSede <> @IdSede)
        SET @errores += 'Ya existe otra sede con ese nombre de estadio. ';

    IF @Ciudad IS NULL OR LTRIM(RTRIM(@Ciudad)) = ''
        SET @errores += 'La ciudad es obligatoria. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @HusoHorario IS NULL OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @HusoHorario)
        SET @errores += 'El huso horario debe ser una zona horaria de Windows valida (por ejemplo Argentina Standard Time). ';

    IF @Capacidad IS NULL OR @Capacidad <= 0
        SET @errores += 'La capacidad debe ser mayor a cero. ';

    -- Cambiar el huso de una sede con partidos dejaria mal la hora local ya guardada
    IF @errores = ''
       AND EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede AND HusoHorario <> @HusoHorario)
       AND EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdSede = @IdSede)
        SET @errores += 'No se puede cambiar el huso horario de una sede que ya tiene partidos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Sede
        SET CodigoExterno = LTRIM(RTRIM(@CodigoExterno)),
            NombreEstadio = LTRIM(RTRIM(@NombreEstadio)),
            Ciudad        = LTRIM(RTRIM(@Ciudad)),
            IdPais        = @IdPais,
            HusoHorario   = @HusoHorario,
            Capacidad     = @Capacidad
        WHERE IdSede = @IdSede;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Torneo.usp_Sede_Baja
    @IdSede INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSede IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede)
        SET @errores += 'La sede indicada no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdSede = @IdSede)
        SET @errores += 'La sede tiene partidos registrados. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Torneo.Sede WHERE IdSede = @IdSede;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar la sede: otros registros dependen de ella. ', 1;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 PARTIDO
 - Un partido nuevo siempre arranca 'Programado' y sin resultado: el marcador lo
   calculan los SP de goles, y el estado lo cambia la logica de partidos.
 - La hora local no se recibe: se calcula desde la hora UTC y el huso de la sede,
   asi nunca puede quedar incoherente con la UTC.
 - Dos partidos en la misma sede deben estar separados por al menos
   @margenMinutos minutos.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Partido_Alta
    @CodigoExterno           VARCHAR(30),
    @NumeroPartido           INT,
    @Fase                    VARCHAR(20),
    @IdSede                  INT,
    @FechaHoraUtc            DATETIME2,
    @IdSeleccionLocal        INT         = NULL,
    @IdSeleccionVisitante    INT         = NULL,
    @EsquemaTacticoLocal     VARCHAR(20) = NULL,
    @EsquemaTacticoVisitante VARCHAR(20) = NULL,
    @IdPartido               INT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @margenMinutos INT = 180;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @husoSede VARCHAR(60), @fechaHoraLocal DATETIME2;

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe un partido con ese codigo externo. ';

    IF @NumeroPartido IS NULL OR @NumeroPartido <= 0
        SET @errores += 'El numero de partido debe ser mayor a cero. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE NumeroPartido = @NumeroPartido)
        SET @errores += 'Ya existe un partido con ese numero. ';

    IF @Fase IS NULL OR @Fase NOT IN ('Grupos', 'Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
        SET @errores += 'La fase debe ser Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final. ';

    IF @IdSede IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede)
        SET @errores += 'La sede indicada no existe. ';

    IF @IdSeleccionLocal IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccionLocal)
        SET @errores += 'La seleccion local no existe. ';

    IF @IdSeleccionVisitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccionVisitante)
        SET @errores += 'La seleccion visitante no existe. ';

    IF @IdSeleccionLocal IS NOT NULL AND @IdSeleccionLocal = @IdSeleccionVisitante
        SET @errores += 'La seleccion local y la visitante deben ser distintas. ';

    IF @Fase = 'Grupos' AND (@IdSeleccionLocal IS NULL OR @IdSeleccionVisitante IS NULL)
        SET @errores += 'En la fase de grupos deben estar definidas las dos selecciones. ';

    IF @FechaHoraUtc IS NULL
        SET @errores += 'La fecha y hora UTC son obligatorias. ';
    ELSE IF @IdSede IS NOT NULL
         AND EXISTS (SELECT 1
                     FROM Torneo.Partido
                     WHERE IdSede = @IdSede
                       AND ABS(DATEDIFF(MINUTE, FechaHoraUtc, @FechaHoraUtc)) < @margenMinutos)
        SET @errores += 'Ya hay otro partido en esa sede con menos de 180 minutos de diferencia. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SELECT @husoSede = HusoHorario FROM Torneo.Sede WHERE IdSede = @IdSede;
    SET @fechaHoraLocal = CAST((@FechaHoraUtc AT TIME ZONE 'UTC') AT TIME ZONE @husoSede AS DATETIME2);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Partido (CodigoExterno, NumeroPartido, Fase, IdSede, IdSeleccionLocal, IdSeleccionVisitante,
                                    EsquemaTacticoLocal, EsquemaTacticoVisitante, FechaHoraUtc, FechaHoraLocal, Estado)
        VALUES (LTRIM(RTRIM(@CodigoExterno)), @NumeroPartido, @Fase, @IdSede, @IdSeleccionLocal, @IdSeleccionVisitante,
                @EsquemaTacticoLocal, @EsquemaTacticoVisitante, @FechaHoraUtc, @fechaHoraLocal, 'Programado');

        SET @IdPartido = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Solo se modifican partidos 'Programado'. No toca estado ni resultado.
CREATE OR ALTER PROCEDURE Torneo.usp_Partido_Modificacion
    @IdPartido               INT,
    @CodigoExterno           VARCHAR(30),
    @NumeroPartido           INT,
    @Fase                    VARCHAR(20),
    @IdSede                  INT,
    @FechaHoraUtc            DATETIME2,
    @IdSeleccionLocal        INT         = NULL,
    @IdSeleccionVisitante    INT         = NULL,
    @EsquemaTacticoLocal     VARCHAR(20) = NULL,
    @EsquemaTacticoVisitante VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @margenMinutos INT = 180;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @husoSede VARCHAR(60), @fechaHoraLocal DATETIME2;

    IF @IdPartido IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdPartido = @IdPartido)
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdPartido = @IdPartido AND Estado <> 'Programado')
        SET @errores += 'Solo se pueden modificar partidos en estado Programado. ';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdPartido <> @IdPartido)
        SET @errores += 'Ya existe otro partido con ese codigo externo. ';

    IF @NumeroPartido IS NULL OR @NumeroPartido <= 0
        SET @errores += 'El numero de partido debe ser mayor a cero. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE NumeroPartido = @NumeroPartido AND IdPartido <> @IdPartido)
        SET @errores += 'Ya existe otro partido con ese numero. ';

    IF @Fase IS NULL OR @Fase NOT IN ('Grupos', 'Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
        SET @errores += 'La fase debe ser Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final. ';

    IF @IdSede IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede)
        SET @errores += 'La sede indicada no existe. ';

    IF @IdSeleccionLocal IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccionLocal)
        SET @errores += 'La seleccion local no existe. ';

    IF @IdSeleccionVisitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccionVisitante)
        SET @errores += 'La seleccion visitante no existe. ';

    IF @IdSeleccionLocal IS NOT NULL AND @IdSeleccionLocal = @IdSeleccionVisitante
        SET @errores += 'La seleccion local y la visitante deben ser distintas. ';

    IF @Fase = 'Grupos' AND (@IdSeleccionLocal IS NULL OR @IdSeleccionVisitante IS NULL)
        SET @errores += 'En la fase de grupos deben estar definidas las dos selecciones. ';

    IF @FechaHoraUtc IS NULL
        SET @errores += 'La fecha y hora UTC son obligatorias. ';
    ELSE IF @IdSede IS NOT NULL
         AND EXISTS (SELECT 1
                     FROM Torneo.Partido
                     WHERE IdSede = @IdSede
                       AND IdPartido <> @IdPartido
                       AND ABS(DATEDIFF(MINUTE, FechaHoraUtc, @FechaHoraUtc)) < @margenMinutos)
        SET @errores += 'Ya hay otro partido en esa sede con menos de 180 minutos de diferencia. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SELECT @husoSede = HusoHorario FROM Torneo.Sede WHERE IdSede = @IdSede;
    SET @fechaHoraLocal = CAST((@FechaHoraUtc AT TIME ZONE 'UTC') AT TIME ZONE @husoSede AS DATETIME2);

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Partido
        SET CodigoExterno           = LTRIM(RTRIM(@CodigoExterno)),
            NumeroPartido           = @NumeroPartido,
            Fase                    = @Fase,
            IdSede                  = @IdSede,
            IdSeleccionLocal        = @IdSeleccionLocal,
            IdSeleccionVisitante    = @IdSeleccionVisitante,
            EsquemaTacticoLocal     = @EsquemaTacticoLocal,
            EsquemaTacticoVisitante = @EsquemaTacticoVisitante,
            FechaHoraUtc            = @FechaHoraUtc,
            FechaHoraLocal          = @fechaHoraLocal
        WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: solo un partido Programado y sin marcador cargado. Alineaciones,
-- tarjetas o designaciones de otros modulos las frena la clave foranea.
CREATE OR ALTER PROCEDURE Torneo.usp_Partido_Baja
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPartido IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdPartido = @IdPartido)
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF EXISTS (SELECT 1
                    FROM Torneo.Partido
                    WHERE IdPartido = @IdPartido
                      AND (Estado <> 'Programado' OR GolesLocal IS NOT NULL OR GolesVisitante IS NOT NULL))
        SET @errores += 'Solo se puede eliminar un partido Programado y sin resultado. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Torneo.Partido WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547
            THROW 50001, 'No se puede eliminar el partido: otros registros dependen de el. ', 1;
        THROW;
    END CATCH
END
GO
