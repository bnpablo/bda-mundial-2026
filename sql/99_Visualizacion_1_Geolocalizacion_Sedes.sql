/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-25
 Script       : 99_Visualizacion_1_Geolocalizacion_Sedes.sql
 Objetivo     : Entrega 9. Agrega la geolocalizacion a Torneo.Sede (Latitud y Longitud)
                para mostrar las sedes en un mapa, y modifica los SP de alta y
                modificacion de sede para que las reciban (opcionales, con sus
                validaciones). Carga las coordenadas de las 8 sedes de los datos de
                aceptacion usando el SP de modificacion.
                Se puede ejecutar mas de una vez.
 Requisito    : ejecutar despues de 99_Datos_Aceptacion.sql.
==============================================================================*/
USE MundialDB;
GO

-- Columnas y restricciones. La latitud y la longitud van siempre juntas.
IF COL_LENGTH('Torneo.Sede', 'Latitud') IS NULL
    ALTER TABLE Torneo.Sede ADD Latitud DECIMAL (9, 6) NULL;
IF COL_LENGTH('Torneo.Sede', 'Longitud') IS NULL
    ALTER TABLE Torneo.Sede ADD Longitud DECIMAL (9, 6) NULL;
GO

IF OBJECT_ID('Torneo.CK_Sede_Coordenadas') IS NULL
    ALTER TABLE Torneo.Sede ADD CONSTRAINT CK_Sede_Coordenadas
        CHECK (Latitud BETWEEN -90 AND 90 AND Longitud BETWEEN -180 AND 180);

IF OBJECT_ID('Torneo.CK_Sede_CoordenadasCompletas') IS NULL
    ALTER TABLE Torneo.Sede ADD CONSTRAINT CK_Sede_CoordenadasCompletas
        CHECK ((Latitud IS NULL AND Longitud IS NULL)
               OR (Latitud IS NOT NULL AND Longitud IS NOT NULL));
GO

/*------------------------------------------------------------------------------
 Torneo.usp_Sede_Alta
 Mismos parametros y validaciones que antes. @Latitud y @Longitud se agregan al
 final y son opcionales, asi que las llamadas existentes siguen funcionando.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Sede_Alta
    @CodigoExterno VARCHAR(30),
    @NombreEstadio VARCHAR(120),
    @Ciudad        VARCHAR(80),
    @IdPais        INT,
    @HusoHorario   VARCHAR(60),
    @Capacidad     INT,
    @IdSede        INT           = NULL OUTPUT,
    @Latitud       DECIMAL(9, 6) = NULL,
    @Longitud      DECIMAL(9, 6) = NULL
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

    IF (@Latitud IS NULL AND @Longitud IS NOT NULL) OR (@Latitud IS NOT NULL AND @Longitud IS NULL)
        SET @errores += 'La latitud y la longitud se informan juntas. ';
    ELSE IF @Latitud NOT BETWEEN -90 AND 90 OR @Longitud NOT BETWEEN -180 AND 180
        SET @errores += 'La latitud debe estar entre -90 y 90 y la longitud entre -180 y 180. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Sede (CodigoExterno, NombreEstadio, Ciudad, IdPais, HusoHorario, Capacidad, Latitud, Longitud)
        VALUES (LTRIM(RTRIM(@CodigoExterno)), LTRIM(RTRIM(@NombreEstadio)), LTRIM(RTRIM(@Ciudad)),
                @IdPais, @HusoHorario, @Capacidad, @Latitud, @Longitud);

        SET @IdSede = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Torneo.usp_Sede_Modificacion
 Modificacion completa: se envian todos los datos y se reemplazan todos, tambien
 las coordenadas (si no se informan, la sede queda sin ubicacion).
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Sede_Modificacion
    @IdSede        INT,
    @CodigoExterno VARCHAR(30),
    @NombreEstadio VARCHAR(120),
    @Ciudad        VARCHAR(80),
    @IdPais        INT,
    @HusoHorario   VARCHAR(60),
    @Capacidad     INT,
    @Latitud       DECIMAL(9, 6) = NULL,
    @Longitud      DECIMAL(9, 6) = NULL
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

    IF (@Latitud IS NULL AND @Longitud IS NOT NULL) OR (@Latitud IS NOT NULL AND @Longitud IS NULL)
        SET @errores += 'La latitud y la longitud se informan juntas. ';
    ELSE IF @Latitud NOT BETWEEN -90 AND 90 OR @Longitud NOT BETWEEN -180 AND 180
        SET @errores += 'La latitud debe estar entre -90 y 90 y la longitud entre -180 y 180. ';

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
            Capacidad     = @Capacidad,
            Latitud       = @Latitud,
            Longitud      = @Longitud
        WHERE IdSede = @IdSede;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Coordenadas de las 8 sedes de los datos de aceptacion (centro de cada estadio).
 Se aplican con el SP de modificacion, tomando del resto de las columnas el valor
 que ya tiene la sede. Las sedes que no estan en la lista no se tocan.
------------------------------------------------------------------------------*/
SET NOCOUNT ON;

CREATE TABLE #Coordenadas (
    Orden         INT IDENTITY (1, 1),
    CodigoExterno VARCHAR (30),
    Latitud       DECIMAL (9, 6),
    Longitud      DECIMAL (9, 6)
);

INSERT INTO #Coordenadas (CodigoExterno, Latitud, Longitud)
VALUES ('AC-SEDE-01', 19.302900, -99.150500),    -- Estadio Banorte, Ciudad de Mexico
       ('AC-SEDE-02', 32.747300, -97.094500),    -- AT&T Stadium, Dallas
       ('AC-SEDE-03', 25.958000, -80.238900),    -- Hard Rock Stadium, Miami
       ('AC-SEDE-04', 47.595200, -122.331600),   -- Lumen Field, Seattle
       ('AC-SEDE-05', 49.276800, -123.112000),   -- BC Place, Vancouver
       ('AC-SEDE-06', 43.633200, -79.418600),    -- BMO Field, Toronto
       ('AC-SEDE-07', 25.669200, -100.244700),   -- Estadio BBVA, Monterrey
       ('AC-SEDE-08', 37.403300, -121.969400);   -- Levis Stadium, Santa Clara

DECLARE @i INT = 1, @cantidad INT = (SELECT COUNT(*) FROM #Coordenadas);
DECLARE @IdSede INT, @Codigo VARCHAR(30), @Estadio VARCHAR(120), @Ciudad VARCHAR(80), @IdPais INT,
        @Huso VARCHAR(60), @Capacidad INT, @Lat DECIMAL(9, 6), @Lon DECIMAL(9, 6);

WHILE @i <= @cantidad
BEGIN
    SET @IdSede = NULL;

    SELECT @IdSede = s.IdSede, @Codigo = s.CodigoExterno, @Estadio = s.NombreEstadio, @Ciudad = s.Ciudad,
           @IdPais = s.IdPais, @Huso = s.HusoHorario, @Capacidad = s.Capacidad,
           @Lat = c.Latitud, @Lon = c.Longitud
    FROM #Coordenadas c
    JOIN Torneo.Sede s ON s.CodigoExterno = c.CodigoExterno
    WHERE c.Orden = @i;

    IF @IdSede IS NOT NULL
        EXEC Torneo.usp_Sede_Modificacion @IdSede, @Codigo, @Estadio, @Ciudad, @IdPais, @Huso, @Capacidad, @Lat, @Lon;

    SET @i += 1;
END

DROP TABLE #Coordenadas;

SELECT NombreEstadio, Ciudad, Latitud, Longitud FROM Torneo.Sede ORDER BY IdSede;
GO
