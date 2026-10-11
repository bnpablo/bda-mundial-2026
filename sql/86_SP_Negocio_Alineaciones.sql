/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 86_SP_Negocio_Alineaciones.sql
 Objetivo     : Logica de negocio de alineaciones y cambios. Cada SP valida todo
                primero (un unico mensaje, THROW 50001) y despues opera dentro de
                una transaccion:
                  Formacion.usp_RegistrarAlineacion  registra la alineacion completa
                                                     de una seleccion en un partido
                                                     (esquema tactico en Partido y
                                                     titulares y suplentes en
                                                     Alineacion, todo o nada).
                  Formacion.usp_RegistrarCambio      registra un cambio indicando los
                                                     jugadores (no las alineaciones),
                                                     solo en un partido En juego.
                  Formacion.usp_VerificarAlineacion  controla titulares, suplentes y
                                                     cambios de cada seleccion.
                La lista de jugadores de usp_RegistrarAlineacion se recibe como JSON
                (arreglo de objetos con IdJugador, EsTitular y PosicionCancha) y se
                procesa con OPENJSON, sin cursores ni SQL dinamico.
 Depende de   : 30_SP_ABM_Formacion.sql
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Formacion.usp_RegistrarAlineacion
 Reglas: el partido debe estar Programado o En juego; la seleccion debe jugar el
 partido y no tener alineacion registrada; el esquema tactico tiene la forma 4-3-3
 y suma 10 jugadores de campo; la lista tiene entre 11 y 26 jugadores, exactamente
 11 titulares y un solo arquero entre ellos; los jugadores existen, son de la
 seleccion, no se repiten y no estaban dados de baja a la fecha del partido.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Formacion.usp_RegistrarAlineacion
    @IdPartido      INT,
    @IdSeleccion    INT,
    @EsquemaTactico VARCHAR(20),
    @Jugadores      VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxTitulares INT = 11, @maxConvocados INT = 26;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(20), @idLocal INT, @idVisitante INT, @fechaPartido DATE;
    DECLARE @cantidad INT, @titulares INT;
    DECLARE @tmpJugadores TABLE (IdJugador INT NULL, EsTitular BIT NULL, PosicionCancha VARCHAR(50) NULL);

    SELECT @estado = Estado,
           @idLocal = IdSeleccionLocal,
           @idVisitante = IdSeleccionVisitante,
           @fechaPartido = CAST(FechaHoraUtc AS DATE)
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    -- Partido y seleccion
    IF @estado IS NULL
    BEGIN
        SET @errores += 'El partido indicado no existe. ';
    END
    ELSE
    BEGIN
        IF @estado NOT IN ('Programado', 'En juego')
            SET @errores += 'Solo se puede registrar la alineacion de un partido Programado o En juego. ';

        -- Las selecciones del partido pueden ser NULL (cruce por definir)
        IF @IdSeleccion IS NULL
           OR (@IdSeleccion <> ISNULL(@idLocal, -1) AND @IdSeleccion <> ISNULL(@idVisitante, -1))
            SET @errores += 'La seleccion indicada no juega este partido. ';
        ELSE IF EXISTS (SELECT 1
                        FROM Formacion.Alineacion a
                        JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdPartido AND j.IdSeleccion = @IdSeleccion)
            SET @errores += 'La seleccion ya tiene alineacion registrada en este partido. ';
    END;

    -- Esquema tactico: grupos de un digito separados por guiones que suman 10 (por ejemplo 4-3-3)
    IF @EsquemaTactico IS NULL OR LTRIM(RTRIM(@EsquemaTactico)) = ''
        SET @errores += 'El esquema tactico es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM STRING_SPLIT(@EsquemaTactico, '-') WHERE value NOT LIKE '[1-9]')
         OR (SELECT SUM(ISNULL(TRY_CAST(value AS INT), 0)) FROM STRING_SPLIT(@EsquemaTactico, '-')) <> 10
        SET @errores += 'El esquema tactico debe tener la forma 4-3-3 y sumar 10 jugadores de campo. ';

    -- Lista de jugadores
    IF @Jugadores IS NULL OR ISJSON(@Jugadores) = 0 OR LEFT(LTRIM(@Jugadores), 1) <> '['
    BEGIN
        SET @errores += 'La lista de jugadores debe ser un JSON valido: un arreglo de objetos con IdJugador, EsTitular y PosicionCancha. ';
    END
    ELSE
    BEGIN
        INSERT INTO @tmpJugadores (IdJugador, EsTitular, PosicionCancha)
        SELECT TRY_CAST(IdJugador AS INT), TRY_CAST(EsTitular AS BIT), PosicionCancha
        FROM OPENJSON(@Jugadores)
             WITH (IdJugador      VARCHAR(20) '$.IdJugador',
                   EsTitular      VARCHAR(10) '$.EsTitular',
                   PosicionCancha VARCHAR(50) '$.PosicionCancha');

        SELECT @cantidad = COUNT(*),
               @titulares = ISNULL(SUM(CASE WHEN EsTitular = 1 THEN 1 ELSE 0 END), 0)
        FROM @tmpJugadores;

        IF @cantidad NOT BETWEEN @maxTitulares AND @maxConvocados
            SET @errores += CONCAT('La alineacion debe tener entre ', @maxTitulares, ' y ', @maxConvocados, ' jugadores. ');

        IF @titulares <> @maxTitulares
            SET @errores += CONCAT('La alineacion debe tener exactamente ', @maxTitulares, ' titulares. ');

        IF (SELECT COUNT(*) FROM @tmpJugadores WHERE EsTitular = 1 AND PosicionCancha = 'POR') <> 1
            SET @errores += 'Debe haber exactamente un arquero (POR) entre los titulares. ';

        IF EXISTS (SELECT 1
                   FROM @tmpJugadores
                   WHERE IdJugador IS NULL OR EsTitular IS NULL OR PosicionCancha IS NULL
                      OR PosicionCancha NOT IN ('POR', 'DEF', 'MED', 'DEL'))
            SET @errores += 'Cada jugador debe informar IdJugador, EsTitular y una posicion valida (POR, DEF, MED o DEL). ';

        IF EXISTS (SELECT 1 FROM @tmpJugadores WHERE IdJugador IS NOT NULL GROUP BY IdJugador HAVING COUNT(*) > 1)
            SET @errores += 'Hay jugadores repetidos en la lista. ';

        IF @estado IS NOT NULL AND @IdSeleccion IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1
                       FROM @tmpJugadores t
                       LEFT JOIN Torneo.Jugador j ON j.IdJugador = t.IdJugador
                       WHERE t.IdJugador IS NOT NULL
                         AND (j.IdJugador IS NULL OR j.IdSeleccion <> @IdSeleccion))
                SET @errores += 'Hay jugadores que no existen o no pertenecen a la seleccion indicada. ';

            IF EXISTS (SELECT 1
                       FROM @tmpJugadores t
                       JOIN Torneo.Jugador j ON j.IdJugador = t.IdJugador
                       WHERE j.FechaBaja IS NOT NULL AND j.FechaBaja <= @fechaPartido)
                SET @errores += 'Hay jugadores dados de baja a la fecha del partido. ';
        END;
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Torneo.Partido
        SET EsquemaTacticoLocal     = CASE WHEN IdSeleccionLocal = @IdSeleccion THEN @EsquemaTactico ELSE EsquemaTacticoLocal END,
            EsquemaTacticoVisitante = CASE WHEN IdSeleccionVisitante = @IdSeleccion THEN @EsquemaTactico ELSE EsquemaTacticoVisitante END
        WHERE IdPartido = @IdPartido;

        INSERT INTO Formacion.Alineacion (IdPartido, IdJugador, EsTitular, PosicionCancha)
        SELECT @IdPartido, IdJugador, EsTitular, PosicionCancha
        FROM @tmpJugadores;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Formacion.usp_RegistrarCambio
 Un cambio solo se registra con el partido En juego, con los dos jugadores en la
 alineacion del partido, y con un periodo y un motivo validos (los del CHECK de
 Sustitucion). Las demas reglas (suplente que entra, titular o ingresado
 que sale, maximo de 5 cambios, etc.) son las de usp_Sustitucion_Alta.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Formacion.usp_RegistrarCambio
    @IdPartido       INT,
    @IdJugadorSale   INT,
    @IdJugadorEntra  INT,
    @Periodo         VARCHAR(30),
    @Minuto          INT,
    @Motivo          VARCHAR(20),
    @MinutoAdicional INT = 0,
    @NumeroVentana   INT = NULL,
    @IdSustitucion   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(20), @idAlineacionSale INT, @idAlineacionEntra INT;

    SELECT @estado = Estado FROM Torneo.Partido WHERE IdPartido = @IdPartido;

    SELECT @idAlineacionSale = IdAlineacion
    FROM Formacion.Alineacion
    WHERE IdPartido = @IdPartido AND IdJugador = @IdJugadorSale;

    SELECT @idAlineacionEntra = IdAlineacion
    FROM Formacion.Alineacion
    WHERE IdPartido = @IdPartido AND IdJugador = @IdJugadorEntra;

    IF @estado IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @estado <> 'En juego'
        SET @errores += 'Solo se pueden registrar cambios en un partido En juego. ';

    IF @idAlineacionSale IS NULL
        SET @errores += 'El jugador que sale no esta en la alineacion de este partido. ';

    IF @idAlineacionEntra IS NULL
        SET @errores += 'El jugador que entra no esta en la alineacion de este partido. ';

    IF @Periodo IS NULL OR @Periodo NOT IN ('Primer tiempo', 'Segundo tiempo', 'Alargue 1', 'Alargue 2')
        SET @errores += 'El periodo debe ser Primer tiempo, Segundo tiempo, Alargue 1 o Alargue 2. ';

    IF @Motivo IS NULL OR @Motivo NOT IN ('Tactico', 'Lesion', 'Otro')
        SET @errores += 'El motivo debe ser Tactico, Lesion u Otro. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @idAlineacionSale,
             @IdAlineacionEntra = @idAlineacionEntra, @Periodo = @Periodo, @Minuto = @Minuto,
             @Motivo = @Motivo, @MinutoAdicional = @MinutoAdicional, @NumeroVentana = @NumeroVentana,
             @IdSustitucion = @IdSustitucion OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdSustitucion = NULL;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Formacion.usp_VerificarAlineacion
 Control de la alineacion por partido: titulares, suplentes y cambios de cada
 seleccion. El estado es OK cuando la seleccion tiene los 11 titulares.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Formacion.usp_VerificarAlineacion
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @maxTitulares INT = 11;
    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPartido IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdPartido = @IdPartido)
        SET @errores += 'El partido indicado no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SELECT s.IdSeleccion,
           ISNULL(SUM(CASE WHEN a.EsTitular = 1 THEN 1 ELSE 0 END), 0) AS Titulares,
           ISNULL(SUM(CASE WHEN a.EsTitular = 0 THEN 1 ELSE 0 END), 0) AS Suplentes,
           (SELECT COUNT(*)
            FROM Formacion.Sustitucion su
            JOIN Formacion.Alineacion asale ON asale.IdAlineacion = su.IdAlineacionSale
            JOIN Torneo.Jugador jsale       ON jsale.IdJugador = asale.IdJugador
            WHERE asale.IdPartido = @IdPartido AND jsale.IdSeleccion = s.IdSeleccion) AS Cambios,
           CASE WHEN ISNULL(SUM(CASE WHEN a.EsTitular = 1 THEN 1 ELSE 0 END), 0) = @maxTitulares
                THEN 'OK' ELSE 'INCOMPLETA' END AS Estado
    FROM Torneo.Partido p
    CROSS APPLY (VALUES (p.IdSeleccionLocal), (p.IdSeleccionVisitante)) s(IdSeleccion)
    LEFT JOIN Torneo.Jugador j    ON j.IdSeleccion = s.IdSeleccion
    LEFT JOIN Formacion.Alineacion a ON a.IdJugador = j.IdJugador AND a.IdPartido = p.IdPartido
    WHERE p.IdPartido = @IdPartido AND s.IdSeleccion IS NOT NULL
    GROUP BY s.IdSeleccion;
END
GO
