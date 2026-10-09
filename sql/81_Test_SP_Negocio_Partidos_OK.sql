/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 81_Test_SP_Negocio_Partidos_OK.sql
 Objetivo     : Testing exitoso de 80_SP_Negocio_Partidos.sql (relacion 1:1). Recorre
                el ciclo de vida de los partidos: registrar (con sede nueva y con
                sede existente), iniciar, finalizar, suspender y reprogramar.
 Requisito    : ejecutar despues de 22_Test_SP_ABM_Seleccion_Validaciones.sql (usa los
                paises, sedes, selecciones con convocatoria y los partidos 1 y 3).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @SelFra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-FRA');
DECLARE @SelMex INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-MEX');
DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @IdP4 INT, @IdP5 INT, @IdSedeSofi INT, @IdSedeExistente INT;

SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 2, 2

PRINT '=== Prueba 1: registrar un partido con una sede que todavia no existe ===';
-- Resultado esperado: en una sola operacion se crean la sede SoFi Stadium (Pacific Standard Time) y el partido 4
-- (Francia contra Mexico, grupos) a las 02:00 UTC, que son las 19:00 del dia anterior en la sede.
-- Quedan 3 sedes y 3 partidos.
EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-004', @NumeroPartido = 4, @Fase = 'Grupos',
     @FechaHoraUtc = '2026-06-13 02:00', @CodigoExternoSede = 'SEDE-SOFI', @IdSeleccionLocal = @SelFra,
     @IdSeleccionVisitante = @SelMex, @NombreEstadio = 'SoFi Stadium', @Ciudad = 'Inglewood', @IdPaisSede = @PaisUsa,
     @HusoHorarioSede = 'Pacific Standard Time', @CapacidadSede = 70000, @IdPartido = @IdP4 OUTPUT, @IdSede = @IdSedeSofi OUTPUT;
SELECT p.IdPartido, p.NumeroPartido, p.Fase, s.NombreEstadio, p.FechaHoraUtc, p.FechaHoraLocal, p.Estado
FROM Torneo.Partido p JOIN Torneo.Sede s ON s.IdSede = p.IdSede WHERE p.IdPartido = @IdP4;
SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 3, 3

PRINT '=== Prueba 2: registrar un partido en una sede que ya existe ===';
-- Resultado esperado: se crea el partido 5 (octavos, Argentina contra Brasil) en el Estadio Azteca. No se
-- crea ninguna sede nueva: siguen siendo 3 sedes y ahora hay 4 partidos.
EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-005', @NumeroPartido = 5, @Fase = 'Octavos',
     @FechaHoraUtc = '2026-07-06 22:00', @CodigoExternoSede = 'SEDE-AZTECA', @IdSeleccionLocal = @SelArg,
     @IdSeleccionVisitante = @SelBra, @IdPartido = @IdP5 OUTPUT, @IdSede = @IdSedeExistente OUTPUT;
SELECT p.IdPartido, p.NumeroPartido, p.Fase, s.NombreEstadio, p.FechaHoraLocal, p.Estado
FROM Torneo.Partido p JOIN Torneo.Sede s ON s.IdSede = p.IdSede WHERE p.IdPartido = @IdP5;
SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 3, 4

PRINT '=== Prueba 3: iniciar un partido ===';
-- Resultado esperado: el partido 3 (Argentina 26 convocados, Brasil 23) pasa de Programado a En juego.
SELECT IdPartido, Estado FROM Torneo.Partido WHERE IdPartido = @IdP3;
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP3;
SELECT IdPartido, Estado FROM Torneo.Partido WHERE IdPartido = @IdP3;

PRINT '=== Prueba 4: finalizar un partido ===';
-- Resultado esperado: el partido 3 pasa a Finalizado con asistencia 80000. Como no se registraron goles, el
-- resultado final queda 0 a 0 (en la fase de grupos puede haber empate).
EXEC Torneo.usp_FinalizarPartido @IdPartido = @IdP3, @Asistencia = 80000;
SELECT IdPartido, Estado, Asistencia, GolesLocal, GolesVisitante, PenalesLocal, PenalesVisitante
FROM Torneo.Partido WHERE IdPartido = @IdP3;

PRINT '=== Prueba 5: suspender y reprogramar un partido ===';
-- Resultado esperado: el partido 4 pasa a Suspendido y despues vuelve a Programado en la nueva fecha: 02:00 UTC
-- del 14/06, que son las 19:00 locales del 13/06 (la hora local se recalcula con el huso de la sede).
EXEC Torneo.usp_SuspenderPartido @IdPartido = @IdP4;
SELECT IdPartido, Estado, FechaHoraUtc, FechaHoraLocal FROM Torneo.Partido WHERE IdPartido = @IdP4;
EXEC Torneo.usp_ReprogramarPartido @IdPartido = @IdP4, @FechaHoraUtc = '2026-06-14 02:00';
SELECT IdPartido, Estado, FechaHoraUtc, FechaHoraLocal FROM Torneo.Partido WHERE IdPartido = @IdP4;

PRINT '=== Prueba 6: iniciar el partido de octavos ===';
-- Resultado esperado: el partido 5 pasa a En juego. Queda asi para las pruebas de validaciones del script 82.
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP5;
SELECT IdPartido, Fase, Estado FROM Torneo.Partido WHERE IdPartido = @IdP5;
GO
