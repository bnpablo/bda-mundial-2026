/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 22_Test_SP_ABM_Seleccion_Validaciones.sql
 Objetivo     : Testing de las validaciones de 20_SP_ABM_Seleccion.sql (relacion 1:1). Cada caso
                invalido se ejecuta dentro de TRY/CATCH: muestra el numero de error y el
                mensaje unico que agrupa todas las condiciones que no se cumplen, y no
                modifica ningun dato.
 Requisito    : ejecutar despues de 21_Test_SP_ABM_Seleccion_OK.sql, que deja cargadas 5 selecciones,
                49 jugadores (Argentina 26 y Brasil 23), el director tecnico de Argentina y el partido 3.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.Jugador) AS Jugadores,
       (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico;     -- esperado: 5, 49, 1

DECLARE @PaisArg INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ARG');
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @IdJ10 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-10');

PRINT '=== Prueba 1: seleccion con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: codigo externo obligatorio, pais inexistente y grupo
-- que no esta entre la A y la L.
BEGIN TRY
    EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = '', @IdPais = 999, @Grupo = 'Z';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: pais que ya tiene seleccion, codigo repetido y grupo completo ===';
-- Resultado esperado: error 50001 con 3 condiciones: ya existe una seleccion con ese codigo externo, el pais ya
-- tiene una seleccion registrada y el grupo C ya tiene el maximo de 4 selecciones.
BEGIN TRY
    EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = 'SEL-ARG', @IdPais = @PaisArg, @Grupo = 'C';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: modificar una seleccion inexistente ===';
-- Resultado esperado: error 50001 con 2 condiciones: la seleccion indicada no existe y el pais (Estados Unidos)
-- ya tiene otra seleccion registrada.
BEGIN TRY
    EXEC Torneo.usp_Seleccion_Modificacion @IdSeleccion = 999, @CodigoExterno = 'SEL-NUEVA', @IdPais = @PaisUsa, @Grupo = 'G';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: baja de una seleccion con jugadores, cuerpo tecnico y partidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: la seleccion tiene jugadores, cuerpo tecnico y partidos
-- registrados. La seleccion no se elimina.
BEGIN TRY
    EXEC Torneo.usp_Seleccion_Baja @IdSeleccion = @SelArg;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: jugador con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 10 condiciones: codigo externo obligatorio, nombre obligatorio, apellido
-- obligatorio, fecha de nacimiento futura, pais inexistente, seleccion inexistente, dorsal fuera de 1 a 99,
-- posicion invalida, club obligatorio y fecha de alta obligatoria.
BEGIN TRY
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = '', @Nombre = '', @Apellido = '', @IdPais = 999, @IdSeleccion = 999,
         @Dorsal = 100, @PosicionHabitual = 'XXX', @ClubOrigen = '', @FechaAlta = NULL, @FechaNacimiento = '2999-01-01';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: jugador con codigo y dorsal repetidos, en una seleccion con el maximo de convocados ===';
-- Resultado esperado: error 50001 con 3 condiciones: ya existe un jugador con ese codigo externo, ese dorsal ya fue
-- asignado en la seleccion y la seleccion ya tiene el maximo de 26 convocados (Argentina tiene 26).
BEGIN TRY
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = 'ARG-01', @Nombre = 'Jugador', @Apellido = 'Repetido', @IdPais = @PaisArg,
         @IdSeleccion = @SelArg, @Dorsal = 1, @PosicionHabitual = 'POR', @ClubOrigen = 'Club Demo', @FechaAlta = '2026-05-22';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: modificar un jugador cambiandole la seleccion ===';
-- Resultado esperado: error 50001 con 1 condicion: no se puede cambiar la seleccion de un jugador.
BEGIN TRY
    EXEC Torneo.usp_Jugador_Modificacion @IdJugador = @IdJ10,
         @CodigoExterno = 'ARG-10', @Nombre = 'Lionel', @Apellido = 'Messi', @IdPais = @PaisArg, @IdSeleccion = @SelBra,
         @Dorsal = 10, @PosicionHabitual = 'DEL', @ClubOrigen = 'Inter Miami', @FechaAlta = '2026-05-20';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: modificar un jugador con un dorsal que ya tiene otro de su seleccion ===';
-- Resultado esperado: error 50001 con 1 condicion: ese dorsal ya fue asignado en la seleccion (el dorsal 9 es de
-- ARG-09).
BEGIN TRY
    EXEC Torneo.usp_Jugador_Modificacion @IdJugador = @IdJ10,
         @CodigoExterno = 'ARG-10', @Nombre = 'Lionel', @Apellido = 'Messi', @IdPais = @PaisArg, @IdSeleccion = @SelArg,
         @Dorsal = 9, @PosicionHabitual = 'DEL', @ClubOrigen = 'Inter Miami', @FechaAlta = '2026-05-20';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: baja de un jugador inexistente ===';
-- Resultado esperado: error 50001: "El jugador indicado no existe."
BEGIN TRY
    EXEC Torneo.usp_Jugador_Baja @IdJugador = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: segundo director tecnico en una seleccion ===';
-- Resultado esperado: error 50001: "La seleccion ya tiene un director tecnico." (Argentina ya tiene a Scaloni).
BEGIN TRY
    EXEC Torneo.usp_CuerpoTecnico_Alta @IdSeleccion = @SelArg, @Nombre = 'Otro', @Apellido = 'Director', @Rol = 'Director tecnico';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: rol invalido ===';
-- Resultado esperado: error 50001: "El rol debe ser Director tecnico o Ayudante."
BEGIN TRY
    EXEC Torneo.usp_CuerpoTecnico_Alta @IdSeleccion = @SelArg, @Nombre = 'Otro', @Apellido = 'Preparador', @Rol = 'Utilero';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 12: cuerpo tecnico sin seleccion, sin nombre ni rol ===';
-- Resultado esperado: error 50001 con 4 condiciones: seleccion inexistente, nombre obligatorio, apellido
-- obligatorio y rol invalido.
BEGIN TRY
    EXEC Torneo.usp_CuerpoTecnico_Alta @IdSeleccion = 999, @Nombre = '', @Apellido = NULL, @Rol = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: modificar un integrante inexistente ===';
-- Resultado esperado: error 50001: "El integrante del cuerpo tecnico indicado no existe."
BEGIN TRY
    EXEC Torneo.usp_CuerpoTecnico_Modificacion @IdCuerpoTecnico = 999, @IdSeleccion = @SelArg, @Nombre = 'A', @Apellido = 'B', @Rol = 'Ayudante';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 14: eliminar un integrante inexistente ===';
-- Resultado esperado: error 50001: "El integrante del cuerpo tecnico indicado no existe."
BEGIN TRY
    EXEC Torneo.usp_CuerpoTecnico_Baja @IdCuerpoTecnico = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.Jugador) AS Jugadores,
       (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico;     -- esperado: 5, 49, 1 (las pruebas no cambiaron nada)
GO
