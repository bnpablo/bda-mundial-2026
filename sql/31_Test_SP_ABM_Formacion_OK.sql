/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-10
 Script       : 31_Test_SP_ABM_Formacion_OK.sql
 Objetivo     : Testing exitoso de 30_SP_ABM_Formacion.sql (relacion 1:1): alta,
                modificacion y baja de Alineacion y de Sustitucion. Muestra los
                datos antes y despues de cada operacion.
 Requisito    : ejecutar despues de 22_Test_SP_ABM_Seleccion_Validaciones.sql (usa
                el partido 3, Argentina contra Brasil, y los jugadores ARG-nn y
                BRA-nn), una sola vez. Los datos se cargan unicamente con los SP.
 Estado final : el partido 3 queda con 10 alineaciones (Argentina 8 y Brasil 2) y
                1 sustitucion (ARG-18 sale y entra ARG-19).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @JArg01 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-01');
DECLARE @JArg04 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-04');
DECLARE @JArg11 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-11');
DECLARE @JArg18 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-18');
DECLARE @JArg19 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-19');
DECLARE @JArg20 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-20');
DECLARE @JArg21 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-21');
DECLARE @JArg22 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-22');
DECLARE @JBra01 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'BRA-01');
DECLARE @JBra19 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'BRA-19');
DECLARE @JBra20 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'BRA-20');
DECLARE @AlArg18 INT, @AlArg19 INT, @AlArg20 INT, @AlArg21 INT, @AlBraTemporal INT;
DECLARE @IdSust1 INT, @IdSust2 INT;

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 0, 0

/*------------------------------------------------------------------------------
 ALINEACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta de alineaciones ===';
-- Resultado esperado: se insertan 10 alineaciones en el partido 3 con IdAlineacion autogenerado.
-- Argentina: 4 titulares (ARG-01, ARG-04, ARG-11, ARG-18) y 4 suplentes (ARG-19, ARG-20, ARG-21, ARG-22).
-- Brasil: 1 titular (BRA-01) y 1 suplente (BRA-19).
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg01, @EsTitular = 1, @PosicionCancha = 'POR';
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg04, @EsTitular = 1, @PosicionCancha = 'DEF';
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg11, @EsTitular = 1, @PosicionCancha = 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg18, @EsTitular = 1, @PosicionCancha = 'DEL', @IdAlineacion = @AlArg18 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg19, @EsTitular = 0, @PosicionCancha = 'DEL', @IdAlineacion = @AlArg19 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg20, @EsTitular = 0, @PosicionCancha = 'DEL', @IdAlineacion = @AlArg20 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg21, @EsTitular = 0, @PosicionCancha = 'DEL', @IdAlineacion = @AlArg21 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg22, @EsTitular = 0, @PosicionCancha = 'DEL';
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JBra01, @EsTitular = 1, @PosicionCancha = 'POR';
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JBra19, @EsTitular = 0, @PosicionCancha = 'DEL';
SELECT a.IdAlineacion, j.CodigoExterno AS Jugador, s.CodigoExterno AS Seleccion, a.EsTitular, a.PosicionCancha
FROM Formacion.Alineacion a
JOIN Torneo.Jugador j   ON j.IdJugador = a.IdJugador
JOIN Torneo.Seleccion s ON s.IdSeleccion = j.IdSeleccion
WHERE a.IdPartido = @IdP3
ORDER BY a.IdAlineacion;

PRINT '=== Prueba 2: modificacion de alineaciones ===';
-- Resultado esperado: ARG-21 pasa de suplente a titular (posicion DEL) y ARG-20 sigue siendo suplente pero
-- cambia su posicion de DEL a MED. Argentina queda con 5 titulares y 3 suplentes.
EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = @AlArg21, @EsTitular = 1, @PosicionCancha = 'DEL';
EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = @AlArg20, @EsTitular = 0, @PosicionCancha = 'MED';
SELECT a.IdAlineacion, j.CodigoExterno AS Jugador, a.EsTitular, a.PosicionCancha
FROM Formacion.Alineacion a
JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
WHERE a.IdAlineacion IN (@AlArg20, @AlArg21);

PRINT '=== Prueba 3: baja de una alineacion sin sustituciones ===';
-- Resultado esperado: se agrega BRA-20 como suplente de Brasil (3 alineaciones de Brasil) y se elimina;
-- la cantidad de alineaciones de Brasil vuelve a 2.
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JBra20, @EsTitular = 0, @PosicionCancha = 'DEL',
     @IdAlineacion = @AlBraTemporal OUTPUT;
SELECT COUNT(*) AS BrasilConTemporal FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
WHERE a.IdPartido = @IdP3 AND j.CodigoExterno LIKE 'BRA-%';
EXEC Formacion.usp_Alineacion_Baja @IdAlineacion = @AlBraTemporal;
SELECT COUNT(*) AS BrasilSinTemporal FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
WHERE a.IdPartido = @IdP3 AND j.CodigoExterno LIKE 'BRA-%';

/*------------------------------------------------------------------------------
 SUSTITUCION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 4: alta de una sustitucion ===';
-- Resultado esperado: se inserta el cambio en el que sale ARG-18 (titular) y entra ARG-19 (suplente) en el
-- minuto 60 del segundo tiempo.
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg18, @IdAlineacionEntra = @AlArg19,
     @Periodo = 'SegundoTiempo', @Minuto = 60, @Motivo = 'Tactico', @NumeroVentana = 1, @IdSustitucion = @IdSust1 OUTPUT;
SELECT IdSustitucion, IdAlineacionSale, IdAlineacionEntra, Periodo, Minuto, MinutoAdicional, NumeroVentana, Motivo
FROM Formacion.Sustitucion;

PRINT '=== Prueba 5: sustitucion de un jugador que ya habia ingresado ===';
-- Resultado esperado: se inserta un segundo cambio en el que sale ARG-19 (que habia entrado en el minuto 60) y
-- entra ARG-20 en el minuto 80. Hay 2 sustituciones.
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg19, @IdAlineacionEntra = @AlArg20,
     @Periodo = 'SegundoTiempo', @Minuto = 80, @Motivo = 'Lesion', @NumeroVentana = 2, @IdSustitucion = @IdSust2 OUTPUT;
SELECT IdSustitucion, IdAlineacionSale, IdAlineacionEntra, Periodo, Minuto, MinutoAdicional, NumeroVentana, Motivo
FROM Formacion.Sustitucion ORDER BY IdSustitucion;

PRINT '=== Prueba 6: modificacion de una sustitucion ===';
-- Resultado esperado: el minuto de la primera sustitucion pasa de 60 a 61. Quien sale y quien entra no cambian.
EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = @IdSust1, @Periodo = 'SegundoTiempo', @Minuto = 61,
     @Motivo = 'Tactico', @MinutoAdicional = 0, @NumeroVentana = 1;
SELECT IdSustitucion, IdAlineacionSale, IdAlineacionEntra, Minuto, MinutoAdicional FROM Formacion.Sustitucion
WHERE IdSustitucion = @IdSust1;

PRINT '=== Prueba 7: baja de una sustitucion ===';
-- Resultado esperado: se elimina el segundo cambio (ARG-19 por ARG-20); queda solo la primera sustitucion.
SELECT COUNT(*) AS SustitucionesAntes FROM Formacion.Sustitucion;
EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = @IdSust2;
SELECT COUNT(*) AS SustitucionesDespues FROM Formacion.Sustitucion;

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 10, 1
GO
