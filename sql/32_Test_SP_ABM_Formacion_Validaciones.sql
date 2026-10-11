/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-10
 Script       : 32_Test_SP_ABM_Formacion_Validaciones.sql
 Objetivo     : Testing de las validaciones de 30_SP_ABM_Formacion.sql. Cada caso
                invalido se ejecuta dentro de TRY/CATCH: muestra el numero de error
                y el mensaje unico que agrupa todas las condiciones que no se
                cumplen, y no modifica ningun dato (el unico jugador que se crea,
                el de la prueba 2, se elimina al terminar).
 Requisito    : ejecutar despues de 31_Test_SP_ABM_Formacion_OK.sql, que deja en el
                partido 3 la alineacion de Argentina (11 titulares y 6 suplentes),
                la de Brasil (1 titular y 1 suplente) y 5 cambios de Argentina.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @SelUsa INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-USA');
DECLARE @Arg01 INT, @Arg03 INT, @IdTemp INT;
DECLARE @Al07 INT, @Al08 INT, @Al11 INT, @Al16 INT, @Al19 INT, @Al21 INT, @AlBra01 INT, @AlBra12 INT, @IdSustC4 INT;

SELECT @Arg01 = MAX(CASE WHEN CodigoExterno = 'ARG-01' THEN IdJugador ELSE 0 END),
       @Arg03 = MAX(CASE WHEN CodigoExterno = 'ARG-03' THEN IdJugador ELSE 0 END)
FROM Torneo.Jugador;

SELECT @Al07 = MAX(CASE WHEN j.CodigoExterno = 'ARG-07' THEN a.IdAlineacion ELSE 0 END),
       @Al08 = MAX(CASE WHEN j.CodigoExterno = 'ARG-08' THEN a.IdAlineacion ELSE 0 END),
       @Al11 = MAX(CASE WHEN j.CodigoExterno = 'ARG-11' THEN a.IdAlineacion ELSE 0 END),
       @Al16 = MAX(CASE WHEN j.CodigoExterno = 'ARG-16' THEN a.IdAlineacion ELSE 0 END),
       @Al19 = MAX(CASE WHEN j.CodigoExterno = 'ARG-19' THEN a.IdAlineacion ELSE 0 END),
       @Al21 = MAX(CASE WHEN j.CodigoExterno = 'ARG-21' THEN a.IdAlineacion ELSE 0 END),
       @AlBra01 = MAX(CASE WHEN j.CodigoExterno = 'BRA-01' THEN a.IdAlineacion ELSE 0 END),
       @AlBra12 = MAX(CASE WHEN j.CodigoExterno = 'BRA-12' THEN a.IdAlineacion ELSE 0 END)
FROM Formacion.Alineacion a
JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
WHERE a.IdPartido = @IdP3;

SELECT @IdSustC4 = IdSustitucion FROM Formacion.Sustitucion WHERE IdAlineacionEntra = @Al21;

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 19, 5

/*------------------------------------------------------------------------------
 ALINEACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alineacion con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 4 condiciones: el partido no existe, el jugador no existe, debe
-- indicarse si el jugador es titular y la posicion en cancha es invalida.
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = 999, @IdJugador = 999, @EsTitular = NULL, @PosicionCancha = 'XXX';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: jugador de una seleccion que no juega el partido ===';
-- Resultado esperado: error 50001 con 1 condicion: el jugador no pertenece a ninguna de las dos selecciones
-- del partido (se crea un jugador temporal de Estados Unidos y se elimina al terminar).
EXEC Torneo.usp_Jugador_Alta 'USA-99', 'Jugador', 'Temporal', @PaisUsa, @SelUsa, 99, 'DEL', 'Club Demo', '2026-05-21', NULL, @IdTemp OUTPUT;
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @IdTemp, @EsTitular = 0, @PosicionCancha = 'DEL';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
EXEC Torneo.usp_Jugador_Baja @IdJugador = @IdTemp;

PRINT '=== Prueba 3: jugador repetido como titular en una seleccion con 11 titulares ===';
-- Resultado esperado: error 50001 con 2 condiciones: el jugador ya esta en la alineacion de este partido y la
-- seleccion ya tiene 11 titulares (ARG-01 ya es titular de Argentina).
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @Arg01, @EsTitular = 1, @PosicionCancha = 'POR';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: duodecimo titular ===';
-- Resultado esperado: error 50001 con 1 condicion: la seleccion ya tiene 11 titulares en este partido.
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Alta @IdPartido = @IdP3, @IdJugador = @Arg03, @EsTitular = 1, @PosicionCancha = 'POR';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: modificar una alineacion inexistente y sin datos ===';
-- Resultado esperado: error 50001 con 3 condiciones: la alineacion no existe, debe indicarse si el jugador es
-- titular y la posicion en cancha es invalida.
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = 999999, @EsTitular = NULL, @PosicionCancha = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: pasar a titular a un suplente que ya ingreso, con 11 titulares ===';
-- Resultado esperado: error 50001 con 2 condiciones: no se puede cambiar la condicion de titular porque el
-- jugador participa de una sustitucion, y la seleccion ya tiene 11 titulares (ARG-08 entro por ARG-07).
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Modificacion @IdAlineacion = @Al08, @EsTitular = 1, @PosicionCancha = 'DEF';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: baja de una alineacion con sustitucion y de una inexistente ===';
-- Resultado esperado: dos errores 50001. Primero: no se puede eliminar porque el jugador participa de una
-- sustitucion (ARG-07 salio). Segundo: la alineacion indicada no existe.
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Baja @IdAlineacion = @Al07;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    EXEC Formacion.usp_Alineacion_Baja @IdAlineacion = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 SUSTITUCION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 8: sustitucion con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 6 condiciones: periodo fuera del dominio, minuto fuera de 0 a 120, minuto
-- adicional negativo, motivo fuera del dominio, y las alineaciones de quien sale y de quien entra no existen.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = 999999, @IdAlineacionEntra = 999998,
         @Periodo = '', @Minuto = 999, @Motivo = NULL, @MinutoAdicional = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: el mismo jugador sale y entra ===';
-- Resultado esperado: error 50001 con 1 condicion: el jugador que sale y el que entra deben ser distintos.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al11, @IdAlineacionEntra = @Al11,
         @Periodo = 'Segundo tiempo', @Minuto = 80, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: cambio entre jugadores de distinta seleccion ===';
-- Resultado esperado: error 50001 con 2 condiciones: los dos jugadores deben pertenecer a la misma seleccion
-- (sale ARG-11 y entra BRA-12) y la seleccion que sale (Argentina) ya uso los 5 cambios del tiempo reglamentario.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al11, @IdAlineacionEntra = @AlBra12,
         @Periodo = 'Segundo tiempo', @Minuto = 80, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: sexto cambio de una seleccion ===';
-- Resultado esperado: error 50001 con 1 condicion: la seleccion ya uso los 5 cambios del tiempo reglamentario
-- (el sexto solo se permite en la prorroga). Sale ARG-19, titular que sigue en cancha, y entra ARG-16, suplente
-- que no ingreso.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al19, @IdAlineacionEntra = @Al16,
         @Periodo = 'Segundo tiempo', @Minuto = 88, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 12: jugador que sale ya reemplazado y que entra ya ingreso ===';
-- Resultado esperado: error 50001 con 3 condiciones: el jugador que sale ya fue reemplazado (ARG-07), el
-- jugador que entra ya ingreso en otra sustitucion (ARG-08) y la seleccion ya uso los 5 cambios del tiempo reglamentario.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al07, @IdAlineacionEntra = @Al08,
         @Periodo = 'Segundo tiempo', @Minuto = 88, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: modificar una sustitucion inexistente con datos invalidos ===';
-- Resultado esperado: error 50001 con 4 condiciones: la sustitucion no existe, periodo fuera del dominio, minuto
-- fuera de 0 a 120 y motivo fuera del dominio.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = 999999, @Periodo = '', @Minuto = 130, @Motivo = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 14: baja de una sustitucion inexistente y de una cuyo ingresado fue reemplazado luego ===';
-- Resultado esperado: dos errores 50001. Primero: la sustitucion indicada no existe. Segundo: no se puede
-- eliminar porque el jugador que entro fue reemplazado luego (ARG-21 entro en el cambio 4 y salio en el 5).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Baja @IdSustitucion = @IdSustC4;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 15: sustitucion con periodo y motivo fuera del dominio ===';
-- Resultado esperado: error 50001 con 2 condiciones: el periodo debe ser Primer tiempo, Segundo tiempo,
-- Alargue 1 o Alargue 2 ('SegundoTiempo' no es valido) y el motivo debe ser Tactico, Lesion o Precaucion ('Cansancio'
-- no es valido). Sale BRA-01 y entra BRA-12 (Brasil no uso cambios), asi que es lo unico que falla.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @AlBra01, @IdAlineacionEntra = @AlBra12,
         @Periodo = 'SegundoTiempo', @Minuto = 60, @Motivo = 'Cansancio';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 16: modificar una sustitucion con periodo y motivo fuera del dominio ===';
-- Resultado esperado: error 50001 con 2 condiciones: el periodo debe ser Primer tiempo, Segundo tiempo,
-- Alargue 1 o Alargue 2 ('Penales' no es valido: no hay cambios en la tanda) y el motivo debe ser Tactico,
-- Lesion o Precaucion ('Indisciplina' no es valido).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = @IdSustC4, @Periodo = 'Penales', @Minuto = 85,
         @Motivo = 'Indisciplina';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 17: sexto cambio en una cuarta ventana del tiempo reglamentario ===';
-- Resultado esperado: error 50001 con 2 condiciones: la seleccion ya uso los 5 cambios del tiempo reglamentario y
-- las 3 ventanas de cambios del tiempo reglamentario (Argentina uso las ventanas 1, 2 y 3; la 4 solo corresponde a
-- la prorroga).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Alta @IdAlineacionSale = @Al19, @IdAlineacionEntra = @Al16,
         @Periodo = 'Segundo tiempo', @Minuto = 88, @Motivo = 'Tactico', @NumeroVentana = 4;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 18: modificar una sustitucion a una cuarta ventana del tiempo reglamentario ===';
-- Resultado esperado: error 50001 con 1 condicion: la seleccion ya uso las 3 ventanas de cambios del tiempo
-- reglamentario (las otras sustituciones de Argentina usan las ventanas 1, 2 y 3).
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = @IdSustC4, @Periodo = 'Segundo tiempo',
         @Minuto = 80, @Motivo = 'Tactico', @NumeroVentana = 4;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 19: numero de ventana invalido en la prorroga ===';
-- Resultado esperado: error 50001 con 1 condicion: el numero de ventana debe ser mayor o igual a 1.
BEGIN TRY
    EXEC Formacion.usp_Sustitucion_Modificacion @IdSustitucion = @IdSustC4, @Periodo = 'Alargue 1',
         @Minuto = 100, @Motivo = 'Precaucion', @NumeroVentana = 0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 19, 5 (las pruebas no cambiaron nada)
GO
