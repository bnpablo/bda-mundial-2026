/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 77_Test_SP_Incidencia_OK.sql
 Objetivo     : Testing exitoso de 76_SP_Incidencia.sql (relacion 1:1) y del calculo
                de suspensiones de 75_Funciones_Incidencia.sql. Cubre los casos
                obligatorios: partido con doble amarilla, partido con roja directa y
                jugador suspendido por acumulacion para el partido siguiente.
                Partidos de Uruguay: P1 (Grupos), P2 (Grupos), P3 (Dieciseisavos),
                P4 (Octavos) y P5 (Cuartos). Colombia juega P1 y P3; Ecuador P2, P4 y P5.
 Requisito    : ejecutar despues de 52_Test_SP_ABM_Arbitraje_Validaciones.sql (usa los
                partidos y jugadores que prepara el script 51), de 30_SP_ABM_Formacion.sql
                (alineaciones y sustitucion) y de 40_SP_Negocio_Partidos.sql (inicia
                P1 a P5).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

/*------------------------------------------------------------------------------
 PREPARACION DE DATOS
 Se inician los partidos P1 a P5 (los goles y tarjetas se cargan En juego), se
 cargan las alineaciones que usan los tests y una sustitucion en P1: URY-02 sale
 y URY-03 entra al minuto 60 del segundo tiempo.
------------------------------------------------------------------------------*/
DECLARE @IdP1 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P1');
DECLARE @IdP2 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P2');
DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P3');
DECLARE @IdP4 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P4');
DECLARE @IdP5 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P5');
DECLARE @IdP6 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P6');

DECLARE @Ury01 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'URY-01');
DECLARE @Ury02 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'URY-02');
DECLARE @Ury03 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'URY-03');
DECLARE @Ury04 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'URY-04');
DECLARE @Col01 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'COL-01');
DECLARE @Col02 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'COL-02');
DECLARE @Ecu01 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ECU-01');
DECLARE @DtUry INT = (SELECT ct.IdCuerpoTecnico
                      FROM Torneo.CuerpoTecnico ct
                      JOIN Torneo.Seleccion s ON s.IdSeleccion = ct.IdSeleccion
                      WHERE s.CodigoExterno = 'SEL-URY' AND ct.Rol = 'Director tecnico');

DECLARE @P1Ury01 INT, @P1Ury02 INT, @P1Ury03 INT, @P1Ury04 INT, @P1Col01 INT, @P1Col02 INT;
DECLARE @P2Ury03 INT, @P2Ury04 INT, @P3Ury02 INT, @P3Ury03 INT, @P3Col02 INT;
DECLARE @P4Ury02 INT, @P4Ecu01 INT, @P6Col01 INT;

EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP1;
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP2;
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP3;
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP4;
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP5;

EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @Ury01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @P1Ury01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @Ury02, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P1Ury02 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @Ury03, @EsTitular = 0, @PosicionCancha = 'DEF', @IdAlineacion = @P1Ury03 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @Ury04, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P1Ury04 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @Col01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @P1Col01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @Col02, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P1Col02 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP2, @IdJugador = @Ury03, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P2Ury03 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP2, @IdJugador = @Ury04, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P2Ury04 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @Ury02, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P3Ury02 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @Ury03, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P3Ury03 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @Col02, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P3Col02 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP4, @IdJugador = @Ury02, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @P4Ury02 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP4, @IdJugador = @Ecu01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @P4Ecu01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP6, @IdJugador = @Col01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @P6Col01 OUTPUT;

EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @P1Ury02, @IdAlineacionEntra = @P1Ury03,
     @Periodo = 'Segundo tiempo', @Minuto = 60, @NumeroVentana = 1, @Motivo = 'Tactico';

SELECT CodigoExterno, Fase, Estado FROM Torneo.Partido WHERE CodigoExterno LIKE 'INC-P%' ORDER BY NumeroPartido;
-- esperado: P0 Finalizado, P1 a P5 En juego, P6 Programado

DECLARE @IdGol INT, @IdGolEnContra INT, @IdGolEcu INT, @IdAmarilla1 INT, @IdAmarilla2 INT;
DECLARE @GeneroRoja BIT, @QuitoRoja BIT;

/*------------------------------------------------------------------------------
 GOLES
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: gol con asistencia ===';
-- Resultado esperado: gol de URY-01 al 10' del primer tiempo con asistencia de URY-02. INC-P1: 1 a 0.
SELECT 'Antes' AS Momento, GolesLocal, GolesVisitante FROM Torneo.Partido WHERE IdPartido = @IdP1;
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Ury01, @TipoGol = 'Jugada', @Periodo = 'Primer tiempo',
     @Minuto = 10, @IdAlineacionAsistente = @P1Ury02, @IdGol = @IdGol OUTPUT;
SELECT 'Despues' AS Momento, GolesLocal, GolesVisitante FROM Torneo.Partido WHERE IdPartido = @IdP1;
SELECT * FROM Incidencia.Gol WHERE IdGol = @IdGol;

PRINT '=== Prueba 2: gol en contra ===';
-- Resultado esperado: COL-01 hace un gol en contra al 20'. Suma para Uruguay (el rival del autor): 2 a 0.
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Col01, @TipoGol = 'En contra', @Periodo = 'Primer tiempo',
     @Minuto = 20, @IdGol = @IdGolEnContra OUTPUT;
SELECT 'Despues' AS Momento, GolesLocal, GolesVisitante FROM Torneo.Partido WHERE IdPartido = @IdP1;

PRINT '=== Prueba 3: gol de un suplente despues de entrar ===';
-- Resultado esperado: URY-03 entro al 60' del segundo tiempo y hace un gol de cabeza al 75'. INC-P1: 3 a 0.
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Ury03, @TipoGol = 'Cabezazo', @Periodo = 'Segundo tiempo',
     @Minuto = 75;
SELECT 'Despues' AS Momento, GolesLocal, GolesVisitante FROM Torneo.Partido WHERE IdPartido = @IdP1;

PRINT '=== Prueba 4: anular un gol ===';
-- Resultado esperado: se anula el gol en contra y el marcador se recalcula: 2 a 0.
EXEC Incidencia.usp_AnularGol @IdGol = @IdGolEnContra;
SELECT 'Despues' AS Momento, GolesLocal, GolesVisitante FROM Torneo.Partido WHERE IdPartido = @IdP1;

PRINT '=== Prueba 5: modificacion completa de un gol ===';
-- Resultado esperado: ECU-01 hace un gol al 20' en INC-P4 (Ecuador 1 a 0). Se corrige: minuto 22, tipo
-- Cabezazo y sin asistencia. El marcador no cambia.
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P4Ecu01, @TipoGol = 'Jugada', @Periodo = 'Primer tiempo',
     @Minuto = 20, @IdGol = @IdGolEcu OUTPUT;
SELECT 'Antes' AS Momento, * FROM Incidencia.Gol WHERE IdGol = @IdGolEcu;
EXEC Incidencia.usp_Gol_Modificacion @IdGol = @IdGolEcu, @TipoGol = 'Cabezazo', @Minuto = 22;
SELECT 'Despues' AS Momento, * FROM Incidencia.Gol WHERE IdGol = @IdGolEcu;
SELECT GolesLocal, GolesVisitante FROM Torneo.Partido WHERE IdPartido = @IdP4;    -- esperado: 1, 0

/*------------------------------------------------------------------------------
 TARJETAS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 6: expulsion por doble amarilla (caso obligatorio) ===';
-- Resultado esperado: URY-01 recibe amarilla al 30' (GeneroRoja = 0) y otra al 50' del segundo tiempo
-- (GeneroRoja = 1). Quedan 3 tarjetas: las dos amarillas y la roja por doble amarilla al 50'.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdAlineacion = @P1Ury01, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 30, @Motivo = 'Falta tactica', @GeneroRoja = @GeneroRoja OUTPUT;
SELECT 'Primera amarilla' AS Paso, @GeneroRoja AS GeneroRoja;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdAlineacion = @P1Ury01, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Segundo tiempo', @Minuto = 50, @Motivo = 'Protesta', @GeneroRoja = @GeneroRoja OUTPUT;
SELECT 'Segunda amarilla' AS Paso, @GeneroRoja AS GeneroRoja;
SELECT * FROM Incidencia.Tarjeta WHERE IdAlineacion = @P1Ury01 ORDER BY IdTarjeta;

PRINT '=== Prueba 7: roja directa (caso obligatorio) ===';
-- Resultado esperado: COL-01 recibe roja directa al 80' del segundo tiempo.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdAlineacion = @P1Col01, @TipoTarjeta = 'Roja directa',
     @Periodo = 'Segundo tiempo', @Minuto = 80, @Motivo = 'Juego brusco grave';
SELECT * FROM Incidencia.Tarjeta WHERE IdAlineacion = @P1Col01;

PRINT '=== Prueba 8: amarilla a un integrante del cuerpo tecnico ===';
-- Resultado esperado: el director tecnico de Uruguay recibe amarilla al 85'.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdCuerpoTecnico = @DtUry, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Segundo tiempo', @Minuto = 85, @Motivo = 'Protesta desde el banco';
SELECT * FROM Incidencia.Tarjeta WHERE IdCuerpoTecnico = @DtUry;

PRINT '=== Prueba 9: anular la segunda amarilla quita la roja ===';
-- Resultado esperado: COL-02 recibe dos amarillas en INC-P3 y se genera la roja. Al anular la segunda amarilla
-- se elimina tambien la roja (QuitoRoja = 1) y queda una sola amarilla.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP3, @IdAlineacion = @P3Col02, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 10;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP3, @IdAlineacion = @P3Col02, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 20, @IdTarjeta = @IdAmarilla2 OUTPUT;
SELECT 'Antes' AS Momento, * FROM Incidencia.Tarjeta WHERE IdAlineacion = @P3Col02 ORDER BY IdTarjeta;
EXEC Incidencia.usp_AnularTarjeta @IdTarjeta = @IdAmarilla2, @QuitoRoja = @QuitoRoja OUTPUT;
SELECT @QuitoRoja AS QuitoRoja;
SELECT 'Despues' AS Momento, * FROM Incidencia.Tarjeta WHERE IdAlineacion = @P3Col02 ORDER BY IdTarjeta;

PRINT '=== Prueba 10: modificacion de tarjetas ===';
-- Resultado esperado: ECU-01 recibe amarilla al 25' en INC-P4 y se corrige: minuto 26 y motivo "Falta tactica".
-- Despues recibe la segunda amarilla al 40' (roja por doble amarilla al 40'). A partir de ahi a sus amarillas
-- solo se les puede corregir el motivo: la primera queda con motivo "Falta tactica reiterada" y el mismo minuto.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP4, @IdAlineacion = @P4Ecu01, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 25, @Motivo = 'Falta', @IdTarjeta = @IdAmarilla1 OUTPUT;
SELECT 'Antes' AS Momento, * FROM Incidencia.Tarjeta WHERE IdTarjeta = @IdAmarilla1;
EXEC Incidencia.usp_Tarjeta_Modificacion @IdTarjeta = @IdAmarilla1, @Minuto = 26, @Motivo = 'Falta tactica';
SELECT 'Despues' AS Momento, * FROM Incidencia.Tarjeta WHERE IdTarjeta = @IdAmarilla1;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP4, @IdAlineacion = @P4Ecu01, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 40;
EXEC Incidencia.usp_Tarjeta_Modificacion @IdTarjeta = @IdAmarilla1, @Minuto = 26, @Motivo = 'Falta tactica reiterada';
SELECT * FROM Incidencia.Tarjeta WHERE IdAlineacion = @P4Ecu01 ORDER BY IdTarjeta;

/*------------------------------------------------------------------------------
 SUSPENSIONES (Incidencia.fn_JugadorSuspendido y fn_SuspendidosPartido)
 Con DEFAULT se usan los criterios del reglamento: 2 amarillas = 1 fecha,
 roja = 1 fecha y reinicio de amarillas desde la Semifinal.
------------------------------------------------------------------------------*/
PRINT '=== Prueba 11: suspension por roja ===';
-- Resultado esperado (columna Suspendido igual a Esperado):
--   URY-01 (doble amarilla en P1): suspendido en P2 = 1 y en P3 = 0 (ya cumplio).
--   COL-01 (roja directa en P1):   suspendido en P3 = 1 (es el partido siguiente de Colombia).
SELECT 'URY-01 en P2' AS Caso, Incidencia.fn_JugadorSuspendido(@Ury01, @IdP2, DEFAULT, DEFAULT, DEFAULT) AS Suspendido, 1 AS Esperado
UNION ALL
SELECT 'URY-01 en P3', Incidencia.fn_JugadorSuspendido(@Ury01, @IdP3, DEFAULT, DEFAULT, DEFAULT), 0
UNION ALL
SELECT 'COL-01 en P3', Incidencia.fn_JugadorSuspendido(@Col01, @IdP3, DEFAULT, DEFAULT, DEFAULT), 1;

PRINT '=== Prueba 12: suspension por acumulacion de amarillas (caso obligatorio) ===';
-- Resultado esperado: URY-04 recibe amarilla en P1 y en P2 (2 acumuladas).
--   Suspendido en P2 = 0, en P3 = 1 (partido siguiente) y en P4 = 0 (ya cumplio).
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdAlineacion = @P1Ury04, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 15;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP2, @IdAlineacion = @P2Ury04, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 40;
SELECT 'URY-04 en P2' AS Caso, Incidencia.fn_JugadorSuspendido(@Ury04, @IdP2, DEFAULT, DEFAULT, DEFAULT) AS Suspendido, 0 AS Esperado
UNION ALL
SELECT 'URY-04 en P3', Incidencia.fn_JugadorSuspendido(@Ury04, @IdP3, DEFAULT, DEFAULT, DEFAULT), 1
UNION ALL
SELECT 'URY-04 en P4', Incidencia.fn_JugadorSuspendido(@Ury04, @IdP4, DEFAULT, DEFAULT, DEFAULT), 0;

PRINT '=== Prueba 13: lista de suspendidos para un partido ===';
-- Resultado esperado: para INC-P3 figuran URY-04 (acumulacion) y COL-01 (roja directa).
SELECT * FROM Incidencia.fn_SuspendidosPartido(@IdP3, DEFAULT, DEFAULT, DEFAULT);

PRINT '=== Prueba 14: criterios parametrizables ===';
-- Resultado esperado:
--   Con 3 amarillas para suspender, URY-04 (2 amarillas) NO esta suspendido en P3 = 0.
--   Con 2 partidos de suspension por roja, URY-01 SI esta suspendido en P3 = 1.
--   La lista de P3 con esos dos criterios: URY-01 y COL-01.
SELECT 'URY-04 en P3, 3 amarillas' AS Caso, Incidencia.fn_JugadorSuspendido(@Ury04, @IdP3, 3, DEFAULT, DEFAULT) AS Suspendido, 0 AS Esperado
UNION ALL
SELECT 'URY-01 en P3, roja = 2 partidos', Incidencia.fn_JugadorSuspendido(@Ury01, @IdP3, DEFAULT, 2, DEFAULT), 1;
SELECT * FROM Incidencia.fn_SuspendidosPartido(@IdP3, 3, 2, DEFAULT);

PRINT '=== Prueba 15: reinicio de amarillas ===';
-- URY-02 recibe amarilla en P3 (dieciseisavos) y en P4 (octavos).
-- Resultado esperado para P5:
--   Reinicio en Octavos: la amarilla de dieciseisavos ya no cuenta en octavos = 0.
--   Sin reinicio ('Ninguna'): se acumulan 2 amarillas = 1.
--   Criterio del reglamento (DEFAULT, reinicio en Semifinal): se acumulan 2 amarillas = 1.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP3, @IdAlineacion = @P3Ury02, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 12;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP4, @IdAlineacion = @P4Ury02, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 12;
SELECT 'Reinicio en Octavos' AS Caso, Incidencia.fn_JugadorSuspendido(@Ury02, @IdP5, DEFAULT, DEFAULT, 'Octavos') AS Suspendido, 0 AS Esperado
UNION ALL
SELECT 'Sin reinicio', Incidencia.fn_JugadorSuspendido(@Ury02, @IdP5, DEFAULT, DEFAULT, 'Ninguna'), 1
UNION ALL
SELECT 'Reglamento (DEFAULT)', Incidencia.fn_JugadorSuspendido(@Ury02, @IdP5, DEFAULT, DEFAULT, DEFAULT), 1;

PRINT '=== Prueba 16: una suspension generada antes del reinicio se cumple igual ===';
-- URY-03 recibe amarilla en P2 y en P3 (2 acumuladas antes de Octavos).
-- Resultado esperado: con reinicio en Octavos, URY-03 igual esta suspendido en P4 = 1.
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP2, @IdAlineacion = @P2Ury03, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 5;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP3, @IdAlineacion = @P3Ury03, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 5;
SELECT 'Reinicio en Octavos: URY-03 en P4' AS Caso,
       Incidencia.fn_JugadorSuspendido(@Ury03, @IdP4, DEFAULT, DEFAULT, 'Octavos') AS Suspendido, 1 AS Esperado;

PRINT '=== Prueba 17: tabla de goleadores del torneo y de una seleccion ===';
-- Resultado esperado: el torneo tiene 3 goleadores con 1 gol cada uno, ninguno de penal: ECU-01, URY-01 y URY-03.
-- La segunda consulta, filtrada por la seleccion de Ecuador, devuelve solo ECU-01.
SELECT Pais, CodigoExterno, Goles, GolesDePenal FROM Incidencia.fn_TablaGoleadores(NULL) ORDER BY Goles DESC, CodigoExterno;
SELECT Pais, CodigoExterno, Goles, GolesDePenal
FROM Incidencia.fn_TablaGoleadores((SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ECU'))
ORDER BY Goles DESC, CodigoExterno;

PRINT '=== Prueba 18: tarjetas por seleccion ===';
-- Resultado esperado: Colombia 1 amarilla y 1 roja directa; Ecuador 2 amarillas y 1 roja por doble amarilla;
-- Uruguay 9 amarillas y 1 roja por doble amarilla (15 tarjetas en total, contando jugadores y cuerpo tecnico).
SELECT Pais, Amarillas, RojasDirectas, RojasPorDobleAmarilla
FROM Incidencia.fn_TarjetasPorSeleccion()
WHERE Pais IN ('Uruguay', 'Colombia', 'Ecuador')
ORDER BY Pais;
GO
