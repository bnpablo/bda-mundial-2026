/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 92_Test_SP_Incidencia_Validaciones.sql
 Objetivo     : Testing de las validaciones de 90_SP_Incidencia.sql (relacion 1:1).
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero
                de error y el mensaje unico que agrupa todas las condiciones que no
                se cumplen.
 Requisito    : ejecutar despues de 91_Test_SP_Incidencia_OK.sql. Estado: INC-P0
                Finalizado; P1 a P5 En juego (P1: Uruguay 2 - Colombia 0, URY-01
                expulsado al 50' del segundo tiempo, URY-02 sustituido al 60' por
                URY-03); INC-P4: gol de ECU-01 y ECU-01 expulsado al 40'; INC-P6
                Programado.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdP0 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P0');
DECLARE @IdP1 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P1');
DECLARE @IdP2 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P2');
DECLARE @IdP4 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P4');
DECLARE @IdP6 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P6');

DECLARE @P1Ury01 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP1 AND j.CodigoExterno = 'URY-01');
DECLARE @P1Ury02 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP1 AND j.CodigoExterno = 'URY-02');
DECLARE @P1Ury03 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP1 AND j.CodigoExterno = 'URY-03');
DECLARE @P1Ury04 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP1 AND j.CodigoExterno = 'URY-04');
DECLARE @P1Col02 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP1 AND j.CodigoExterno = 'COL-02');
DECLARE @P4Ecu01 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP4 AND j.CodigoExterno = 'ECU-01');
DECLARE @P6Col01 INT = (SELECT a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                        WHERE a.IdPartido = @IdP6 AND j.CodigoExterno = 'COL-01');

DECLARE @DtUry INT = (SELECT ct.IdCuerpoTecnico FROM Torneo.CuerpoTecnico ct JOIN Torneo.Seleccion s ON s.IdSeleccion = ct.IdSeleccion
                      WHERE s.CodigoExterno = 'SEL-URY' AND ct.Rol = 'Director tecnico');
DECLARE @DtCol INT = (SELECT ct.IdCuerpoTecnico FROM Torneo.CuerpoTecnico ct JOIN Torneo.Seleccion s ON s.IdSeleccion = ct.IdSeleccion
                      WHERE s.CodigoExterno = 'SEL-COL' AND ct.Rol = 'Director tecnico');

DECLARE @GolUry01 INT = (SELECT IdGol FROM Incidencia.Gol WHERE IdAlineacionAutor = @P1Ury01);
DECLARE @GolEcu01 INT = (SELECT IdGol FROM Incidencia.Gol WHERE IdAlineacionAutor = @P4Ecu01);
DECLARE @RojaUry01 INT = (SELECT IdTarjeta FROM Incidencia.Tarjeta
                          WHERE IdAlineacion = @P1Ury01 AND TipoTarjeta = 'Roja por doble amarilla');
DECLARE @Amarilla1Ecu01 INT = (SELECT MIN(IdTarjeta) FROM Incidencia.Tarjeta
                               WHERE IdAlineacion = @P4Ecu01 AND TipoTarjeta = 'Amarilla');
DECLARE @AmarillaDtUry INT = (SELECT IdTarjeta FROM Incidencia.Tarjeta WHERE IdCuerpoTecnico = @DtUry);
DECLARE @RojaEcu01 INT = (SELECT IdTarjeta FROM Incidencia.Tarjeta
                          WHERE IdAlineacion = @P4Ecu01 AND TipoTarjeta = 'Roja por doble amarilla');

SELECT (SELECT COUNT(*) FROM Incidencia.Gol) AS Goles, (SELECT COUNT(*) FROM Incidencia.Tarjeta) AS Tarjetas;
-- esperado: 3 goles y 15 tarjetas

/*------------------------------------------------------------------------------
 REGISTRAR Y ANULAR GOLES
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: gol con varios errores a la vez ===';
-- Resultado esperado: error 50001 con 3 condiciones: tipo de gol invalido, el minuto 50 no corresponde al
-- primer tiempo y el asistente debe ser un companero del autor (COL-02 es de la otra seleccion).
BEGIN TRY
    EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Ury04, @TipoGol = 'Chilena', @Periodo = 'Primer tiempo',
         @Minuto = 50, @IdAlineacionAsistente = @P1Col02;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: gol de un jugador que ya fue sustituido ===';
-- Resultado esperado: error 50001: "El autor no estaba en cancha en ese momento del partido." (URY-02 salio al
-- 60' y el gol es al 70').
BEGIN TRY
    EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Ury02, @TipoGol = 'Jugada', @Periodo = 'Segundo tiempo',
         @Minuto = 70;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: gol de un suplente antes de entrar ===';
-- Resultado esperado: error 50001: "El autor no estaba en cancha en ese momento del partido." (URY-03 entro al
-- 60' del segundo tiempo y el gol es al 30' del primero).
BEGIN TRY
    EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Ury03, @TipoGol = 'Jugada', @Periodo = 'Primer tiempo',
         @Minuto = 30;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: definicion por penales en la fase de grupos ===';
-- Resultado esperado: error 50001: "En la fase de grupos no hay alargue ni definicion por penales."
BEGIN TRY
    EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P1Ury04, @TipoGol = 'Penal', @Periodo = 'Penales',
         @Minuto = 120;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: gol en un partido que todavia no empezo ===';
-- Resultado esperado: error 50001: "Solo se pueden registrar goles en un partido En juego." (INC-P6 esta
-- Programado).
BEGIN TRY
    EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @P6Col01, @TipoGol = 'Jugada', @Periodo = 'Primer tiempo',
         @Minuto = 10;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: anular un gol inexistente ===';
-- Resultado esperado: error 50001: "El gol indicado no existe."
BEGIN TRY
    EXEC Incidencia.usp_AnularGol @IdGol = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 REGISTRAR Y ANULAR TARJETAS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 7: tarjeta a un jugador ya expulsado ===';
-- Resultado esperado: error 50001: "El destinatario ya habia sido expulsado antes de ese momento del partido."
-- (URY-01 fue expulsado al 50' del segundo tiempo).
BEGIN TRY
    EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdAlineacion = @P1Ury01, @TipoTarjeta = 'Amarilla',
         @Periodo = 'Segundo tiempo', @Minuto = 70;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: tarjeta con varios errores a la vez ===';
-- Resultado esperado: error 50001 con 3 condiciones: dos destinatarios (jugador y director tecnico), la roja
-- por doble amarilla no se carga a mano y el minuto 95 no corresponde al segundo tiempo.
BEGIN TRY
    EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP1, @IdAlineacion = @P1Ury04, @IdCuerpoTecnico = @DtUry,
         @TipoTarjeta = 'Roja por doble amarilla', @Periodo = 'Segundo tiempo', @Minuto = 95;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: tarjeta en un partido finalizado ===';
-- Resultado esperado: error 50001: "Solo se pueden registrar tarjetas en un partido En juego." (INC-P0, que
-- jugo Colombia, esta Finalizado).
BEGIN TRY
    EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP0, @IdCuerpoTecnico = @DtCol, @TipoTarjeta = 'Amarilla',
         @Periodo = 'Primer tiempo', @Minuto = 10;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: tarjeta con la alineacion de otro partido ===';
-- Resultado esperado: error 50001: "La alineacion no existe o no corresponde a este partido." (la alineacion
-- de URY-04 es de INC-P1 y la tarjeta es para INC-P2).
BEGIN TRY
    EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @IdP2, @IdAlineacion = @P1Ury04, @TipoTarjeta = 'Amarilla',
         @Periodo = 'Primer tiempo', @Minuto = 10;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: anular directamente una roja por doble amarilla ===';
-- Resultado esperado: error 50001: "La roja por doble amarilla no se anula directamente: anule una de las dos
-- amarillas."
BEGIN TRY
    EXEC Incidencia.usp_AnularTarjeta @IdTarjeta = @RojaUry01;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 12: anular una tarjeta inexistente ===';
-- Resultado esperado: error 50001: "La tarjeta indicada no existe."
BEGIN TRY
    EXEC Incidencia.usp_AnularTarjeta @IdTarjeta = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 MODIFICACION DE GOLES Y TARJETAS
 Gol de ECU-01 en INC-P4: primer tiempo, 22', Cabezazo. ECU-01 tiene amarillas
 al 26' y al 40' y roja por doble amarilla al 40'. El director tecnico de
 Uruguay tiene una amarilla al 85' del segundo tiempo en INC-P1.
------------------------------------------------------------------------------*/
PRINT '=== Prueba 13: convertir un gol en gol en contra ===';
-- Resultado esperado: error 50001: "Cambiar un gol a En contra (o al reves) altera el marcador: anule el gol y
-- registrelo de nuevo."
BEGIN TRY
    EXEC Incidencia.usp_Gol_Modificacion @IdGol = @GolEcu01, @TipoGol = 'En contra', @Minuto = 22;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 14: minuto fuera del periodo y autor ya expulsado ===';
-- Resultado esperado: error 50001 con 2 condiciones: el minuto 60 no corresponde al primer tiempo y el autor
-- no estaba en cancha (fue expulsado al 40').
BEGIN TRY
    EXEC Incidencia.usp_Gol_Modificacion @IdGol = @GolEcu01, @TipoGol = 'Cabezazo', @Minuto = 60;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 15: cambiar el minuto de una amarilla de un jugador expulsado por doble amarilla ===';
-- Resultado esperado: error 50001: "El destinatario fue expulsado por doble amarilla: a sus amarillas solo se les
-- corrige el motivo." (la primera amarilla de ECU-01 no puede pasar del 26' al 30').
BEGIN TRY
    EXEC Incidencia.usp_Tarjeta_Modificacion @IdTarjeta = @Amarilla1Ecu01, @Minuto = 30, @Motivo = 'Falta tactica';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 16: modificar un gol inexistente ===';
-- Resultado esperado: error 50001: "El gol indicado no existe."
BEGIN TRY
    EXEC Incidencia.usp_Gol_Modificacion @IdGol = 999, @TipoGol = 'Jugada', @Minuto = 10;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 17: tarjeta con un minuto fuera del periodo ===';
-- Resultado esperado: error 50001: "El minuto no corresponde al periodo Segundo tiempo." (la amarilla del
-- director tecnico de Uruguay es del segundo tiempo y se intenta pasar al minuto 30).
BEGIN TRY
    EXEC Incidencia.usp_Tarjeta_Modificacion @IdTarjeta = @AmarillaDtUry, @Minuto = 30, @Motivo = 'Protesta';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 18: modificar la roja que genero el sistema ===';
-- Resultado esperado: error 50001: "La roja por doble amarilla la genera el sistema y no se modifica."
BEGIN TRY
    EXEC Incidencia.usp_Tarjeta_Modificacion @IdTarjeta = @RojaEcu01, @Minuto = 40, @Motivo = 'Otro motivo';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 19: modificar una tarjeta inexistente ===';
-- Resultado esperado: error 50001: "La tarjeta indicada no existe."
BEGIN TRY
    EXEC Incidencia.usp_Tarjeta_Modificacion @IdTarjeta = 999, @Minuto = 10;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 PARTIDO FINALIZADO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 20: anular un gol despues de finalizar el partido ===';
-- Resultado esperado: INC-P1 se finaliza con usp_FinalizarPartido y el resultado queda 2 a 0 (el que calcularon los SP
-- de goles). Despues, anular el gol de URY-01 da error 50001: "Solo se pueden anular goles de un partido En
-- juego." y el resultado sigue 2 a 0.
EXEC Torneo.usp_FinalizarPartido @IdPartido = @IdP1, @Asistencia = 70000;
BEGIN TRY
    EXEC Incidencia.usp_AnularGol @IdGol = @GolUry01;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT IdPartido, Estado, GolesLocal, GolesVisitante, Asistencia FROM Torneo.Partido WHERE IdPartido = @IdP1;

SELECT (SELECT COUNT(*) FROM Incidencia.Gol) AS Goles, (SELECT COUNT(*) FROM Incidencia.Tarjeta) AS Tarjetas;
-- esperado: 3 goles y 15 tarjetas (ningun caso invalido modifico datos)
GO
