/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-10
 Script       : 32_Test_SP_ABM_Formacion_Validaciones.sql
 Objetivo     : Testing de las validaciones de 30_SP_ABM_Formacion.sql (relacion 1:1).
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero
                de error y el mensaje unico que agrupa todas las condiciones que no
                se cumplen. Las pruebas que necesitan datos auxiliares los cargan con
                los SP dentro de una transaccion que se deshace, de modo que ninguna
                prueba modifica datos.
 Requisito    : ejecutar despues de 31_Test_SP_ABM_Formacion_OK.sql, que deja el
                partido 3 con 10 alineaciones (Argentina 8 y Brasil 2) y 1 sustitucion.
 Nota         : la regla de maximo de 26 convocados por partido no se prueba porque
                cada seleccion tiene como maximo 26 jugadores. La baja de una
                alineacion con goles o tarjetas se prueba en los scripts de Incidencia.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdP1 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-001');
DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @JArg01 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-01');
DECLARE @JArg04 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-04');
DECLARE @JArg05 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-05');
DECLARE @JArg06 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-06');
DECLARE @JArg07 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-07');
DECLARE @JArg08 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-08');
DECLARE @JArg09 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-09');
DECLARE @JArg10 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-10');
DECLARE @JArg12 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-12');
DECLARE @JArg13 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-13');
DECLARE @JArg14 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-14');
DECLARE @JArg15 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-15');
DECLARE @JArg16 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-16');

DECLARE @AlArg01 INT, @AlArg04 INT, @AlArg11 INT, @AlArg18 INT, @AlArg19 INT, @AlArg20 INT, @AlArg21 INT, @AlArg22 INT, @AlBra19 INT;
SELECT @AlArg01 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-01';
SELECT @AlArg04 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-04';
SELECT @AlArg11 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-11';
SELECT @AlArg18 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-18';
SELECT @AlArg19 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-19';
SELECT @AlArg20 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-20';
SELECT @AlArg21 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-21';
SELECT @AlArg22 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'ARG-22';
SELECT @AlBra19 = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador WHERE a.IdPartido = @IdP3 AND j.CodigoExterno = 'BRA-19';
DECLARE @IdSust1 INT = (SELECT IdSustitucion FROM Formacion.Sustitucion WHERE IdAlineacionSale = @AlArg18);
DECLARE @AlArg05 INT, @AlArg12 INT, @AlArg13 INT, @AlArg14 INT, @AlArg15 INT, @AlArg16 INT, @IdSustTemporal INT;

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 10, 1

/*------------------------------------------------------------------------------
 ALINEACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alineacion con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 4 condiciones: partido inexistente, jugador inexistente, falta indicar
-- si es titular y posicion en cancha invalida.
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = 999, @IdJugador = 999999, @EsTitular = NULL, @PosicionCancha = 'XXX';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: jugador de una seleccion que no juega el partido ===';
-- Resultado esperado: error 50001: el jugador no pertenece a ninguna de las dos selecciones del partido
-- (el partido 1 todavia no tiene selecciones definidas).
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP1, @IdJugador = @JArg04, @EsTitular = 1, @PosicionCancha = 'DEF';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: jugador que ya esta en la alineacion del partido ===';
-- Resultado esperado: error 50001: "El jugador ya esta en la alineacion de este partido." (ARG-01).
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg01, @EsTitular = 1, @PosicionCancha = 'POR';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: doceavo titular de una seleccion ===';
-- Resultado esperado: error 50001: "La seleccion ya tiene 11 titulares en este partido." Se cargan 6 titulares
-- mas de Argentina (ya tenia 5) y se intenta agregar uno mas. Se deshace todo.
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg05, @EsTitular = 1, @PosicionCancha = 'DEF';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg06, @EsTitular = 1, @PosicionCancha = 'DEF';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg07, @EsTitular = 1, @PosicionCancha = 'DEF';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg08, @EsTitular = 1, @PosicionCancha = 'MED';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg09, @EsTitular = 1, @PosicionCancha = 'MED';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg10, @EsTitular = 1, @PosicionCancha = 'DEL';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg12, @EsTitular = 1, @PosicionCancha = 'MED';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH

PRINT '=== Prueba 5: modificar a titular cuando la seleccion ya tiene 11 ===';
-- Resultado esperado: error 50001: "La seleccion ya tiene 11 titulares en este partido." Se cargan 6 titulares
-- mas de Argentina y se intenta pasar a titular al suplente ARG-20. Se deshace todo.
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg05, @EsTitular = 1, @PosicionCancha = 'DEF';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg06, @EsTitular = 1, @PosicionCancha = 'DEF';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg07, @EsTitular = 1, @PosicionCancha = 'DEF';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg08, @EsTitular = 1, @PosicionCancha = 'MED';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg09, @EsTitular = 1, @PosicionCancha = 'MED';
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg10, @EsTitular = 1, @PosicionCancha = 'DEL';
    EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = @AlArg20, @EsTitular = 1, @PosicionCancha = 'MED';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH

PRINT '=== Prueba 6: modificar una alineacion inexistente con datos invalidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: la alineacion no existe, falta indicar si es titular y
-- la posicion en cancha es invalida.
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = 999999, @EsTitular = NULL, @PosicionCancha = 'XXX';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: cambiar la condicion de titular de un jugador que participa de una sustitucion ===';
-- Resultado esperado: error 50001: "No se puede cambiar la condicion de titular: el jugador participa de una
-- sustitucion." (ARG-18 salio en el cambio de la prueba 4 del script 31).
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = @AlArg18, @EsTitular = 0, @PosicionCancha = 'DEL';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: baja de una alineacion inexistente y de una con sustitucion ===';
-- Resultado esperado: dos errores 50001. Primero: "La alineacion indicada no existe." Segundo: "No se puede
-- eliminar: el jugador participa de una sustitucion." (ARG-18).
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Baja @IdAlineacion = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Baja @IdAlineacion = @AlArg18;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 SUSTITUCION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 9: sustitucion con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 6 condiciones: periodo obligatorio, minuto fuera de 0 a 120, minuto
-- adicional negativo, motivo obligatorio y las dos alineaciones inexistentes.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = 999999, @IdAlineacionEntra = 999998, @Periodo = '',
         @Minuto = 150, @Motivo = NULL, @MinutoAdicional = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: el mismo jugador sale y entra ===';
-- Resultado esperado: error 50001: "El jugador que sale y el que entra deben ser distintos."
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg01, @IdAlineacionEntra = @AlArg01,
         @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: jugadores de distinta seleccion y jugador que sale ya reemplazado ===';
-- Resultado esperado: error 50001 con 2 condiciones: los dos jugadores deben pertenecer a la misma seleccion
-- (ARG-18 y BRA-19) y el jugador que sale ya fue reemplazado (ARG-18 salio por ARG-19).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg18, @IdAlineacionEntra = @AlBra19,
         @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 12: el jugador que entra es titular ===';
-- Resultado esperado: error 50001: "El jugador que entra debe ser suplente." (ARG-01 es titular).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg04, @IdAlineacionEntra = @AlArg01,
         @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: el jugador que sale es un suplente que todavia no ingreso ===';
-- Resultado esperado: error 50001: "El jugador que sale es suplente y todavia no ingreso al campo."
-- (ARG-20 es suplente y no ingreso; entra ARG-22).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg20, @IdAlineacionEntra = @AlArg22,
         @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 14: el jugador que entra ya ingreso en otra sustitucion ===';
-- Resultado esperado: error 50001: "El jugador que entra ya ingreso en otra sustitucion." (ARG-19 entro por
-- ARG-18).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg04, @IdAlineacionEntra = @AlArg19,
         @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 15: sexto cambio de una seleccion ===';
-- Resultado esperado: error 50001: "La seleccion ya uso el maximo de 5 cambios en este partido." Argentina ya
-- tiene 1 cambio: se cargan jugadores auxiliares, se hacen 4 cambios mas y se intenta un sexto. Se deshace todo.
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg05, @EsTitular = 1, @PosicionCancha = 'DEF', @IdAlineacion = @AlArg05 OUTPUT;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg12, @EsTitular = 0, @PosicionCancha = 'MED', @IdAlineacion = @AlArg12 OUTPUT;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg13, @EsTitular = 0, @PosicionCancha = 'MED', @IdAlineacion = @AlArg13 OUTPUT;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg14, @EsTitular = 0, @PosicionCancha = 'MED', @IdAlineacion = @AlArg14 OUTPUT;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg15, @EsTitular = 0, @PosicionCancha = 'MED', @IdAlineacion = @AlArg15 OUTPUT;
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @JArg16, @EsTitular = 0, @PosicionCancha = 'MED', @IdAlineacion = @AlArg16 OUTPUT;
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg04, @IdAlineacionEntra = @AlArg12, @Periodo = 'SegundoTiempo', @Minuto = 62, @Motivo = 'Tactico';
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg11, @IdAlineacionEntra = @AlArg13, @Periodo = 'SegundoTiempo', @Minuto = 64, @Motivo = 'Tactico';
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg21, @IdAlineacionEntra = @AlArg14, @Periodo = 'SegundoTiempo', @Minuto = 66, @Motivo = 'Tactico';
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg01, @IdAlineacionEntra = @AlArg15, @Periodo = 'SegundoTiempo', @Minuto = 68, @Motivo = 'Lesion';
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg05, @IdAlineacionEntra = @AlArg16, @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH

PRINT '=== Prueba 16: modificar una sustitucion inexistente con datos invalidos ===';
-- Resultado esperado: error 50001 con 5 condiciones: la sustitucion no existe, periodo obligatorio, minuto
-- fuera de 0 a 120, minuto adicional negativo y motivo obligatorio.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = 999999, @Periodo = NULL, @Minuto = -1,
         @Motivo = '', @MinutoAdicional = -5;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 17: baja de una sustitucion inexistente y de una cuyo jugador que entro fue reemplazado luego ===';
-- Resultado esperado: dos errores 50001. Primero: "La sustitucion indicada no existe." Segundo: "No se puede
-- eliminar: el jugador que entro fue reemplazado luego." Se carga el cambio ARG-19 por ARG-20 y se intenta
-- eliminar el primero (ARG-18 por ARG-19). Se deshace todo.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlArg19, @IdAlineacionEntra = @AlArg20, @Periodo = 'SegundoTiempo',
         @Minuto = 80, @Motivo = 'Lesion', @IdSustitucion = @IdSustTemporal OUTPUT;
    EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = @IdSust1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 10, 1 (las pruebas no cambiaron nada)
GO
