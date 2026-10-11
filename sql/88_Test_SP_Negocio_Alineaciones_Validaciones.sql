/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 88_Test_SP_Negocio_Alineaciones_Validaciones.sql
 Objetivo     : Testing de las validaciones de 86_SP_Negocio_Alineaciones.sql. Cada
                caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero de
                error y el mensaje unico que agrupa todas las condiciones que no se
                cumplen. Para las pruebas con una seleccion sin alineacion se crea
                un partido temporal (PARTIDO-006) que se elimina al terminar.
 Requisito    : ejecutar despues de 87_Test_SP_Negocio_Alineaciones_OK.sql. Estado:
                el partido 5 (En juego) con la alineacion de Argentina y de Brasil y
                un cambio de cada una; el partido 3 (Finalizado) con la alineacion
                de Argentina cargada por el script 31; ARG-26 de baja desde el
                02/06/2026.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @SelUsa INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-USA');
DECLARE @SedeMetLife INT = (SELECT IdSede FROM Torneo.Sede WHERE CodigoExterno = 'SEDE-METLIFE');
DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @IdP5 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-005');
DECLARE @IdP6 INT;
DECLARE @Arg01 INT, @Arg05 INT, @Arg06 INT, @Arg07 INT, @Arg14 INT;
DECLARE @jsonArg VARCHAR(MAX), @jsonMalo VARCHAR(MAX), @jsonBaja VARCHAR(MAX), @jsonOtra VARCHAR(MAX);

SELECT @Arg01 = MAX(CASE WHEN CodigoExterno = 'ARG-01' THEN IdJugador END),
       @Arg05 = MAX(CASE WHEN CodigoExterno = 'ARG-05' THEN IdJugador END),
       @Arg06 = MAX(CASE WHEN CodigoExterno = 'ARG-06' THEN IdJugador END),
       @Arg07 = MAX(CASE WHEN CodigoExterno = 'ARG-07' THEN IdJugador END),
       @Arg14 = MAX(CASE WHEN CodigoExterno = 'ARG-14' THEN IdJugador END)
FROM Torneo.Jugador;

-- Alineacion valida de Argentina (11 titulares en 4-3-3 y 6 suplentes) para las pruebas
SET @jsonArg = (
    SELECT j.IdJugador,
           CAST(CASE WHEN j.Dorsal IN (1, 4, 5, 6, 7, 11, 12, 13, 18, 19, 20) THEN 1 ELSE 0 END AS BIT) AS EsTitular,
           j.PosicionHabitual AS PosicionCancha
    FROM Torneo.Jugador j
    WHERE j.IdSeleccion = @SelArg AND j.FechaBaja IS NULL
      AND j.Dorsal IN (1, 2, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21)
    ORDER BY j.Dorsal
    FOR JSON PATH);

-- Partido temporal de octavos entre Argentina y Brasil, sin alineaciones
EXEC Torneo.usp_Partido_Alta 'PARTIDO-006', 6, 'Octavos', @SedeMetLife, '2026-07-10 20:00', @SelArg, @SelBra, NULL, NULL, @IdP6 OUTPUT;

SELECT (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos, (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 5 (incluye el temporal), 52, 7

/*------------------------------------------------------------------------------
 REGISTRAR ALINEACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: partido inexistente y sin datos ===';
-- Resultado esperado: error 50001 con 3 condiciones: el partido no existe, el esquema tactico es obligatorio y
-- la lista de jugadores debe ser un JSON valido.
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = 999, @IdSeleccion = NULL, @EsquemaTactico = '', @Jugadores = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: partido finalizado y seleccion que ya tiene alineacion ===';
-- Resultado esperado: error 50001 con 2 condiciones: solo se puede registrar la alineacion de un partido
-- Programado o En juego (el partido 3 esta Finalizado) y la seleccion ya tiene alineacion en este partido.
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP3, @IdSeleccion = @SelArg, @EsquemaTactico = '4-3-3', @Jugadores = @jsonArg;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: seleccion que no juega el partido ===';
-- Resultado esperado: error 50001 con 2 condiciones: la seleccion indicada (Estados Unidos) no juega este
-- partido y hay jugadores que no pertenecen a la seleccion indicada (la lista es de Argentina).
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP6, @IdSeleccion = @SelUsa, @EsquemaTactico = '4-3-3', @Jugadores = @jsonArg;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: esquema tactico invalido y lista que no es JSON ===';
-- Resultado esperado: error 50001 con 2 condiciones: el esquema tactico debe tener la forma 4-3-3 y sumar 10
-- jugadores de campo (4-3-4 suma 11) y la lista de jugadores debe ser un JSON valido.
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP6, @IdSeleccion = @SelArg, @EsquemaTactico = '4-3-4', @Jugadores = 'esto no es un JSON';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: lista con pocos jugadores, sin arquero, con una posicion invalida y un jugador repetido ===';
-- Resultado esperado: error 50001 con 5 condiciones: la alineacion debe tener entre 11 y 26 jugadores, debe
-- tener exactamente 11 titulares, debe haber exactamente un arquero entre los titulares, cada jugador debe
-- informar una posicion valida y hay jugadores repetidos.
SET @jsonMalo = CONCAT('[{"IdJugador":', @Arg01, ',"EsTitular":1,"PosicionCancha":"DEF"},',
                       '{"IdJugador":', @Arg01, ',"EsTitular":1,"PosicionCancha":"XXX"}]');
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP6, @IdSeleccion = @SelArg, @EsquemaTactico = '4-3-3', @Jugadores = @jsonMalo;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: jugador dado de baja ===';
-- Resultado esperado: error 50001 con 1 condicion: hay jugadores dados de baja a la fecha del partido (ARG-26,
-- de baja desde el 02/06/2026, va como suplente).
SET @jsonBaja = (
    SELECT j.IdJugador,
           CAST(CASE WHEN j.Dorsal = 26 THEN 0 ELSE 1 END AS BIT) AS EsTitular,
           j.PosicionHabitual AS PosicionCancha
    FROM Torneo.Jugador j
    WHERE j.IdSeleccion = @SelArg AND j.Dorsal IN (1, 4, 5, 6, 7, 11, 12, 13, 18, 19, 20, 26)
    FOR JSON PATH);
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP6, @IdSeleccion = @SelArg, @EsquemaTactico = '4-3-3', @Jugadores = @jsonBaja;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: jugador de otra seleccion ===';
-- Resultado esperado: error 50001 con 1 condicion: hay jugadores que no existen o no pertenecen a la seleccion
-- indicada (BRA-02 va como suplente en la lista de Argentina).
SET @jsonOtra = (
    SELECT j.IdJugador,
           CAST(CASE WHEN j.IdSeleccion = @SelArg AND j.Dorsal IN (1, 4, 5, 6, 7, 11, 12, 13, 18, 19, 20) THEN 1 ELSE 0 END AS BIT) AS EsTitular,
           j.PosicionHabitual AS PosicionCancha
    FROM Torneo.Jugador j
    WHERE (j.IdSeleccion = @SelArg AND j.Dorsal IN (1, 4, 5, 6, 7, 11, 12, 13, 18, 19, 20))
       OR j.CodigoExterno = 'BRA-02'
    FOR JSON PATH);
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP6, @IdSeleccion = @SelArg, @EsquemaTactico = '4-3-3', @Jugadores = @jsonOtra;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: registrar de nuevo la alineacion de una seleccion ===';
-- Resultado esperado: error 50001 con 1 condicion: la seleccion ya tiene alineacion registrada en este partido
-- (Argentina ya tiene la del partido 5, registrada en el script 87). No se duplica ningun jugador.
BEGIN TRY
    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP5, @IdSeleccion = @SelArg, @EsquemaTactico = '4-3-3', @Jugadores = @jsonArg;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 REGISTRAR CAMBIO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 9: cambio en un partido que no esta En juego y sin alineaciones ===';
-- Resultado esperado: error 50001 con 3 condiciones: solo se pueden registrar cambios en un partido En juego
-- (el partido temporal esta Programado) y ninguno de los dos jugadores esta en la alineacion del partido.
BEGIN TRY
    EXEC Formacion.usp_RegistrarCambio @IdPartido = @IdP6, @IdJugadorSale = @Arg07, @IdJugadorEntra = @Arg14,
         @Periodo = 'SegundoTiempo', @Minuto = 60, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: cambio entre dos titulares ===';
-- Resultado esperado: error 50001 con 1 condicion (de usp_Sustitucion_Alta): el jugador que entra debe ser
-- suplente (ARG-05 es titular).
BEGIN TRY
    EXEC Formacion.usp_RegistrarCambio @IdPartido = @IdP5, @IdJugadorSale = @Arg06, @IdJugadorEntra = @Arg05,
         @Periodo = 'SegundoTiempo', @Minuto = 70, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: reemplazar a un jugador que ya fue reemplazado ===';
-- Resultado esperado: error 50001 con 1 condicion (de usp_Sustitucion_Alta): el jugador que sale ya fue
-- reemplazado (ARG-07 salio en el script 87).
BEGIN TRY
    EXEC Formacion.usp_RegistrarCambio @IdPartido = @IdP5, @IdJugadorSale = @Arg07, @IdJugadorEntra = @Arg14,
         @Periodo = 'SegundoTiempo', @Minuto = 80, @Motivo = 'Tactico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 VERIFICAR ALINEACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 12: verificar un partido inexistente ===';
-- Resultado esperado: error 50001: "El partido indicado no existe."
BEGIN TRY
    EXEC Formacion.usp_VerificarAlineacion @IdPartido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: verificar un partido sin alineaciones ===';
-- Resultado esperado: una fila por seleccion (Argentina y Brasil) con 0 titulares, 0 suplentes, 0 cambios y
-- estado INCOMPLETA (el partido temporal todavia no tiene alineaciones).
EXEC Formacion.usp_VerificarAlineacion @IdPartido = @IdP6;

-- Se elimina el partido temporal
EXEC Torneo.usp_Partido_Baja @IdPartido = @IdP6;

SELECT (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos, (SELECT COUNT(*) FROM Formacion.Alineacion) AS Alineaciones,
       (SELECT COUNT(*) FROM Formacion.Sustitucion) AS Sustituciones;     -- esperado: 4, 52, 7 (las pruebas no cambiaron nada)
GO
