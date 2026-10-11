/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-10
 Script       : 31_Test_SP_ABM_Formacion_OK.sql
 Objetivo     : Testing exitoso de 30_SP_ABM_Formacion.sql: alta, modificacion y
                baja de Alineacion y Sustitucion. Muestra los datos antes y
                despues de cada operacion.
 Requisito    : ejecutar despues de 22_Test_SP_ABM_Seleccion_Validaciones.sql (usa
                las selecciones de Argentina y Brasil con su convocatoria y el
                partido 3), una sola vez. Los datos se cargan unicamente con los SP.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @Arg01 INT, @Arg02 INT, @Arg04 INT, @Arg05 INT, @Arg06 INT, @Arg07 INT, @Arg08 INT,
        @Arg11 INT, @Arg12 INT, @Arg13 INT, @Arg14 INT, @Arg15 INT, @Arg16 INT,
        @Arg18 INT, @Arg19 INT, @Arg20 INT, @Arg21 INT, @Arg23 INT, @Bra01 INT, @Bra12 INT;
DECLARE @Al02 INT, @Al05 INT, @Al06 INT, @Al07 INT, @Al08 INT, @Al14 INT, @Al15 INT,
        @Al16 INT, @Al19 INT, @Al20 INT, @Al21 INT;
DECLARE @IdAlTemp INT, @IdSust1 INT, @IdSustTemp INT;

SELECT @Arg01 = MAX(CASE WHEN CodigoExterno = 'ARG-01' THEN IdJugador ELSE 0 END),
       @Arg02 = MAX(CASE WHEN CodigoExterno = 'ARG-02' THEN IdJugador ELSE 0 END),
       @Arg04 = MAX(CASE WHEN CodigoExterno = 'ARG-04' THEN IdJugador ELSE 0 END),
       @Arg05 = MAX(CASE WHEN CodigoExterno = 'ARG-05' THEN IdJugador ELSE 0 END),
       @Arg06 = MAX(CASE WHEN CodigoExterno = 'ARG-06' THEN IdJugador ELSE 0 END),
       @Arg07 = MAX(CASE WHEN CodigoExterno = 'ARG-07' THEN IdJugador ELSE 0 END),
       @Arg08 = MAX(CASE WHEN CodigoExterno = 'ARG-08' THEN IdJugador ELSE 0 END),
       @Arg11 = MAX(CASE WHEN CodigoExterno = 'ARG-11' THEN IdJugador ELSE 0 END),
       @Arg12 = MAX(CASE WHEN CodigoExterno = 'ARG-12' THEN IdJugador ELSE 0 END),
       @Arg13 = MAX(CASE WHEN CodigoExterno = 'ARG-13' THEN IdJugador ELSE 0 END),
       @Arg14 = MAX(CASE WHEN CodigoExterno = 'ARG-14' THEN IdJugador ELSE 0 END),
       @Arg15 = MAX(CASE WHEN CodigoExterno = 'ARG-15' THEN IdJugador ELSE 0 END),
       @Arg16 = MAX(CASE WHEN CodigoExterno = 'ARG-16' THEN IdJugador ELSE 0 END),
       @Arg18 = MAX(CASE WHEN CodigoExterno = 'ARG-18' THEN IdJugador ELSE 0 END),
       @Arg19 = MAX(CASE WHEN CodigoExterno = 'ARG-19' THEN IdJugador ELSE 0 END),
       @Arg20 = MAX(CASE WHEN CodigoExterno = 'ARG-20' THEN IdJugador ELSE 0 END),
       @Arg21 = MAX(CASE WHEN CodigoExterno = 'ARG-21' THEN IdJugador ELSE 0 END),
       @Arg23 = MAX(CASE WHEN CodigoExterno = 'ARG-23' THEN IdJugador ELSE 0 END),
       @Bra01 = MAX(CASE WHEN CodigoExterno = 'BRA-01' THEN IdJugador ELSE 0 END),
       @Bra12 = MAX(CASE WHEN CodigoExterno = 'BRA-12' THEN IdJugador ELSE 0 END)
FROM Torneo.Jugador;

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 0, 0

/*------------------------------------------------------------------------------
 ALINEACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta de la alineacion de Argentina y de Brasil en el partido 3 ===';
-- Resultado esperado: Argentina queda con 11 titulares (formacion 4-3-3) y 6 suplentes; Brasil con 1 titular
-- y 1 suplente. En total 19 alineaciones.
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg01, 1, 'POR';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg04, 1, 'DEF';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg05, 1, 'DEF';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg06, 1, 'DEF';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg07, 1, 'DEF';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg11, 1, 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg12, 1, 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg13, 1, 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg18, 1, 'DEL';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg19, 1, 'DEL';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg20, 1, 'DEL';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg02, 0, 'POR';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg08, 0, 'DEF';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg14, 0, 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg15, 0, 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg16, 0, 'MED';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg21, 0, 'DEL';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Bra01, 1, 'POR';
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Bra12, 0, 'MED';
SELECT s.CodigoExterno AS Seleccion,
       SUM(CASE WHEN a.EsTitular = 1 THEN 1 ELSE 0 END) AS Titulares,
       SUM(CASE WHEN a.EsTitular = 0 THEN 1 ELSE 0 END) AS Suplentes
FROM Formacion.Alineacion a
JOIN Torneo.Jugador j   ON j.IdJugador = a.IdJugador
JOIN Torneo.Seleccion s ON s.IdSeleccion = j.IdSeleccion
WHERE a.IdPartido = @IdP3
GROUP BY s.CodigoExterno ORDER BY s.CodigoExterno;

-- Ids de alineacion que se usan en las sustituciones
SELECT @Al02 = MAX(CASE WHEN j.CodigoExterno = 'ARG-02' THEN a.IdAlineacion ELSE 0 END),
       @Al05 = MAX(CASE WHEN j.CodigoExterno = 'ARG-05' THEN a.IdAlineacion ELSE 0 END),
       @Al06 = MAX(CASE WHEN j.CodigoExterno = 'ARG-06' THEN a.IdAlineacion ELSE 0 END),
       @Al07 = MAX(CASE WHEN j.CodigoExterno = 'ARG-07' THEN a.IdAlineacion ELSE 0 END),
       @Al08 = MAX(CASE WHEN j.CodigoExterno = 'ARG-08' THEN a.IdAlineacion ELSE 0 END),
       @Al14 = MAX(CASE WHEN j.CodigoExterno = 'ARG-14' THEN a.IdAlineacion ELSE 0 END),
       @Al15 = MAX(CASE WHEN j.CodigoExterno = 'ARG-15' THEN a.IdAlineacion ELSE 0 END),
       @Al16 = MAX(CASE WHEN j.CodigoExterno = 'ARG-16' THEN a.IdAlineacion ELSE 0 END),
       @Al19 = MAX(CASE WHEN j.CodigoExterno = 'ARG-19' THEN a.IdAlineacion ELSE 0 END),
       @Al20 = MAX(CASE WHEN j.CodigoExterno = 'ARG-20' THEN a.IdAlineacion ELSE 0 END),
       @Al21 = MAX(CASE WHEN j.CodigoExterno = 'ARG-21' THEN a.IdAlineacion ELSE 0 END)
FROM Formacion.Alineacion a
JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
WHERE a.IdPartido = @IdP3;

PRINT '=== Prueba 2: modificacion de una alineacion ===';
-- Resultado esperado: la posicion en cancha del suplente ARG-15 pasa de MED a DEL. La condicion de suplente
-- no cambia.
SELECT a.IdAlineacion, j.CodigoExterno, a.EsTitular, a.PosicionCancha FROM Formacion.Alineacion a
JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdAlineacion = @Al15;
EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = @Al15, @EsTitular = 0, @PosicionCancha = 'DEL';
SELECT a.IdAlineacion, j.CodigoExterno, a.EsTitular, a.PosicionCancha FROM Formacion.Alineacion a
JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdAlineacion = @Al15;

PRINT '=== Prueba 3: baja de una alineacion sin sustituciones ===';
-- Resultado esperado: se agrega ARG-23 como suplente (20 alineaciones en el partido) y se elimina; la
-- cantidad vuelve a 19.
EXEC Formacion.usp_Alineacion_Alta @IdP3, @Arg23, 0, 'DEL', @IdAlTemp OUTPUT;
SELECT COUNT(*) AS AlineacionesConTemporal FROM Formacion.Alineacion WHERE IdPartido = @IdP3;
EXEC Formacion.usp_Alineacion_Baja @IdAlineacion = @IdAlTemp;
SELECT COUNT(*) AS AlineacionesSinTemporal FROM Formacion.Alineacion WHERE IdPartido = @IdP3;

/*------------------------------------------------------------------------------
 SUSTITUCION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 4: alta de una sustitucion ===';
-- Resultado esperado: se registra el cambio 1 de Argentina: sale ARG-07 (titular) y entra ARG-08 (suplente)
-- en el minuto 60 del segundo tiempo, ventana 1, por motivo tactico.
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al07, @IdAlineacionEntra = @Al08,
     @Periodo = 'Segundo tiempo', @Minuto = 60, @Motivo = 'Tactico', @NumeroVentana = 1,
     @IdSustitucion = @IdSust1 OUTPUT;
SELECT su.IdSustitucion, js.CodigoExterno AS Sale, je.CodigoExterno AS Entra, su.Periodo, su.Minuto,
       su.MinutoAdicional, su.NumeroVentana, su.Motivo
FROM Formacion.Sustitucion su
JOIN Formacion.Alineacion asa ON asa.IdAlineacion = su.IdAlineacionSale
JOIN Torneo.Jugador js        ON js.IdJugador = asa.IdJugador
JOIN Formacion.Alineacion aen ON aen.IdAlineacion = su.IdAlineacionEntra
JOIN Torneo.Jugador je        ON je.IdJugador = aen.IdJugador
WHERE su.IdSustitucion = @IdSust1;

PRINT '=== Prueba 5: modificacion de una sustitucion ===';
-- Resultado esperado: el cambio pasa al minuto 65 con 2 minutos adicionales y el motivo pasa a Lesion.
-- Quienes salen y entran no cambian.
EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = @IdSust1, @Periodo = 'Segundo tiempo',
     @Minuto = 65, @Motivo = 'Lesion', @MinutoAdicional = 2, @NumeroVentana = 1;
SELECT IdSustitucion, Periodo, Minuto, MinutoAdicional, NumeroVentana, Motivo
FROM Formacion.Sustitucion WHERE IdSustitucion = @IdSust1;

PRINT '=== Prueba 6: baja de una sustitucion ===';
-- Resultado esperado: se registra un cambio temporal (sale ARG-19, entra ARG-16): hay 2 sustituciones. Se
-- elimina y vuelve a haber 1.
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al19, @IdAlineacionEntra = @Al16,
     @Periodo = 'Segundo tiempo', @Minuto = 70, @Motivo = 'Tactico', @NumeroVentana = 2,
     @IdSustitucion = @IdSustTemp OUTPUT;
SELECT COUNT(*) AS SustitucionesConTemporal FROM Formacion.Sustitucion;
EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = @IdSustTemp;
SELECT COUNT(*) AS SustitucionesSinTemporal FROM Formacion.Sustitucion;

PRINT '=== Prueba 7: Argentina completa los 5 cambios del partido ===';
-- Resultado esperado: se registran 4 cambios mas y Argentina queda con 5 (el maximo). El ultimo es una cadena:
-- ARG-21 entra en el cambio 4 y sale en el 5, reemplazado por ARG-02.
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al06, @IdAlineacionEntra = @Al14,
     @Periodo = 'Segundo tiempo', @Minuto = 70, @Motivo = 'Tactico', @NumeroVentana = 2;
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al05, @IdAlineacionEntra = @Al15,
     @Periodo = 'Segundo tiempo', @Minuto = 70, @Motivo = 'Tactico', @NumeroVentana = 2;
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al20, @IdAlineacionEntra = @Al21,
     @Periodo = 'Segundo tiempo', @Minuto = 80, @Motivo = 'Tactico', @NumeroVentana = 3;
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al21, @IdAlineacionEntra = @Al02,
     @Periodo = 'Segundo tiempo', @Minuto = 85, @Motivo = 'Lesion', @NumeroVentana = 3;
SELECT su.IdSustitucion, js.CodigoExterno AS Sale, je.CodigoExterno AS Entra, su.Minuto, su.NumeroVentana, su.Motivo
FROM Formacion.Sustitucion su
JOIN Formacion.Alineacion asa ON asa.IdAlineacion = su.IdAlineacionSale
JOIN Torneo.Jugador js        ON js.IdJugador = asa.IdJugador
JOIN Formacion.Alineacion aen ON aen.IdAlineacion = su.IdAlineacionEntra
JOIN Torneo.Jugador je        ON je.IdJugador = aen.IdJugador
WHERE asa.IdPartido = @IdP3
ORDER BY su.IdSustitucion;

PRINT '=== Prueba 8: sexto cambio de Argentina en la prorroga ===';
-- Resultado esperado: el sexto cambio solo se admite en la prorroga y en una ventana propia: sale ARG-19 y entra
-- ARG-16 en el minuto 100 (Alargue 1, ventana 4, motivo Precaucion), con lo que hay 6 sustituciones. Se elimina a
-- continuacion y vuelven a ser 5, que es el estado que esperan los tests siguientes.
EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al19, @IdAlineacionEntra = @Al16,
     @Periodo = 'Alargue 1', @Minuto = 100, @Motivo = 'Precaucion', @NumeroVentana = 4,
     @IdSustitucion = @IdSustTemp OUTPUT;
SELECT COUNT(*) AS SustitucionesConProrroga FROM Formacion.Sustitucion;
EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = @IdSustTemp;
SELECT COUNT(*) AS SustitucionesSinProrroga FROM Formacion.Sustitucion;
GO
