/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 05_Funciones_Incidencia.sql
 Objetivo     : Funciones que usan los SP de goles y tarjetas:
                  Incidencia.fn_OrdenFase           orden numerico de una fase.
                  Incidencia.fn_MinutoValido        si un minuto corresponde a un periodo.
                  Incidencia.fn_MomentoPartido      periodo + minuto como un numero ordenable.
                  Incidencia.fn_JugadorEnCancha     si un jugador estaba en cancha.
                  Incidencia.fn_JugadorSuspendido   si un jugador esta suspendido.
                  Incidencia.fn_SuspendidosPartido  suspendidos para un partido.
                Los criterios de suspension son parametros de las funciones, con el
                valor del reglamento por defecto (no hace falta una tabla de
                configuracion ni modificar el DER).
 Prerrequisito: 04_Tablas_Arbitraje_Incidencia.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_OrdenFase
 La fase esta guardada como texto en Torneo.Partido: esta funcion permite
 compararlas (Grupos = 1 ... Final = 7). Devuelve NULL si el texto no es una fase.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_OrdenFase (@Fase VARCHAR(20))
RETURNS TINYINT
AS
BEGIN
    RETURN CASE @Fase
               WHEN 'Grupos'        THEN 1
               WHEN 'Dieciseisavos' THEN 2
               WHEN 'Octavos'       THEN 3
               WHEN 'Cuartos'       THEN 4
               WHEN 'Semifinal'     THEN 5
               WHEN 'Tercer puesto' THEN 6
               WHEN 'Final'         THEN 7
           END;
END
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_MinutoValido
 Primer tiempo 1-45, segundo 46-90, alargue 1 91-105, alargue 2 106-120. En la
 definicion por penales se registra el minuto 120. El minuto adicional (0 a 30)
 solo se admite en el ultimo minuto del periodo (45+2, 90+4...).
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_MinutoValido (@Periodo VARCHAR(30), @Minuto INT, @MinutoAdicional INT)
RETURNS BIT
AS
BEGIN
    DECLARE @desde INT, @hasta INT;
    DECLARE @adicional INT = ISNULL(@MinutoAdicional, 0);

    SET @desde = CASE @Periodo
                     WHEN 'Primer tiempo'  THEN 1
                     WHEN 'Segundo tiempo' THEN 46
                     WHEN 'Alargue 1'      THEN 91
                     WHEN 'Alargue 2'      THEN 106
                     WHEN 'Penales'        THEN 120
                 END;

    SET @hasta = CASE @Periodo
                     WHEN 'Primer tiempo'  THEN 45
                     WHEN 'Segundo tiempo' THEN 90
                     WHEN 'Alargue 1'      THEN 105
                     ELSE 120
                 END;

    IF @desde IS NULL OR @Minuto IS NULL OR @Minuto < @desde OR @Minuto > @hasta
        RETURN 0;

    IF @adicional < 0 OR @adicional > 30
        RETURN 0;

    IF @adicional > 0 AND (@Minuto <> @hasta OR @Periodo = 'Penales')
        RETURN 0;

    RETURN 1;
END
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_MomentoPartido
 Convierte (periodo, minuto, adicional) en un numero que respeta el orden del
 partido, para poder comparar dos eventos con < y >:
   numero del periodo * 100000 + minuto * 100 + minuto adicional
 Ejemplos: Primer tiempo 45+2 -> 104502. Segundo tiempo 60' -> 206000.
 Devuelve NULL si el periodo no es valido.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_MomentoPartido (@Periodo VARCHAR(30), @Minuto INT, @MinutoAdicional INT)
RETURNS INT
AS
BEGIN
    DECLARE @numeroPeriodo INT = CASE @Periodo
                                     WHEN 'Primer tiempo'  THEN 1
                                     WHEN 'Segundo tiempo' THEN 2
                                     WHEN 'Alargue 1'      THEN 3
                                     WHEN 'Alargue 2'      THEN 4
                                     WHEN 'Penales'        THEN 5
                                 END;

    RETURN @numeroPeriodo * 100000 + @Minuto * 100 + ISNULL(@MinutoAdicional, 0);
END
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_JugadorEnCancha
 Devuelve 1 si el jugador estaba en cancha en ese momento del partido:
   - era titular, o entro por una sustitucion en ese momento o antes;
   - no salio por una sustitucion antes de ese momento;
   - no fue expulsado antes de ese momento.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_JugadorEnCancha (@IdAlineacion INT, @Momento INT)
RETURNS BIT
AS
BEGIN
    DECLARE @esTitular BIT, @entrada INT, @salida INT, @expulsion INT;

    SELECT @esTitular = EsTitular
    FROM Formacion.Alineacion
    WHERE IdAlineacion = @IdAlineacion;

    IF @esTitular IS NULL OR @Momento IS NULL
        RETURN 0;

    -- Momento en que entro: 0 si es titular; si es suplente, el de su sustitucion.
    IF @esTitular = 1
        SET @entrada = 0;
    ELSE
        SELECT @entrada = Incidencia.fn_MomentoPartido(Periodo, Minuto, MinutoAdicional)
        FROM Formacion.Sustitucion
        WHERE IdAlineacionEntra = @IdAlineacion;

    SELECT @salida = Incidencia.fn_MomentoPartido(Periodo, Minuto, MinutoAdicional)
    FROM Formacion.Sustitucion
    WHERE IdAlineacionSale = @IdAlineacion;

    SELECT @expulsion = Incidencia.fn_MomentoPartido(Periodo, Minuto, MinutoAdicional)
    FROM Incidencia.Tarjeta
    WHERE IdAlineacion = @IdAlineacion
      AND TipoTarjeta IN ('Roja directa', 'Roja por doble amarilla');

    IF @entrada IS NULL OR @entrada > @Momento     -- nunca entro, o entro despues
        RETURN 0;
    IF @salida < @Momento                          -- ya habia salido
        RETURN 0;
    IF @expulsion < @Momento                       -- ya habia sido expulsado
        RETURN 0;

    RETURN 1;
END
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_JugadorSuspendido
 Devuelve 1 si el jugador esta suspendido para el partido indicado.

 Criterios parametrizables (con DEFAULT o NULL se usa el valor del reglamento):
   @AmarillasParaSuspension  amarillas que generan una fecha de suspension (2).
   @PartidosSuspensionRoja   fechas de suspension por una roja (1).
   @FaseReinicioAmarillas    desde esta fase la cuenta de amarillas vuelve a
                             cero ('Semifinal'). Con 'Ninguna' no hay reinicio.
 Ejemplo: Incidencia.fn_JugadorSuspendido(@IdJugador, @IdPartido, DEFAULT, DEFAULT, DEFAULT)

 Reglas:
   1. Roja: recibio una roja (directa o por doble amarilla) en alguno de los
      ultimos @PartidosSuspensionRoja partidos de su seleccion.
   2. Amarillas: en el partido anterior de su seleccion completo un multiplo de
      @AmarillasParaSuspension (la 2da, la 4ta...). Se compara cuantas
      amarillas tenia hasta ese partido y cuantas tenia antes de ese partido.
   3. Si el partido anterior es de la fase de reinicio o posterior, solo cuentan
      las amarillas desde esa fase. Una suspension que se genero antes del
      reinicio se cumple igual.
   4. Las amarillas de un partido en el que fue expulsado por doble amarilla no
      cuentan (ya se sanciona con la roja).
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_JugadorSuspendido (
    @IdJugador               INT,
    @IdPartido               INT,
    @AmarillasParaSuspension INT         = 2,
    @PartidosSuspensionRoja  INT         = 1,
    @FaseReinicioAmarillas   VARCHAR(20) = 'Semifinal'
)
RETURNS BIT
AS
BEGIN
    DECLARE @idSeleccion INT, @fechaPartido DATETIME2;
    DECLARE @idAnterior INT, @fechaAnterior DATETIME2, @faseAnterior VARCHAR(20);
    DECLARE @ordenReinicio TINYINT, @ordenDesde TINYINT;
    DECLARE @amarillasHasta INT, @amarillasAntes INT;

    -- Valores del reglamento si no se informan o no son validos.
    IF @AmarillasParaSuspension IS NULL OR @AmarillasParaSuspension < 1
        SET @AmarillasParaSuspension = 2;
    IF @PartidosSuspensionRoja IS NULL OR @PartidosSuspensionRoja < 0
        SET @PartidosSuspensionRoja = 1;
    SET @ordenReinicio = Incidencia.fn_OrdenFase(ISNULL(@FaseReinicioAmarillas, 'Semifinal'));

    -- Seleccion del jugador y fecha del partido (tiene que jugarlo su seleccion).
    SELECT @idSeleccion = j.IdSeleccion, @fechaPartido = p.FechaHoraUtc
    FROM Torneo.Jugador j
    JOIN Torneo.Partido p ON j.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
    WHERE j.IdJugador = @IdJugador
      AND p.IdPartido = @IdPartido;

    IF @idSeleccion IS NULL
        RETURN 0;

    -- Regla 1: roja en alguno de los ultimos @PartidosSuspensionRoja partidos de la seleccion.
    IF EXISTS (SELECT 1
               FROM (SELECT TOP (@PartidosSuspensionRoja) IdPartido
                     FROM Torneo.Partido
                     WHERE @idSeleccion IN (IdSeleccionLocal, IdSeleccionVisitante)
                       AND FechaHoraUtc < @fechaPartido
                     ORDER BY FechaHoraUtc DESC) ultimos
               JOIN Formacion.Alineacion a ON a.IdPartido = ultimos.IdPartido AND a.IdJugador = @IdJugador
               JOIN Incidencia.Tarjeta t ON t.IdAlineacion = a.IdAlineacion
               WHERE t.TipoTarjeta IN ('Roja directa', 'Roja por doble amarilla'))
        RETURN 1;

    -- Reglas 2 a 4: amarillas. Se busca el partido anterior de la seleccion.
    SELECT TOP (1) @idAnterior = IdPartido, @fechaAnterior = FechaHoraUtc, @faseAnterior = Fase
    FROM Torneo.Partido
    WHERE @idSeleccion IN (IdSeleccionLocal, IdSeleccionVisitante)
      AND FechaHoraUtc < @fechaPartido
    ORDER BY FechaHoraUtc DESC;

    IF @idAnterior IS NULL
        RETURN 0;

    -- Si el partido anterior ya es de la fase de reinicio, solo cuentan las fases desde ahi.
    SET @ordenDesde = CASE WHEN Incidencia.fn_OrdenFase(@faseAnterior) >= @ordenReinicio THEN @ordenReinicio ELSE 1 END;

    SELECT @amarillasHasta = COUNT(*),
           @amarillasAntes = SUM(CASE WHEN p.FechaHoraUtc < @fechaAnterior THEN 1 ELSE 0 END)
    FROM Incidencia.Tarjeta t
    JOIN Formacion.Alineacion a ON a.IdAlineacion = t.IdAlineacion
    JOIN Torneo.Partido p ON p.IdPartido = a.IdPartido
    WHERE a.IdJugador = @IdJugador
      AND t.TipoTarjeta = 'Amarilla'
      AND p.FechaHoraUtc <= @fechaAnterior
      AND Incidencia.fn_OrdenFase(p.Fase) >= @ordenDesde
      AND NOT EXISTS (SELECT 1 FROM Incidencia.Tarjeta r
                      WHERE r.IdAlineacion = a.IdAlineacion
                        AND r.TipoTarjeta = 'Roja por doble amarilla');

    -- Division entera: con 2 amarillas por fecha, 1/2 = 0 y 2/2 = 1. Si el numero
    -- aumenta en el partido anterior, en ese partido completo un multiplo.
    IF @amarillasHasta / @AmarillasParaSuspension > ISNULL(@amarillasAntes, 0) / @AmarillasParaSuspension
        RETURN 1;

    RETURN 0;
END
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_SuspendidosPartido
 Jugadores activos de las dos selecciones que estan suspendidos para el partido.
 Recibe los mismos criterios que fn_JugadorSuspendido.
 Ejemplo: SELECT * FROM Incidencia.fn_SuspendidosPartido(@IdPartido, DEFAULT, DEFAULT, DEFAULT)
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_SuspendidosPartido (
    @IdPartido               INT,
    @AmarillasParaSuspension INT         = 2,
    @PartidosSuspensionRoja  INT         = 1,
    @FaseReinicioAmarillas   VARCHAR(20) = 'Semifinal'
)
RETURNS TABLE
AS
RETURN
    SELECT j.IdJugador, j.CodigoExterno, j.Nombre, j.Apellido, j.Dorsal
    FROM Torneo.Partido p
    JOIN Torneo.Jugador j ON j.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
    WHERE p.IdPartido = @IdPartido
      AND j.FechaBaja IS NULL
      AND Incidencia.fn_JugadorSuspendido(j.IdJugador, p.IdPartido, @AmarillasParaSuspension,
                                          @PartidosSuspensionRoja, @FaseReinicioAmarillas) = 1;
GO
