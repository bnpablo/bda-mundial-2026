/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 12_Test_SP_ABM_Torneo_Validaciones.sql
 Objetivo     : Testing de las validaciones de 10_SP_ABM_Torneo.sql (relacion 1:1).
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el
                numero de error y el mensaje unico que agrupa todas las condiciones
                que no se cumplen, y no modifica ningun dato.
 Requisito    : ejecutar despues de 11_Test_SP_ABM_Torneo_OK.sql, que deja cargados
                3 paises (Argentina, Estados Unidos y Mexico), 2 sedes y 1 partido.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

SELECT (SELECT COUNT(*) FROM Torneo.Pais) AS Paises, (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes,
       (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;     -- esperado: 3, 2, 1

/*------------------------------------------------------------------------------
 PAIS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: pais con varios datos invalidos a la vez ===';
-- Resultado esperado: error 50001 con UN solo mensaje que junta 6 condiciones: codigo ISO de 3 letras,
-- nombre obligatorio, confederacion invalida, huso horario invalido, PIB negativo y anio del PIB.
BEGIN TRY
    EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'AR1', @Nombre = '', @Confederacion = 'MARTE',
         @HusoHorario = 'Zona Inventada', @PibPerCapitaUsd = -5, @AnioPib = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: pais con codigo y nombre repetidos ===';
-- Resultado esperado: error 50001 con 2 condiciones: ya existe un pais con ese codigo ISO y con ese nombre.
BEGIN TRY
    EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'ARG', @Nombre = 'Argentina', @Confederacion = 'CONMEBOL',
         @HusoHorario = 'Argentina Standard Time';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: modificar un pais inexistente y con nombre ya usado ===';
-- Resultado esperado: error 50001 con 2 condiciones: el pais indicado no existe y ya existe otro pais
-- con ese nombre.
BEGIN TRY
    EXEC Torneo.usp_Pais_Modificacion @IdPais = 999, @CodigoIso3 = 'ZZZ', @Nombre = 'Argentina',
         @Confederacion = 'CONMEBOL', @HusoHorario = 'Argentina Standard Time';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: baja de un pais con sedes ===';
-- Resultado esperado: error 50001: "El pais tiene sedes registradas." (Estados Unidos tiene el MetLife).
-- El pais no se elimina.
BEGIN TRY
    EXEC Torneo.usp_Pais_Baja @IdPais = 2;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT COUNT(*) AS Paises FROM Torneo.Pais;     -- esperado: 3

PRINT '=== Prueba 5: baja de un pais inexistente ===';
-- Resultado esperado: error 50001: "El pais indicado no existe."
BEGIN TRY
    EXEC Torneo.usp_Pais_Baja @IdPais = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 SEDE
------------------------------------------------------------------------------*/
PRINT '=== Prueba 6: sede con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 6 condiciones: codigo externo obligatorio, nombre del estadio
-- obligatorio, ciudad obligatoria, pais inexistente, huso horario invalido y capacidad mayor a cero.
BEGIN TRY
    EXEC Torneo.usp_Sede_Alta @CodigoExterno = NULL, @NombreEstadio = '', @Ciudad = '', @IdPais = 999,
         @HusoHorario = 'Zona Inventada', @Capacidad = 0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: sede con codigo y nombre repetidos ===';
-- Resultado esperado: error 50001 con 2 condiciones: ya existe una sede con ese codigo externo y con ese
-- nombre de estadio.
BEGIN TRY
    EXEC Torneo.usp_Sede_Alta @CodigoExterno = 'SEDE-AZTECA', @NombreEstadio = 'Estadio Azteca', @Ciudad = 'Ciudad de Mexico',
         @IdPais = 3, @HusoHorario = 'Central Standard Time (Mexico)', @Capacidad = 80000;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: cambiar el huso horario de una sede que ya tiene partidos ===';
-- Resultado esperado: error 50001: "No se puede cambiar el huso horario de una sede que ya tiene partidos."
-- (el Estadio Azteca tiene el partido 1).
BEGIN TRY
    EXEC Torneo.usp_Sede_Modificacion @IdSede = 2, @CodigoExterno = 'SEDE-AZTECA', @NombreEstadio = 'Estadio Azteca',
         @Ciudad = 'Ciudad de Mexico', @IdPais = 3, @HusoHorario = 'Eastern Standard Time', @Capacidad = 87523;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: baja de una sede con partidos ===';
-- Resultado esperado: error 50001: "La sede tiene partidos registrados." La sede no se elimina.
BEGIN TRY
    EXEC Torneo.usp_Sede_Baja @IdSede = 2;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT COUNT(*) AS Sedes FROM Torneo.Sede;     -- esperado: 2

/*------------------------------------------------------------------------------
 PARTIDO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 10: partido con varios datos invalidos a la vez ===';
-- Resultado esperado: error 50001 con 7 condiciones: codigo externo obligatorio, numero de partido mayor a
-- cero, fase invalida, sede inexistente, seleccion local inexistente, seleccion visitante inexistente y
-- fecha y hora UTC obligatoria.
BEGIN TRY
    EXEC Torneo.usp_Partido_Alta @CodigoExterno = '', @NumeroPartido = 0, @Fase = 'Mundial', @IdSede = 999,
         @FechaHoraUtc = NULL, @IdSeleccionLocal = 999, @IdSeleccionVisitante = 998;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: fase de grupos sin selecciones y partido muy cerca de otro en la misma sede ===';
-- Resultado esperado: error 50001 con 2 condiciones: en la fase de grupos deben estar definidas las dos
-- selecciones, y ya hay otro partido en esa sede con menos de 180 minutos de diferencia (el partido 1 es a
-- las 22:00 UTC en el Azteca y este seria a las 23:00).
BEGIN TRY
    EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'PARTIDO-003', @NumeroPartido = 3, @Fase = 'Grupos', @IdSede = 2,
         @FechaHoraUtc = '2026-07-04 23:00';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 12: partido con codigo y numero repetidos ===';
-- Resultado esperado: error 50001 con 2 condiciones: ya existe un partido con ese codigo externo y con ese
-- numero.
BEGIN TRY
    EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'PARTIDO-001', @NumeroPartido = 1, @Fase = 'Octavos', @IdSede = 1,
         @FechaHoraUtc = '2026-07-10 20:00';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: modificar y eliminar un partido inexistente ===';
-- Resultado esperado: dos errores 50001: "El partido indicado no existe." (uno por cada SP).
BEGIN TRY
    EXEC Torneo.usp_Partido_Modificacion @IdPartido = 999, @CodigoExterno = 'PARTIDO-009', @NumeroPartido = 9,
         @Fase = 'Octavos', @IdSede = 1, @FechaHoraUtc = '2026-07-12 20:00';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    EXEC Torneo.usp_Partido_Baja @IdPartido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Torneo.Pais) AS Paises, (SELECT COUNT(*) FROM Torneo.Sede) AS Sedes,
       (SELECT COUNT(*) FROM Torneo.Partido) AS Partidos;     -- esperado: 3, 2, 1 (las pruebas no cambiaron nada)
GO
