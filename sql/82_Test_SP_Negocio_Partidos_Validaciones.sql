/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 82_Test_SP_Negocio_Partidos_Validaciones.sql
 Objetivo     : Testing de las validaciones de 80_SP_Negocio_Partidos.sql (relacion 1:1).
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero
                de error y el mensaje unico que agrupa todas las condiciones que no
                se cumplen. La prueba 4 comprueba que la operacion es "todo o nada".
 Requisito    : ejecutar despues de 81_Test_SP_Negocio_Partidos_OK.sql. Estado de los
                partidos: 1 Programado (sin selecciones), 3 Finalizado, 4 Programado
                (Francia-Mexico, sin convocados) y 5 En juego (octavos Argentina-Brasil).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @IdP1 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-001');
DECLARE @IdP3 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-003');
DECLARE @IdP4 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-004');
DECLARE @IdP5 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-005');

SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 3, 4

/*------------------------------------------------------------------------------
 REGISTRAR PARTIDO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: sede inexistente sin los datos para crearla ===';
-- Resultado esperado: error 50001: "La sede no existe: para crearla hay que informar nombre del estadio, ciudad,
-- pais, huso horario y capacidad."
BEGIN TRY
    EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-006', @NumeroPartido = 6, @Fase = 'Octavos',
         @FechaHoraUtc = '2026-07-07 22:00', @CodigoExternoSede = 'SEDE-FANTASMA';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: sin codigo de sede ===';
-- Resultado esperado: error 50001: "El codigo externo de la sede es obligatorio."
BEGIN TRY
    EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-006', @NumeroPartido = 6, @Fase = 'Octavos',
         @FechaHoraUtc = '2026-07-07 22:00', @CodigoExternoSede = '';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: sede nueva con datos invalidos ===';
-- Resultado esperado: error 50001 con las condiciones de usp_Sede_Alta: huso horario invalido y capacidad mayor
-- a cero. No se crea ni la sede ni el partido.
BEGIN TRY
    EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-006', @NumeroPartido = 6, @Fase = 'Octavos',
         @FechaHoraUtc = '2026-07-07 22:00', @CodigoExternoSede = 'SEDE-NUEVA', @NombreEstadio = 'Estadio Nuevo',
         @Ciudad = 'Miami', @IdPaisSede = @PaisUsa, @HusoHorarioSede = 'Zona Inventada', @CapacidadSede = 0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 3, 4

PRINT '=== Prueba 4: sede nueva valida pero partido invalido (todo o nada) ===';
-- Resultado esperado: error 50001 de usp_Partido_Alta: ya existe un partido con ese codigo externo y con ese
-- numero. Como el partido no se pudo crear, la transaccion se deshace y la sede SEDE-NUEVA2 TAMPOCO queda
-- creada: siguen siendo 3 sedes y 4 partidos, y la consulta por la sede nueva devuelve 0 filas.
BEGIN TRY
    EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-001', @NumeroPartido = 1, @Fase = 'Octavos',
         @FechaHoraUtc = '2026-07-08 22:00', @CodigoExternoSede = 'SEDE-NUEVA2', @NombreEstadio = 'Estadio Nuevo Dos',
         @Ciudad = 'Miami', @IdPaisSede = @PaisUsa, @HusoHorarioSede = 'Eastern Standard Time', @CapacidadSede = 60000;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 3, 4
SELECT COUNT(*) AS SedeNueva2 FROM Torneo.Sede WHERE CodigoExterno = 'SEDE-NUEVA2';                      -- esperado: 0

/*------------------------------------------------------------------------------
 INICIAR PARTIDO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 5: iniciar un partido inexistente ===';
-- Resultado esperado: error 50001: "El partido indicado no existe."
BEGIN TRY
    EXEC Torneo.usp_IniciarPartido @IdPartido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: iniciar un partido que ya finalizo ===';
-- Resultado esperado: error 50001: "Solo se puede iniciar un partido en estado Programado." (el partido 3 esta
-- Finalizado).
BEGIN TRY
    EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP3;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: iniciar un partido sin selecciones definidas ===';
-- Resultado esperado: error 50001: "El partido necesita las dos selecciones definidas para empezar." (partido 1).
BEGIN TRY
    EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: iniciar un partido con selecciones sin convocatoria completa ===';
-- Resultado esperado: error 50001 con 2 condiciones: la seleccion local y la visitante tienen menos de 23
-- convocados (Francia y Mexico no tienen jugadores cargados).
BEGIN TRY
    EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP4;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 FINALIZAR PARTIDO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 9: finalizar un partido que no esta en juego ===';
-- Resultado esperado: error 50001: "Solo se puede finalizar un partido en estado En juego." (partido 4).
BEGIN TRY
    EXEC Torneo.usp_FinalizarPartido @IdPartido = @IdP4, @Asistencia = 1000;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: asistencia mayor a la capacidad y empate sin penales en una fase eliminatoria ===';
-- Resultado esperado: error 50001 con 2 condiciones: la asistencia no puede superar la capacidad del estadio
-- (87523, el Azteca) y en una fase eliminatoria el partido no puede terminar empatado sin definicion por
-- penales. El partido 5 sigue En juego.
BEGIN TRY
    EXEC Torneo.usp_FinalizarPartido @IdPartido = @IdP5, @Asistencia = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT IdPartido, Fase, Estado FROM Torneo.Partido WHERE IdPartido = @IdP5;     -- esperado: En juego

PRINT '=== Prueba 11: finalizar un partido inexistente y sin asistencia ===';
-- Resultado esperado: error 50001: "El partido indicado no existe." (la asistencia no se evalua si el partido
-- no existe).
BEGIN TRY
    EXEC Torneo.usp_FinalizarPartido @IdPartido = 999, @Asistencia = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 SUSPENDER Y REPROGRAMAR
------------------------------------------------------------------------------*/
PRINT '=== Prueba 12: suspender un partido finalizado ===';
-- Resultado esperado: error 50001: "Solo se puede suspender un partido Programado o En juego." (partido 3).
BEGIN TRY
    EXEC Torneo.usp_SuspenderPartido @IdPartido = @IdP3;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: reprogramar un partido que no esta suspendido y sin fecha ===';
-- Resultado esperado: error 50001 con 2 condiciones: solo se puede reprogramar un partido Suspendido (el 4 esta
-- Programado) y la nueva fecha y hora UTC son obligatorias.
BEGIN TRY
    EXEC Torneo.usp_ReprogramarPartido @IdPartido = @IdP4, @FechaHoraUtc = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes, (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;   -- esperado: 3, 4
GO
