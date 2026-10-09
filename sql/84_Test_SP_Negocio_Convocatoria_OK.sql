/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 84_Test_SP_Negocio_Convocatoria_OK.sql
 Objetivo     : Testing exitoso de 83_SP_Negocio_Convocatoria.sql (relacion 1:1):
                registrar una seleccion con su director tecnico, una baja de ultimo
                momento con reemplazo y una baja sin reemplazo.
 Requisito    : ejecutar despues de 82_Test_SP_Negocio_Partidos_Validaciones.sql (usa las
                selecciones de Argentina, con 26 convocados, y de Brasil, con 23).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisBra INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'BRA');
DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @PaisEsp INT, @IdSelEsp INT, @IdDirector INT, @IdReemplazo INT;
DECLARE @IdBaja INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'BRA-05');
DECLARE @IdBajaSinReemplazo INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-26');

SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico,
       (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @SelArg AND FechaBaja IS NULL) AS ConvocadosArgentina,
       (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @SelBra AND FechaBaja IS NULL) AS ConvocadosBrasil;   -- esperado: 5, 1, 26, 23

PRINT '=== Prueba 1: registrar una seleccion con su director tecnico ===';
-- Resultado esperado: en una sola operacion se crean la seleccion de Espana (grupo F) y su director tecnico Luis
-- de la Fuente. Hay 6 selecciones y 2 integrantes del cuerpo tecnico.
EXEC Torneo.usp_Pais_Alta 'ESP', 'Espana', 'UEFA', 'Central Europe Standard Time', NULL, NULL, @PaisEsp OUTPUT;
EXEC Torneo.usp_RegistrarSeleccion @CodigoExterno = 'SEL-ESP', @IdPais = @PaisEsp, @Grupo = 'F',
     @NombreDirector = 'Luis', @ApellidoDirector = 'de la Fuente', @IdSeleccion = @IdSelEsp OUTPUT, @IdDirector = @IdDirector OUTPUT;
SELECT s.IdSeleccion, s.CodigoExterno, s.Grupo, c.Nombre, c.Apellido, c.Rol
FROM Torneo.Seleccion s JOIN Torneo.CuerpoTecnico c ON c.IdSeleccion = s.IdSeleccion WHERE s.IdSeleccion = @IdSelEsp;
SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico;   -- esperado: 6, 2

PRINT '=== Prueba 2: baja de ultimo momento con reemplazo ===';
-- Resultado esperado: el defensor BRA-05 queda dado de baja por lesion el 01/06 y su reemplazo BRA-24 (defensor,
-- dorsal 24) se da de alta ese mismo dia en Brasil. La baja queda enlazada con el reemplazo (IdJugadorReemplazo).
-- Brasil sigue teniendo 23 convocados activos.
SELECT IdJugador, CodigoExterno, Dorsal, FechaBaja, MotivoBaja, IdJugadorReemplazo FROM Torneo.Jugador WHERE IdJugador = @IdBaja;
EXEC Torneo.usp_RegistrarBajaYReemplazo @IdJugadorBaja = @IdBaja, @MotivoBaja = 'Lesion', @FechaBaja = '2026-06-01',
     @CodigoExternoReemplazo = 'BRA-24', @NombreReemplazo = 'Jugador', @ApellidoReemplazo = 'Reemplazo Brasil',
     @IdPaisReemplazo = @PaisBra, @DorsalReemplazo = 24, @PosicionReemplazo = 'DEF', @ClubReemplazo = 'Club Demo',
     @IdJugadorReemplazo = @IdReemplazo OUTPUT;
SELECT IdJugador, CodigoExterno, Dorsal, FechaAlta, FechaBaja, MotivoBaja, IdJugadorReemplazo
FROM Torneo.Jugador WHERE IdJugador IN (@IdBaja, @IdReemplazo) ORDER BY IdJugador;
SELECT COUNT(*) AS ConvocadosBrasil FROM Torneo.Jugador WHERE IdSeleccion = @SelBra AND FechaBaja IS NULL;   -- esperado: 23

PRINT '=== Prueba 3: baja de ultimo momento sin reemplazo ===';
-- Resultado esperado: ARG-26 queda dado de baja por enfermedad el 02/06. Argentina pasa de 26 a 25 convocados,
-- que sigue siendo mas que el minimo de 23.
EXEC Torneo.usp_RegistrarBajaJugador @IdJugador = @IdBajaSinReemplazo, @MotivoBaja = 'Enfermedad', @FechaBaja = '2026-06-02';
SELECT IdJugador, CodigoExterno, FechaBaja, MotivoBaja, IdJugadorReemplazo FROM Torneo.Jugador WHERE IdJugador = @IdBajaSinReemplazo;
SELECT COUNT(*) AS ConvocadosArgentina FROM Torneo.Jugador WHERE IdSeleccion = @SelArg AND FechaBaja IS NULL;   -- esperado: 25
GO
