/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-25
 Script       : 99_Visualizacion_2_Consultas_Alcance.sql
 Objetivo     : Entrega 9. Consultas del alcance (seccion "to be") que no tenian un
                objeto propio:
                  Reportes.usp_ReportarFixture         A. fixture completo, filtrado
                                                       por sede, fase, seleccion o fecha.
                  Formacion.fn_HistorialTitularidad    C. historial de titularidad de
                                                       un jugador en el torneo.
                  Incidencia.fn_EquipoEnCancha         D. equipo que estaba en cancha
                                                       en un minuto del partido.
                Las demas consultas del alcance ya existen (goleadores, tarjetas y
                suspensiones, historial de arbitros, simulacion de prime time,
                historial de publicidad e ingresos).
                Se puede ejecutar mas de una vez.
 Requisito    : ejecutar despues de 75_Funciones_Incidencia.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarFixture
 Todos los partidos con su fecha y horario local de la sede y UTC, ordenados por
 fecha. Los filtros son opcionales y se combinan: con NULL no filtran. @Fecha se
 compara con la fecha local de la sede. El marcador solo se informa en los
 partidos finalizados y las selecciones sin definir figuran como 'A definir'.
 Ejemplo: EXEC Reportes.usp_ReportarFixture @IdSede = NULL, @Fase = 'Grupos',
                                           @IdSeleccion = NULL, @Fecha = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarFixture
    @IdSede      INT         = NULL,
    @Fase        VARCHAR(20) = NULL,
    @IdSeleccion INT         = NULL,
    @Fecha       DATE        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSede IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede)
        SET @errores += 'La sede indicada no existe. ';

    IF @Fase IS NOT NULL AND Incidencia.fn_OrdenFase(@Fase) IS NULL
        SET @errores += 'La fase debe ser Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final. ';

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SELECT p.NumeroPartido, p.Fase, p.FechaHoraLocal, p.FechaHoraUtc,
           se.NombreEstadio AS Sede, se.Ciudad,
           ISNULL(pl.Nombre, 'A definir') AS Local,
           ISNULL(pv.Nombre, 'A definir') AS Visitante,
           p.Estado,
           CASE WHEN p.Estado = 'Finalizado'
                THEN CAST(p.GolesLocal AS VARCHAR(3)) + ' - ' + CAST(p.GolesVisitante AS VARCHAR(3))
           END AS Marcador
    FROM Torneo.Partido p
    JOIN Torneo.Sede se           ON se.IdSede = p.IdSede
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Pais pl      ON pl.IdPais = sl.IdPais
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN Torneo.Pais pv      ON pv.IdPais = sv.IdPais
    WHERE (@IdSede IS NULL OR p.IdSede = @IdSede)
      AND (@Fase IS NULL OR p.Fase = @Fase)
      AND (@IdSeleccion IS NULL OR @IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante))
      AND (@Fecha IS NULL OR CAST(p.FechaHoraLocal AS DATE) = @Fecha)
    ORDER BY p.FechaHoraUtc, p.NumeroPartido;
END
GO

/*------------------------------------------------------------------------------
 Formacion.fn_HistorialTitularidad
 Los partidos en los que el jugador figura en la alineacion (titular o suplente),
 con el rival y la posicion en cancha. Devuelve una fila por partido; ordenar por
 FechaHoraUtc al consultar. Ejemplo:
   SELECT * FROM Formacion.fn_HistorialTitularidad(@IdJugador) ORDER BY FechaHoraUtc
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Formacion.fn_HistorialTitularidad (@IdJugador INT)
RETURNS TABLE
AS
RETURN
    SELECT p.NumeroPartido, p.Fase, p.FechaHoraUtc, p.Estado,
           CASE WHEN j.IdSeleccion = p.IdSeleccionLocal THEN pv.Nombre ELSE pl.Nombre END AS Rival,
           a.EsTitular, a.PosicionCancha
    FROM Formacion.Alineacion a
    JOIN Torneo.Jugador j         ON j.IdJugador = a.IdJugador
    JOIN Torneo.Partido p         ON p.IdPartido = a.IdPartido
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Pais pl      ON pl.IdPais = sl.IdPais
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN Torneo.Pais pv      ON pv.IdPais = sv.IdPais
    WHERE a.IdJugador = @IdJugador;
GO

/*------------------------------------------------------------------------------
 Incidencia.fn_EquipoEnCancha
 Los jugadores de ambas selecciones que estaban en cancha en un momento del
 partido, segun los titulares, las sustituciones y las expulsiones
 (Incidencia.fn_JugadorEnCancha). El momento se indica como en el resto del
 sistema: periodo, minuto y minuto adicional. En el minuto exacto de una
 sustitucion figuran en cancha tanto el que sale como el que entra (es el criterio
 de fn_JugadorEnCancha: un gol o una tarjeta en ese minuto es valido para ambos).
 Si el periodo no es valido o el
 partido no existe, no devuelve filas. Ejemplo:
   SELECT * FROM Incidencia.fn_EquipoEnCancha(@IdPartido, 'Segundo tiempo', 60, 0)
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Incidencia.fn_EquipoEnCancha (
    @IdPartido       INT,
    @Periodo         VARCHAR(30),
    @Minuto          INT,
    @MinutoAdicional INT = 0
)
RETURNS TABLE
AS
RETURN
    SELECT j.IdJugador, pa.Nombre AS Seleccion, j.Dorsal, j.Apellido, j.Nombre, a.PosicionCancha, a.EsTitular
    FROM Formacion.Alineacion a
    JOIN Torneo.Jugador j   ON j.IdJugador = a.IdJugador
    JOIN Torneo.Seleccion s ON s.IdSeleccion = j.IdSeleccion
    JOIN Torneo.Pais pa     ON pa.IdPais = s.IdPais
    WHERE a.IdPartido = @IdPartido
      AND Incidencia.fn_JugadorEnCancha(a.IdAlineacion,
              Incidencia.fn_MomentoPartido(@Periodo, @Minuto, @MinutoAdicional)) = 1;
GO
