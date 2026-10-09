/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 21_Test_SP_ABM_Seleccion_OK.sql
 Objetivo     : Testing exitoso de 20_SP_ABM_Seleccion.sql (relacion 1:1): Seleccion, Jugador y
                CuerpoTecnico, y partidos con selecciones. Muestra los datos antes y despues.
 Requisito    : ejecutar despues de 11_Test_SP_ABM_Torneo_OK.sql (usa sus paises y sedes), una sola vez.
                Los datos se cargan unicamente con los SP.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisArg INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ARG');
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @PaisMex INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'MEX');
DECLARE @PaisBra INT, @PaisFra INT, @PaisTemporal INT;
DECLARE @SelArg INT, @SelBra INT, @SelFra INT, @SelMex INT, @SelUsa INT, @SelTemporal INT;
DECLARE @IdJugadorTemporal INT, @IdDt INT, @IdAyudante INT, @IdPartido INT;
DECLARE @SedeMetLife INT = (SELECT IdSede FROM Torneo.Sede WHERE CodigoExterno = 'SEDE-METLIFE');

/*------------------------------------------------------------------------------
 SELECCION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta de selecciones ===';
-- Resultado esperado: se crean los paises Brasil y Francia y 5 selecciones: Argentina, Brasil, Francia y
-- Mexico en el grupo C (4 selecciones, el maximo del grupo) y Estados Unidos en el grupo D.
EXEC Torneo.usp_Pais_Alta 'BRA', 'Brasil', 'CONMEBOL', 'E. South America Standard Time', NULL, NULL, @PaisBra OUTPUT;
EXEC Torneo.usp_Pais_Alta 'FRA', 'Francia', 'UEFA', 'Central Europe Standard Time', NULL, NULL, @PaisFra OUTPUT;
EXEC Torneo.usp_Seleccion_Alta 'SEL-ARG', @PaisArg, 'C', @SelArg OUTPUT;
EXEC Torneo.usp_Seleccion_Alta 'SEL-BRA', @PaisBra, 'c', @SelBra OUTPUT;      -- la letra minuscula se guarda en mayuscula
EXEC Torneo.usp_Seleccion_Alta 'SEL-FRA', @PaisFra, 'C', @SelFra OUTPUT;
EXEC Torneo.usp_Seleccion_Alta 'SEL-MEX', @PaisMex, 'C', @SelMex OUTPUT;
EXEC Torneo.usp_Seleccion_Alta 'SEL-USA', @PaisUsa, 'D', @SelUsa OUTPUT;
SELECT s.IdSeleccion, s.CodigoExterno, p.Nombre AS Pais, s.Grupo FROM Torneo.Seleccion s JOIN Torneo.Pais p ON p.IdPais = s.IdPais ORDER BY s.IdSeleccion;

PRINT '=== Prueba 2: modificacion de una seleccion ===';
-- Resultado esperado: Estados Unidos pasa del grupo D al grupo E.
EXEC Torneo.usp_Seleccion_Modificacion @IdSeleccion = @SelUsa, @CodigoExterno = 'SEL-USA', @IdPais = @PaisUsa, @Grupo = 'E';
SELECT IdSeleccion, CodigoExterno, Grupo FROM Torneo.Seleccion WHERE IdSeleccion = @SelUsa;

PRINT '=== Prueba 3: baja de una seleccion sin datos asociados ===';
-- Resultado esperado: se crea el pais Chile con su seleccion (grupo F) y se elimina la seleccion y luego el
-- pais; la cantidad de selecciones vuelve a 5.
EXEC Torneo.usp_Pais_Alta 'CHL', 'Chile', 'CONMEBOL', 'Pacific SA Standard Time', NULL, NULL, @PaisTemporal OUTPUT;
EXEC Torneo.usp_Seleccion_Alta 'SEL-CHL', @PaisTemporal, 'F', @SelTemporal OUTPUT;
SELECT COUNT(*) AS SeleccionesConChile FROM Torneo.Seleccion;
EXEC Torneo.usp_Seleccion_Baja @IdSeleccion = @SelTemporal;
EXEC Torneo.usp_Pais_Baja @IdPais = @PaisTemporal;
SELECT COUNT(*) AS SeleccionesSinChile FROM Torneo.Seleccion;

/*------------------------------------------------------------------------------
 JUGADOR (convocatoria)
 Orden de los parametros: codigo externo, nombre, apellido, pais, seleccion,
 dorsal, posicion, club, fecha de alta.
------------------------------------------------------------------------------*/
PRINT '=== Prueba 4: alta de la convocatoria ===';
-- Resultado esperado: Argentina queda con 26 convocados (el maximo) y Brasil con 23 (el minimo).
EXEC Torneo.usp_Jugador_Alta 'ARG-01', 'Jugador', 'Argentina 01', @PaisArg, @SelArg, 1, 'POR', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-02', 'Jugador', 'Argentina 02', @PaisArg, @SelArg, 2, 'POR', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-03', 'Jugador', 'Argentina 03', @PaisArg, @SelArg, 3, 'POR', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-04', 'Jugador', 'Argentina 04', @PaisArg, @SelArg, 4, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-05', 'Jugador', 'Argentina 05', @PaisArg, @SelArg, 5, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-06', 'Jugador', 'Argentina 06', @PaisArg, @SelArg, 6, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-07', 'Jugador', 'Argentina 07', @PaisArg, @SelArg, 7, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-08', 'Jugador', 'Argentina 08', @PaisArg, @SelArg, 8, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-09', 'Jugador', 'Argentina 09', @PaisArg, @SelArg, 9, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-10', 'Jugador', 'Argentina 10', @PaisArg, @SelArg, 10, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-11', 'Jugador', 'Argentina 11', @PaisArg, @SelArg, 11, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-12', 'Jugador', 'Argentina 12', @PaisArg, @SelArg, 12, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-13', 'Jugador', 'Argentina 13', @PaisArg, @SelArg, 13, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-14', 'Jugador', 'Argentina 14', @PaisArg, @SelArg, 14, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-15', 'Jugador', 'Argentina 15', @PaisArg, @SelArg, 15, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-16', 'Jugador', 'Argentina 16', @PaisArg, @SelArg, 16, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-17', 'Jugador', 'Argentina 17', @PaisArg, @SelArg, 17, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-18', 'Jugador', 'Argentina 18', @PaisArg, @SelArg, 18, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-19', 'Jugador', 'Argentina 19', @PaisArg, @SelArg, 19, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-20', 'Jugador', 'Argentina 20', @PaisArg, @SelArg, 20, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-21', 'Jugador', 'Argentina 21', @PaisArg, @SelArg, 21, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-22', 'Jugador', 'Argentina 22', @PaisArg, @SelArg, 22, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-23', 'Jugador', 'Argentina 23', @PaisArg, @SelArg, 23, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-24', 'Jugador', 'Argentina 24', @PaisArg, @SelArg, 24, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-25', 'Jugador', 'Argentina 25', @PaisArg, @SelArg, 25, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'ARG-26', 'Jugador', 'Argentina 26', @PaisArg, @SelArg, 26, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-01', 'Jugador', 'Brasil 01', @PaisBra, @SelBra, 1, 'POR', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-02', 'Jugador', 'Brasil 02', @PaisBra, @SelBra, 2, 'POR', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-03', 'Jugador', 'Brasil 03', @PaisBra, @SelBra, 3, 'POR', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-04', 'Jugador', 'Brasil 04', @PaisBra, @SelBra, 4, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-05', 'Jugador', 'Brasil 05', @PaisBra, @SelBra, 5, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-06', 'Jugador', 'Brasil 06', @PaisBra, @SelBra, 6, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-07', 'Jugador', 'Brasil 07', @PaisBra, @SelBra, 7, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-08', 'Jugador', 'Brasil 08', @PaisBra, @SelBra, 8, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-09', 'Jugador', 'Brasil 09', @PaisBra, @SelBra, 9, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-10', 'Jugador', 'Brasil 10', @PaisBra, @SelBra, 10, 'DEF', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-11', 'Jugador', 'Brasil 11', @PaisBra, @SelBra, 11, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-12', 'Jugador', 'Brasil 12', @PaisBra, @SelBra, 12, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-13', 'Jugador', 'Brasil 13', @PaisBra, @SelBra, 13, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-14', 'Jugador', 'Brasil 14', @PaisBra, @SelBra, 14, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-15', 'Jugador', 'Brasil 15', @PaisBra, @SelBra, 15, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-16', 'Jugador', 'Brasil 16', @PaisBra, @SelBra, 16, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-17', 'Jugador', 'Brasil 17', @PaisBra, @SelBra, 17, 'MED', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-18', 'Jugador', 'Brasil 18', @PaisBra, @SelBra, 18, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-19', 'Jugador', 'Brasil 19', @PaisBra, @SelBra, 19, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-20', 'Jugador', 'Brasil 20', @PaisBra, @SelBra, 20, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-21', 'Jugador', 'Brasil 21', @PaisBra, @SelBra, 21, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-22', 'Jugador', 'Brasil 22', @PaisBra, @SelBra, 22, 'DEL', 'Club Demo', '2026-05-20';
EXEC Torneo.usp_Jugador_Alta 'BRA-23', 'Jugador', 'Brasil 23', @PaisBra, @SelBra, 23, 'DEL', 'Club Demo', '2026-05-20';
SELECT s.CodigoExterno AS Seleccion, COUNT(*) AS Convocados,
       SUM(CASE WHEN j.PosicionHabitual = 'POR' THEN 1 ELSE 0 END) AS Porteros
FROM Torneo.Jugador j JOIN Torneo.Seleccion s ON s.IdSeleccion = j.IdSeleccion
WHERE j.FechaBaja IS NULL GROUP BY s.CodigoExterno ORDER BY s.CodigoExterno;

PRINT '=== Prueba 5: modificacion de un jugador ===';
-- Resultado esperado: el jugador ARG-10 cambia de nombre (Lionel Messi), de club (Inter Miami) y se le carga
-- la fecha de nacimiento. El resto no cambia.
DECLARE @IdJ10 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-10');
SELECT IdJugador, Nombre, Apellido, Dorsal, ClubOrigen, FechaNacimiento FROM Torneo.Jugador WHERE IdJugador = @IdJ10;
EXEC Torneo.usp_Jugador_Modificacion @IdJugador = @IdJ10, @CodigoExterno = 'ARG-10', @Nombre = 'Lionel', @Apellido = 'Messi',
     @IdPais = @PaisArg, @IdSeleccion = @SelArg, @Dorsal = 10, @PosicionHabitual = 'DEL', @ClubOrigen = 'Inter Miami',
     @FechaAlta = '2026-05-20', @FechaNacimiento = '1987-06-24';
SELECT IdJugador, Nombre, Apellido, Dorsal, ClubOrigen, FechaNacimiento FROM Torneo.Jugador WHERE IdJugador = @IdJ10;

PRINT '=== Prueba 6: baja de un jugador ===';
-- Resultado esperado: se agrega un jugador temporal a Brasil (24 convocados) y se elimina; vuelve a 23.
EXEC Torneo.usp_Jugador_Alta 'BRA-99', 'Jugador', 'Temporal', @PaisBra, @SelBra, 99, 'DEL', 'Club Demo', '2026-05-21', NULL, @IdJugadorTemporal OUTPUT;
SELECT COUNT(*) AS BrasilConTemporal FROM Torneo.Jugador WHERE IdSeleccion = @SelBra;
EXEC Torneo.usp_Jugador_Baja @IdJugador = @IdJugadorTemporal;
SELECT COUNT(*) AS BrasilSinTemporal FROM Torneo.Jugador WHERE IdSeleccion = @SelBra;

/*------------------------------------------------------------------------------
 CUERPO TECNICO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 7: alta, modificacion y baja del cuerpo tecnico ===';
-- Resultado esperado: Argentina tiene un director tecnico y un ayudante; el ayudante cambia de apellido y
-- luego se elimina; queda solo el director tecnico.
EXEC Torneo.usp_CuerpoTecnico_Alta @SelArg, 'Lionel', 'Scaloni', 'Director tecnico', @IdDt OUTPUT;
EXEC Torneo.usp_CuerpoTecnico_Alta @SelArg, 'Walter', 'Samuel', 'Ayudante', @IdAyudante OUTPUT;
SELECT IdCuerpoTecnico, IdSeleccion, Nombre, Apellido, Rol FROM Torneo.CuerpoTecnico ORDER BY IdCuerpoTecnico;
EXEC Torneo.usp_CuerpoTecnico_Modificacion @IdCuerpoTecnico = @IdAyudante, @IdSeleccion = @SelArg, @Nombre = 'Walter', @Apellido = 'Samuel Gomez', @Rol = 'Ayudante';
SELECT IdCuerpoTecnico, Apellido, Rol FROM Torneo.CuerpoTecnico WHERE IdCuerpoTecnico = @IdAyudante;
EXEC Torneo.usp_CuerpoTecnico_Baja @IdCuerpoTecnico = @IdAyudante;
SELECT COUNT(*) AS IntegrantesDespues FROM Torneo.CuerpoTecnico;

/*------------------------------------------------------------------------------
 PARTIDO CON SELECCIONES (completa las pruebas de 11_Test_SP_ABM_Torneo_OK.sql)
------------------------------------------------------------------------------*/
PRINT '=== Prueba 8: partido de fase de grupos con selecciones ===';
-- Resultado esperado: se inserta el partido 3 (Argentina contra Brasil, grupo C) en el Estadio MetLife a las
-- 20:00 UTC (16:00 locales); luego se le cargan los esquemas tacticos con la modificacion.
EXEC Torneo.usp_Partido_Alta 'PARTIDO-003', 3, 'Grupos', @SedeMetLife, '2026-06-12 20:00', @SelArg, @SelBra, NULL, NULL, @IdPartido OUTPUT;
EXEC Torneo.usp_Partido_Modificacion @IdPartido = @IdPartido, @CodigoExterno = 'PARTIDO-003', @NumeroPartido = 3, @Fase = 'Grupos',
     @IdSede = @SedeMetLife, @FechaHoraUtc = '2026-06-12 20:00', @IdSeleccionLocal = @SelArg, @IdSeleccionVisitante = @SelBra,
     @EsquemaTacticoLocal = '4-3-3', @EsquemaTacticoVisitante = '4-4-2';
SELECT IdPartido, NumeroPartido, Fase, IdSeleccionLocal, IdSeleccionVisitante, EsquemaTacticoLocal, EsquemaTacticoVisitante,
       FechaHoraUtc, FechaHoraLocal, Estado
FROM Torneo.Partido WHERE IdPartido = @IdPartido;
GO
