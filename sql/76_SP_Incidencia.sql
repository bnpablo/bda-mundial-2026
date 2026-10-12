/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 76_SP_Incidencia.sql
 Objetivo     : Procedimientos de goles y tarjetas. El alta y la baja son logica de
                negocio porque tambien cambian otras filas (el marcador del partido
                o la roja por doble amarilla); la modificacion es un ABM simple:
                  Incidencia.usp_RecalcularMarcador   recalcula el resultado del partido.
                  Incidencia.usp_RegistrarGol         registra un gol y actualiza el marcador.
                  Incidencia.usp_AnularGol            anula un gol y actualiza el marcador.
                  Incidencia.usp_Gol_Modificacion     corrige tipo y minuto de un gol.
                  Incidencia.usp_RegistrarTarjeta     la segunda amarilla genera la roja.
                  Incidencia.usp_AnularTarjeta        si era la segunda amarilla, quita la roja.
                  Incidencia.usp_Tarjeta_Modificacion corrige minuto y motivo de una tarjeta.
                Los goles y las tarjetas se cargan, anulan y corrigen solo con el
                partido En juego (estados de 40_SP_Negocio_Partidos.sql).
 Prerrequisito: 75_Funciones_Incidencia.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Incidencia.usp_RecalcularMarcador
 Cuenta los goles registrados del partido y guarda el resultado (en lugar de
 sumar o restar 1), asi el marcador nunca queda distinto de la tabla Gol.
   - Un gol en contra suma para el rival del autor.
   - Los goles del periodo Penales van a PenalesLocal y PenalesVisitante; si no
     hubo definicion por penales, esas columnas quedan en NULL.
 Lo llaman usp_RegistrarGol y usp_AnularGol dentro de su transaccion.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Incidencia.usp_RecalcularMarcador
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @local INT, @visitante INT;
    DECLARE @golesLocal INT, @golesVisitante INT, @penalesLocal INT, @penalesVisitante INT;

    SELECT @local = IdSeleccionLocal, @visitante = IdSeleccionVisitante
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    IF @local IS NULL
        THROW 50001, 'El partido indicado no existe o no tiene selecciones definidas. ', 1;

    -- La subconsulta indica, para cada gol, a que seleccion le suma.
    SELECT @golesLocal       = SUM(CASE WHEN Periodo <> 'Penales' AND IdSeleccionSuma = @local     THEN 1 ELSE 0 END),
           @golesVisitante   = SUM(CASE WHEN Periodo <> 'Penales' AND IdSeleccionSuma = @visitante THEN 1 ELSE 0 END),
           @penalesLocal     = SUM(CASE WHEN Periodo =  'Penales' AND IdSeleccionSuma = @local     THEN 1 ELSE 0 END),
           @penalesVisitante = SUM(CASE WHEN Periodo =  'Penales' AND IdSeleccionSuma = @visitante THEN 1 ELSE 0 END)
    FROM (SELECT g.Periodo,
                 CASE WHEN g.TipoGol <> 'En contra' THEN j.IdSeleccion   -- suma para su seleccion
                      WHEN j.IdSeleccion = @local   THEN @visitante      -- en contra: suma para el rival
                      ELSE @local
                 END AS IdSeleccionSuma
          FROM Incidencia.Gol g
          JOIN Formacion.Alineacion a ON a.IdAlineacion = g.IdAlineacionAutor
          JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
          WHERE a.IdPartido = @IdPartido) goles;

    -- Sin goles, SUM devuelve NULL: el marcador queda 0 a 0 y los penales en NULL.
    UPDATE Torneo.Partido
    SET GolesLocal       = ISNULL(@golesLocal, 0),
        GolesVisitante   = ISNULL(@golesVisitante, 0),
        PenalesLocal     = CASE WHEN @penalesLocal + @penalesVisitante > 0 THEN @penalesLocal END,
        PenalesVisitante = CASE WHEN @penalesLocal + @penalesVisitante > 0 THEN @penalesVisitante END
    WHERE IdPartido = @IdPartido;
END
GO

/*------------------------------------------------------------------------------
 GOLES
 Incidencia.usp_RegistrarGol
   1. El autor esta alineado en un partido En juego.
   2. Tipo y periodo validos, y el minuto corresponde al periodo.
   3. En la fase de grupos no hay alargue ni definicion por penales.
   4. En la definicion por penales el tipo de gol es Penal.
   5. El autor estaba en cancha (titular o ingresado, no sustituido ni expulsado).
   6. Asistencia (opcional): es de un companero del autor que estaba en cancha,
      y no corresponde en un gol en contra ni en un penal de la definicion.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Incidencia.usp_RegistrarGol
    @IdAlineacionAutor     INT,
    @TipoGol               VARCHAR(20),
    @Periodo               VARCHAR(30),
    @Minuto                INT,
    @MinutoAdicional       INT = 0,
    @IdAlineacionAsistente INT = NULL,
    @IdGol                 INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idPartido INT, @estadoPartido VARCHAR(20), @fase VARCHAR(20), @seleccionAutor INT, @momento INT;
    DECLARE @partidoAsistente INT, @seleccionAsistente INT;

    SET @MinutoAdicional = ISNULL(@MinutoAdicional, 0);
    SET @momento = Incidencia.fn_MomentoPartido(@Periodo, @Minuto, @MinutoAdicional);

    SELECT @idPartido = p.IdPartido, @estadoPartido = p.Estado, @fase = p.Fase, @seleccionAutor = j.IdSeleccion
    FROM Formacion.Alineacion a
    JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
    JOIN Torneo.Partido p ON p.IdPartido = a.IdPartido
    WHERE a.IdAlineacion = @IdAlineacionAutor;

    -- 1. Autor y partido
    IF @idPartido IS NULL
        SET @errores += 'La alineacion del autor no existe. ';
    ELSE IF @estadoPartido <> 'En juego'
        SET @errores += 'Solo se pueden registrar goles en un partido En juego. ';

    -- 2. Tipo, periodo y minuto
    IF @TipoGol IS NULL OR @TipoGol NOT IN ('Jugada', 'Penal', 'Tiro libre', 'Cabezazo', 'En contra')
        SET @errores += 'El tipo de gol debe ser Jugada, Penal, Tiro libre, Cabezazo o En contra. ';

    IF @momento IS NULL
        SET @errores += 'El periodo debe ser Primer tiempo, Segundo tiempo, Alargue 1, Alargue 2 o Penales. ';
    ELSE IF Incidencia.fn_MinutoValido(@Periodo, @Minuto, @MinutoAdicional) = 0
        SET @errores += 'El minuto no corresponde al periodo ' + @Periodo + '. ';

    -- 3 y 4. Fase de grupos y definicion por penales
    IF @fase = 'Grupos' AND @Periodo IN ('Alargue 1', 'Alargue 2', 'Penales')
        SET @errores += 'En la fase de grupos no hay alargue ni definicion por penales. ';

    IF @Periodo = 'Penales' AND ISNULL(@TipoGol, '') <> 'Penal'
        SET @errores += 'En la definicion por penales el tipo de gol debe ser Penal. ';

    -- 5. El autor estaba en cancha
    IF @idPartido IS NOT NULL AND @momento IS NOT NULL
       AND Incidencia.fn_JugadorEnCancha(@IdAlineacionAutor, @momento) = 0
        SET @errores += 'El autor no estaba en cancha en ese momento del partido. ';

    -- 6. Asistencia
    IF @IdAlineacionAsistente IS NOT NULL
    BEGIN
        SELECT @partidoAsistente = a.IdPartido, @seleccionAsistente = j.IdSeleccion
        FROM Formacion.Alineacion a
        JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
        WHERE a.IdAlineacion = @IdAlineacionAsistente;

        IF @TipoGol = 'En contra' OR @Periodo = 'Penales'
            SET @errores += 'Un gol en contra o de la definicion por penales no tiene asistencia. ';

        IF @IdAlineacionAsistente = @IdAlineacionAutor
            SET @errores += 'El asistente no puede ser el autor del gol. ';
        ELSE IF @partidoAsistente IS NULL OR @partidoAsistente <> @idPartido OR @seleccionAsistente <> @seleccionAutor
            SET @errores += 'El asistente debe ser un companero del autor en el mismo partido. ';
        ELSE IF @momento IS NOT NULL AND Incidencia.fn_JugadorEnCancha(@IdAlineacionAsistente, @momento) = 0
            SET @errores += 'El asistente no estaba en cancha en ese momento del partido. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Incidencia.Gol (IdAlineacionAutor, IdAlineacionAsistente, TipoGol, Periodo, Minuto, MinutoAdicional)
        VALUES (@IdAlineacionAutor, @IdAlineacionAsistente, @TipoGol, @Periodo, @Minuto, @MinutoAdicional);

        SET @IdGol = SCOPE_IDENTITY();

        EXEC Incidencia.usp_RecalcularMarcador @IdPartido = @idPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdGol = NULL;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Incidencia.usp_AnularGol
    @IdGol INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idPartido INT, @estadoPartido VARCHAR(20);

    SELECT @idPartido = p.IdPartido, @estadoPartido = p.Estado
    FROM Incidencia.Gol g
    JOIN Formacion.Alineacion a ON a.IdAlineacion = g.IdAlineacionAutor
    JOIN Torneo.Partido p ON p.IdPartido = a.IdPartido
    WHERE g.IdGol = @IdGol;

    IF @idPartido IS NULL
        SET @errores += 'El gol indicado no existe. ';
    ELSE IF @estadoPartido <> 'En juego'
        SET @errores += 'Solo se pueden anular goles de un partido En juego. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Incidencia.Gol WHERE IdGol = @IdGol;

        EXEC Incidencia.usp_RecalcularMarcador @IdPartido = @idPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Incidencia.usp_Gol_Modificacion
 Corrige el tipo, el minuto y el minuto adicional de un gol (modificacion
 completa de esos tres datos). El autor, el periodo y la asistencia no se
 modifican, y un gol no se puede convertir en 'En contra' (ni al reves) porque
 cambiaria el resultado: en esos casos se anula el gol y se registra de nuevo.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Incidencia.usp_Gol_Modificacion
    @IdGol           INT,
    @TipoGol         VARCHAR(20),
    @Minuto          INT,
    @MinutoAdicional INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idAutor INT, @idAsistente INT, @tipoActual VARCHAR(20), @periodo VARCHAR(30), @estadoPartido VARCHAR(20), @momento INT;

    SET @MinutoAdicional = ISNULL(@MinutoAdicional, 0);

    SELECT @idAutor       = g.IdAlineacionAutor,
           @idAsistente   = g.IdAlineacionAsistente,
           @tipoActual    = g.TipoGol,
           @periodo       = g.Periodo,
           @estadoPartido = p.Estado
    FROM Incidencia.Gol g
    JOIN Formacion.Alineacion a ON a.IdAlineacion = g.IdAlineacionAutor
    JOIN Torneo.Partido p ON p.IdPartido = a.IdPartido
    WHERE g.IdGol = @IdGol;

    IF @idAutor IS NULL
        THROW 50001, 'El gol indicado no existe. ', 1;

    SET @momento = Incidencia.fn_MomentoPartido(@periodo, @Minuto, @MinutoAdicional);

    IF @estadoPartido <> 'En juego'
        SET @errores += 'Solo se pueden modificar goles de un partido En juego. ';

    IF @TipoGol IS NULL OR @TipoGol NOT IN ('Jugada', 'Penal', 'Tiro libre', 'Cabezazo', 'En contra')
        SET @errores += 'El tipo de gol debe ser Jugada, Penal, Tiro libre, Cabezazo o En contra. ';
    ELSE IF (@tipoActual = 'En contra' AND @TipoGol <> 'En contra')
            OR (@tipoActual <> 'En contra' AND @TipoGol = 'En contra')
        SET @errores += 'Cambiar un gol a En contra (o al reves) altera el marcador: anule el gol y registrelo de nuevo. ';

    IF @periodo = 'Penales' AND ISNULL(@TipoGol, '') <> 'Penal'
        SET @errores += 'En la definicion por penales el tipo de gol debe ser Penal. ';

    IF Incidencia.fn_MinutoValido(@periodo, @Minuto, @MinutoAdicional) = 0
        SET @errores += 'El minuto no corresponde al periodo ' + @periodo + '. ';

    IF Incidencia.fn_JugadorEnCancha(@idAutor, @momento) = 0
        SET @errores += 'El autor no estaba en cancha en ese momento del partido. ';

    IF @idAsistente IS NOT NULL AND Incidencia.fn_JugadorEnCancha(@idAsistente, @momento) = 0
        SET @errores += 'El asistente no estaba en cancha en ese momento del partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Incidencia.Gol
        SET TipoGol         = @TipoGol,
            Minuto          = @Minuto,
            MinutoAdicional = @MinutoAdicional
        WHERE IdGol = @IdGol;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 TARJETAS
 Incidencia.usp_RegistrarTarjeta
 Registra amarillas y rojas directas para un jugador (@IdAlineacion) o para un
 integrante del cuerpo tecnico (@IdCuerpoTecnico). Si es la segunda amarilla
 del destinatario en el partido, en la misma transaccion se genera la 'Roja por
 doble amarilla' (@GeneroRoja = 1). La roja por doble amarilla no se carga a mano.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Incidencia.usp_RegistrarTarjeta
    @IdPartido       INT,
    @TipoTarjeta     VARCHAR(30),
    @Periodo         VARCHAR(30),
    @Minuto          INT,
    @MinutoAdicional INT          = 0,
    @IdAlineacion    INT          = NULL,
    @IdCuerpoTecnico INT          = NULL,
    @Motivo          VARCHAR(100) = NULL,
    @IdTarjeta       INT          = NULL OUTPUT,
    @GeneroRoja      BIT          = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estadoPartido VARCHAR(20), @fase VARCHAR(20), @momento INT, @amarillasPrevias INT;

    SET @MinutoAdicional = ISNULL(@MinutoAdicional, 0);
    SET @GeneroRoja = 0;
    SET @momento = Incidencia.fn_MomentoPartido(@Periodo, @Minuto, @MinutoAdicional);

    SELECT @estadoPartido = Estado, @fase = Fase
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    -- Partido
    IF @estadoPartido IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @estadoPartido <> 'En juego'
        SET @errores += 'Solo se pueden registrar tarjetas en un partido En juego. ';

    -- Destinatario: un jugador o un integrante del cuerpo tecnico, de este partido
    IF (@IdAlineacion IS NULL AND @IdCuerpoTecnico IS NULL)
       OR (@IdAlineacion IS NOT NULL AND @IdCuerpoTecnico IS NOT NULL)
        SET @errores += 'Hay que indicar un unico destinatario: un jugador (alineacion) o un integrante del cuerpo tecnico. ';

    IF @IdAlineacion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Formacion.Alineacion WHERE IdAlineacion = @IdAlineacion AND IdPartido = @IdPartido)
        SET @errores += 'La alineacion no existe o no corresponde a este partido. ';

    IF @IdCuerpoTecnico IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM Torneo.CuerpoTecnico ct
                       JOIN Torneo.Partido p ON ct.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
                       WHERE ct.IdCuerpoTecnico = @IdCuerpoTecnico
                         AND p.IdPartido = @IdPartido)
        SET @errores += 'El integrante del cuerpo tecnico no existe o su seleccion no juega este partido. ';

    -- Tipo, periodo y minuto
    IF @TipoTarjeta = 'Roja por doble amarilla'
        SET @errores += 'La roja por doble amarilla se genera automaticamente al registrar la segunda amarilla. ';
    ELSE IF @TipoTarjeta IS NULL OR @TipoTarjeta NOT IN ('Amarilla', 'Roja directa')
        SET @errores += 'El tipo de tarjeta debe ser Amarilla o Roja directa. ';

    IF @momento IS NULL
        SET @errores += 'El periodo debe ser Primer tiempo, Segundo tiempo, Alargue 1, Alargue 2 o Penales. ';
    ELSE IF Incidencia.fn_MinutoValido(@Periodo, @Minuto, @MinutoAdicional) = 0
        SET @errores += 'El minuto no corresponde al periodo ' + @Periodo + '. ';

    IF @fase = 'Grupos' AND @Periodo IN ('Alargue 1', 'Alargue 2', 'Penales')
        SET @errores += 'En la fase de grupos no hay alargue ni definicion por penales. ';

    -- No puede recibir tarjetas despues de haber sido expulsado
    IF EXISTS (SELECT 1
               FROM Incidencia.Tarjeta
               WHERE IdPartido = @IdPartido
                 AND TipoTarjeta IN ('Roja directa', 'Roja por doble amarilla')
                 AND (IdAlineacion = @IdAlineacion OR IdCuerpoTecnico = @IdCuerpoTecnico)
                 AND Incidencia.fn_MomentoPartido(Periodo, Minuto, MinutoAdicional) <= @momento)
        SET @errores += 'El destinatario ya habia sido expulsado antes de ese momento del partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @amarillasPrevias = COUNT(*)
        FROM Incidencia.Tarjeta
        WHERE IdPartido = @IdPartido
          AND TipoTarjeta = 'Amarilla'
          AND (IdAlineacion = @IdAlineacion OR IdCuerpoTecnico = @IdCuerpoTecnico);

        INSERT INTO Incidencia.Tarjeta (IdPartido, IdCuerpoTecnico, IdAlineacion, TipoTarjeta, Periodo, Minuto,
                                        MinutoAdicional, Motivo)
        VALUES (@IdPartido, @IdCuerpoTecnico, @IdAlineacion, @TipoTarjeta, @Periodo, @Minuto,
                @MinutoAdicional, NULLIF(LTRIM(RTRIM(@Motivo)), ''));

        SET @IdTarjeta = SCOPE_IDENTITY();

        -- Segunda amarilla en el partido: expulsion por doble amarilla en el mismo minuto.
        IF @TipoTarjeta = 'Amarilla' AND @amarillasPrevias = 1
        BEGIN
            INSERT INTO Incidencia.Tarjeta (IdPartido, IdCuerpoTecnico, IdAlineacion, TipoTarjeta, Periodo, Minuto,
                                            MinutoAdicional, Motivo)
            VALUES (@IdPartido, @IdCuerpoTecnico, @IdAlineacion, 'Roja por doble amarilla', @Periodo, @Minuto,
                    @MinutoAdicional, 'Segunda amarilla');

            SET @GeneroRoja = 1;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdTarjeta = NULL;
        SET @GeneroRoja = 0;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Incidencia.usp_AnularTarjeta
 Si se anula una amarilla y el destinatario tenia una roja por doble amarilla en
 ese partido, la roja tambien se anula (ya no hay dos amarillas). La roja por
 doble amarilla no se anula directamente: se anula una de las amarillas.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Incidencia.usp_AnularTarjeta
    @IdTarjeta INT,
    @QuitoRoja BIT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idPartido INT, @tipoTarjeta VARCHAR(30), @estadoPartido VARCHAR(20);
    DECLARE @idAlineacion INT, @idCuerpoTecnico INT;

    SET @QuitoRoja = 0;

    SELECT @idPartido       = t.IdPartido,
           @tipoTarjeta     = t.TipoTarjeta,
           @idAlineacion    = t.IdAlineacion,
           @idCuerpoTecnico = t.IdCuerpoTecnico,
           @estadoPartido   = p.Estado
    FROM Incidencia.Tarjeta t
    JOIN Torneo.Partido p ON p.IdPartido = t.IdPartido
    WHERE t.IdTarjeta = @IdTarjeta;

    IF @idPartido IS NULL
        SET @errores += 'La tarjeta indicada no existe. ';
    ELSE
    BEGIN
        IF @estadoPartido <> 'En juego'
            SET @errores += 'Solo se pueden anular tarjetas de un partido En juego. ';

        IF @tipoTarjeta = 'Roja por doble amarilla'
            SET @errores += 'La roja por doble amarilla no se anula directamente: anule una de las dos amarillas. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Incidencia.Tarjeta WHERE IdTarjeta = @IdTarjeta;

        IF @tipoTarjeta = 'Amarilla'
        BEGIN
            DELETE FROM Incidencia.Tarjeta
            WHERE IdPartido = @idPartido
              AND TipoTarjeta = 'Roja por doble amarilla'
              AND (IdAlineacion = @idAlineacion OR IdCuerpoTecnico = @idCuerpoTecnico);

            IF @@ROWCOUNT > 0
                SET @QuitoRoja = 1;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @QuitoRoja = 0;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Incidencia.usp_Tarjeta_Modificacion
 Corrige el minuto, el minuto adicional y el motivo (modificacion completa de
 esos tres datos). El tipo, el periodo y el destinatario no se modifican: se
 anula la tarjeta y se registra de nuevo. La roja por doble amarilla no se
 modifica porque la genera el sistema, y si el destinatario fue expulsado por
 doble amarilla, a sus amarillas solo se les corrige el motivo (cambiar el
 minuto dejaria la roja en un minuto que ya no corresponde).
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Incidencia.usp_Tarjeta_Modificacion
    @IdTarjeta       INT,
    @Minuto          INT,
    @MinutoAdicional INT          = 0,
    @Motivo          VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idPartido INT, @tipoTarjeta VARCHAR(30), @periodo VARCHAR(30), @estadoPartido VARCHAR(20);
    DECLARE @idAlineacion INT, @idCuerpoTecnico INT, @minutoActual INT, @adicionalActual INT;

    SET @MinutoAdicional = ISNULL(@MinutoAdicional, 0);

    SELECT @idPartido       = t.IdPartido,
           @tipoTarjeta     = t.TipoTarjeta,
           @periodo         = t.Periodo,
           @idAlineacion    = t.IdAlineacion,
           @idCuerpoTecnico = t.IdCuerpoTecnico,
           @minutoActual    = t.Minuto,
           @adicionalActual = t.MinutoAdicional,
           @estadoPartido   = p.Estado
    FROM Incidencia.Tarjeta t
    JOIN Torneo.Partido p ON p.IdPartido = t.IdPartido
    WHERE t.IdTarjeta = @IdTarjeta;

    IF @idPartido IS NULL
        THROW 50001, 'La tarjeta indicada no existe. ', 1;

    IF @estadoPartido <> 'En juego'
        SET @errores += 'Solo se pueden modificar tarjetas de un partido En juego. ';

    IF @tipoTarjeta = 'Roja por doble amarilla'
        SET @errores += 'La roja por doble amarilla la genera el sistema y no se modifica. ';
    ELSE IF (@Minuto <> @minutoActual OR @MinutoAdicional <> @adicionalActual)
            AND EXISTS (SELECT 1
                        FROM Incidencia.Tarjeta
                        WHERE IdPartido = @idPartido
                          AND TipoTarjeta = 'Roja por doble amarilla'
                          AND (IdAlineacion = @idAlineacion OR IdCuerpoTecnico = @idCuerpoTecnico))
        SET @errores += 'El destinatario fue expulsado por doble amarilla: a sus amarillas solo se les corrige el motivo. ';

    IF Incidencia.fn_MinutoValido(@periodo, @Minuto, @MinutoAdicional) = 0
        SET @errores += 'El minuto no corresponde al periodo ' + @periodo + '. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Incidencia.Tarjeta
        SET Minuto          = @Minuto,
            MinutoAdicional = @MinutoAdicional,
            Motivo          = NULLIF(LTRIM(RTRIM(@Motivo)), '')
        WHERE IdTarjeta = @IdTarjeta;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
