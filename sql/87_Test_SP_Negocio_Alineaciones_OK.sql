/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 87_Test_SP_Negocio_Alineaciones_OK.sql
 Objetivo     : Testing exitoso de 86_SP_Negocio_Alineaciones.sql: registrar la
                alineacion de las dos selecciones de un partido, verificarla y
                registrar cambios. La lista de jugadores se arma con una consulta
                FOR JSON y se carga unicamente con los SP.
 Requisito    : ejecutar despues de 85_Test_SP_Negocio_Convocatoria_Validaciones.sql
                (usa el partido 5, En juego, de octavos entre Argentina y Brasil,
                sin alineaciones; Brasil con 23 jugadores activos, entre ellos
                BRA-24, el reemplazo del script 84).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @IdP5 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-005');
DECLARE @jsonArg VARCHAR(MAX), @jsonBra VARCHAR(MAX);
DECLARE @IdArg07 INT, @IdArg08 INT, @IdBra18 INT, @IdBra20 INT, @IdSust INT;

SELECT Estado, EsquemaTacticoLocal, EsquemaTacticoVisitante,
       (SELECT COUNT(*) FROM Formacion.Alineacion WHERE IdPartido = @IdP5) AS Alineaciones
FROM Torneo.Partido WHERE IdPartido = @IdP5;     -- esperado: En juego, NULL, NULL, 0

PRINT '=== Prueba 1: registrar la alineacion de Argentina ===';
-- Resultado esperado: en una sola operacion se carga el esquema 4-3-3 como esquema local del partido y 17
-- jugadores de Argentina: 11 titulares (dorsales 1, 4, 5, 6, 7, 11, 12, 13, 18, 19 y 20) y 6 suplentes.
SET @jsonArg = (
    SELECT j.IdJugador,
           CAST(CASE WHEN j.Dorsal IN (1, 4, 5, 6, 7, 11, 12, 13, 18, 19, 20) THEN 1 ELSE 0 END AS BIT) AS EsTitular,
           j.PosicionHabitual AS PosicionCancha
    FROM Torneo.Jugador j
    WHERE j.IdSeleccion = @SelArg AND j.FechaBaja IS NULL
      AND j.Dorsal IN (1, 2, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21)
    ORDER BY j.Dorsal
    FOR JSON PATH);
EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP5, @IdSeleccion = @SelArg,
     @EsquemaTactico = '4-3-3', @Jugadores = @jsonArg;
SELECT EsquemaTacticoLocal, EsquemaTacticoVisitante FROM Torneo.Partido WHERE IdPartido = @IdP5;
SELECT j.Dorsal, j.CodigoExterno, a.EsTitular, a.PosicionCancha
FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
WHERE a.IdPartido = @IdP5 ORDER BY a.EsTitular DESC, j.Dorsal;

PRINT '=== Prueba 2: registrar la alineacion de Brasil ===';
-- Resultado esperado: se carga el esquema 4-4-2 como esquema visitante y 16 jugadores de Brasil: 11 titulares
-- y 5 suplentes, entre ellos BRA-24 (el reemplazo). BRA-05 no se incluye porque esta dado de baja.
SET @jsonBra = (
    SELECT j.IdJugador,
           CAST(CASE WHEN j.Dorsal IN (1, 4, 6, 7, 8, 11, 12, 13, 14, 18, 19) THEN 1 ELSE 0 END AS BIT) AS EsTitular,
           j.PosicionHabitual AS PosicionCancha
    FROM Torneo.Jugador j
    WHERE j.IdSeleccion = @SelBra AND j.FechaBaja IS NULL
      AND j.Dorsal IN (1, 2, 4, 6, 7, 8, 9, 11, 12, 13, 14, 15, 18, 19, 20, 24)
    ORDER BY j.Dorsal
    FOR JSON PATH);
EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @IdP5, @IdSeleccion = @SelBra,
     @EsquemaTactico = '4-4-2', @Jugadores = @jsonBra;
SELECT EsquemaTacticoLocal, EsquemaTacticoVisitante FROM Torneo.Partido WHERE IdPartido = @IdP5;
SELECT COUNT(*) AS AlineacionesDelPartido FROM Formacion.Alineacion WHERE IdPartido = @IdP5;     -- esperado: 33

PRINT '=== Prueba 3: verificar la alineacion del partido ===';
-- Resultado esperado: una fila por seleccion. Argentina: 11 titulares, 6 suplentes, 0 cambios, OK.
-- Brasil: 11 titulares, 5 suplentes, 0 cambios, OK.
EXEC Formacion.usp_VerificarAlineacion @IdPartido = @IdP5;

PRINT '=== Prueba 4: registrar un cambio de cada seleccion ===';
-- Resultado esperado: se crean 2 sustituciones en el partido 5. Argentina: sale ARG-07 y entra ARG-08 en el
-- minuto 60 (ventana 1, tactico). Brasil: sale BRA-18 y entra BRA-20 en el minuto 75 (ventana 2, lesion).
SELECT @IdArg07 = MAX(CASE WHEN CodigoExterno = 'ARG-07' THEN IdJugador ELSE 0 END),
       @IdArg08 = MAX(CASE WHEN CodigoExterno = 'ARG-08' THEN IdJugador ELSE 0 END),
       @IdBra18 = MAX(CASE WHEN CodigoExterno = 'BRA-18' THEN IdJugador ELSE 0 END),
       @IdBra20 = MAX(CASE WHEN CodigoExterno = 'BRA-20' THEN IdJugador ELSE 0 END)
FROM Torneo.Jugador;
EXEC Formacion.usp_RegistrarCambio @IdPartido = @IdP5, @IdJugadorSale = @IdArg07, @IdJugadorEntra = @IdArg08,
     @Periodo = 'Segundo tiempo', @Minuto = 60, @Motivo = 'Tactico', @NumeroVentana = 1, @IdSustitucion = @IdSust OUTPUT;
EXEC Formacion.usp_RegistrarCambio @IdPartido = @IdP5, @IdJugadorSale = @IdBra18, @IdJugadorEntra = @IdBra20,
     @Periodo = 'Segundo tiempo', @Minuto = 75, @Motivo = 'Lesion', @NumeroVentana = 2, @IdSustitucion = @IdSust OUTPUT;
SELECT su.IdSustitucion, js.CodigoExterno AS Sale, je.CodigoExterno AS Entra, su.Minuto, su.NumeroVentana, su.Motivo
FROM Formacion.Sustitucion su
JOIN Formacion.Alineacion asa ON asa.IdAlineacion = su.IdAlineacionSale
JOIN Torneo.Jugador js        ON js.IdJugador = asa.IdJugador
JOIN Formacion.Alineacion aen ON aen.IdAlineacion = su.IdAlineacionEntra
JOIN Torneo.Jugador je        ON je.IdJugador = aen.IdJugador
WHERE asa.IdPartido = @IdP5 ORDER BY su.IdSustitucion;

PRINT '=== Prueba 5: verificar la alineacion despues de los cambios ===';
-- Resultado esperado: Argentina y Brasil con 1 cambio cada una; los titulares y suplentes no cambian.
EXEC Formacion.usp_VerificarAlineacion @IdPartido = @IdP5;
GO
