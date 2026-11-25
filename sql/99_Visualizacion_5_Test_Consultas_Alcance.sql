/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-25
 Script       : 99_Visualizacion_5_Test_Consultas_Alcance.sql
 Objetivo     : Testing de la Entrega 9: el fixture filtrado, el historial de titularidad,
                el equipo en cancha en un minuto, la geolocalizacion de sedes y las
                vistas del BI. Los casos de error muestran el numero y el mensaje.
                Las pruebas que dan de alta una sede la eliminan al terminar.
 Requisito    : ejecutar despues de 99_Visualizacion_4_Acceso_BI.sql. Usa el partido
                203 y la seleccion de Alemania de 99_Datos_Aceptacion.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @idPartido INT, @idSede INT, @idSeleccion INT, @idJugador INT, @fecha DATE;

SELECT @idPartido = IdPartido, @idSede = IdSede, @fecha = CAST(FechaHoraLocal AS DATE)
FROM Torneo.Partido WHERE NumeroPartido = 203;

SELECT @idSeleccion = s.IdSeleccion
FROM Torneo.Seleccion s JOIN Torneo.Pais pa ON pa.IdPais = s.IdPais
WHERE pa.CodigoIso3 = 'DEU';

SELECT TOP 1 @idJugador = a.IdJugador
FROM Formacion.Alineacion a
WHERE a.IdPartido = @idPartido AND a.EsTitular = 1
ORDER BY a.IdAlineacion;

PRINT '=== Prueba 1: fixture completo, sin filtros ===';
-- Resultado esperado: una fila por cada partido cargado, ordenadas por fecha UTC, con la
-- hora local y UTC. El marcador solo figura en los partidos finalizados.
EXEC Reportes.usp_ReportarFixture;

PRINT '=== Prueba 2: fixture de una sede ===';
-- Resultado esperado: solo partidos de la sede del partido 203 (Hard Rock Stadium).
EXEC Reportes.usp_ReportarFixture @IdSede = @idSede;

PRINT '=== Prueba 3: fixture de una seleccion en una fase ===';
-- Resultado esperado: los partidos de Alemania en la fase de grupos, como local o visitante.
EXEC Reportes.usp_ReportarFixture @Fase = 'Grupos', @IdSeleccion = @idSeleccion;

PRINT '=== Prueba 4: fixture de una fecha ===';
-- Resultado esperado: los partidos cuya fecha local es 2026-06-11, entre ellos el 203.
EXEC Reportes.usp_ReportarFixture @Fecha = @fecha;

PRINT '=== Prueba 5: fixture con filtros que no existen ===';
-- Resultado esperado: error 50001 con tres mensajes: sede, fase y seleccion inexistentes.
BEGIN TRY
    EXEC Reportes.usp_ReportarFixture @IdSede = -1, @Fase = 'Inventada', @IdSeleccion = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: historial de titularidad de un jugador ===';
-- Resultado esperado: una fila por partido en que figura en la alineacion, con el rival
-- y si fue titular. Incluye al menos el partido 203, en el que es titular.
SELECT * FROM Formacion.fn_HistorialTitularidad(@idJugador) ORDER BY FechaHoraUtc;

PRINT '=== Prueba 7: historial de titularidad de un jugador inexistente ===';
-- Resultado esperado: 0 filas.
SELECT COUNT(*) AS Filas FROM Formacion.fn_HistorialTitularidad(-1);

PRINT '=== Prueba 8: equipo en cancha al minuto 1 ===';
-- Resultado esperado: 22 filas, los 11 titulares de cada seleccion (EsTitular = 1).
SELECT COUNT(*) AS EnCancha, SUM(CAST(EsTitular AS INT)) AS Titulares
FROM Incidencia.fn_EquipoEnCancha(@idPartido, 'Primer tiempo', 1, 0);

PRINT '=== Prueba 9: equipo en cancha antes y despues de la primera sustitucion ===';
-- Resultado esperado: en las dos tomas hay 22 jugadores. El que sale (SaleEnCancha) esta
-- en la toma de un minuto antes (1) y no en la de un minuto despues (0); el que entra
-- (EntraEnCancha) esta solo despues (0 y 1).
DECLARE @periodo VARCHAR(30), @minuto INT, @sale INT, @entra INT;

SELECT TOP 1 @periodo = s.Periodo, @minuto = s.Minuto,
             @sale = sa.IdJugador, @entra = se.IdJugador
FROM Formacion.Sustitucion s
JOIN Formacion.Alineacion sa ON sa.IdAlineacion = s.IdAlineacionSale
JOIN Formacion.Alineacion se ON se.IdAlineacion = s.IdAlineacionEntra
WHERE sa.IdPartido = @idPartido
ORDER BY Incidencia.fn_MomentoPartido(s.Periodo, s.Minuto, s.MinutoAdicional);

SELECT 'Un minuto antes' AS Toma, COUNT(*) AS EnCancha,
       SUM(CASE WHEN IdJugador = @sale THEN 1 ELSE 0 END)  AS SaleEnCancha,
       SUM(CASE WHEN IdJugador = @entra THEN 1 ELSE 0 END) AS EntraEnCancha
FROM Incidencia.fn_EquipoEnCancha(@idPartido, @periodo, @minuto - 1, 0)
UNION ALL
SELECT 'Un minuto despues', COUNT(*),
       SUM(CASE WHEN IdJugador = @sale THEN 1 ELSE 0 END),
       SUM(CASE WHEN IdJugador = @entra THEN 1 ELSE 0 END)
FROM Incidencia.fn_EquipoEnCancha(@idPartido, @periodo, @minuto + 1, 0);

PRINT '=== Prueba 10: equipo en cancha con un periodo que no existe ===';
-- Resultado esperado: 0 filas.
SELECT COUNT(*) AS Filas FROM Incidencia.fn_EquipoEnCancha(@idPartido, 'Tercer tiempo', 10, 0);

PRINT '=== Prueba 11: alta de una sede con coordenadas ===';
-- Resultado esperado: la sede queda con Latitud -34.545300 y Longitud -58.449800 (una fila).
DECLARE @idPais INT, @idNueva INT;
SELECT @idPais = IdPais FROM Torneo.Sede WHERE IdSede = @idSede;
EXEC Torneo.usp_Sede_Alta 'E9-SEDE-01', 'Estadio de Prueba Geolocalizacion', 'Buenos Aires', @idPais,
     'Argentina Standard Time', 70000, @idNueva OUTPUT, -34.5453, -58.4498;
SELECT NombreEstadio, Latitud, Longitud FROM Torneo.Sede WHERE IdSede = @idNueva;

PRINT '=== Prueba 12: modificacion que quita las coordenadas ===';
-- Resultado esperado: la sede queda con Latitud y Longitud NULL (modificacion completa).
EXEC Torneo.usp_Sede_Modificacion @idNueva, 'E9-SEDE-01', 'Estadio de Prueba Geolocalizacion', 'Buenos Aires',
     @idPais, 'Argentina Standard Time', 70000;
SELECT NombreEstadio, Latitud, Longitud FROM Torneo.Sede WHERE IdSede = @idNueva;

PRINT '=== Prueba 13: alta con solo la latitud ===';
-- Resultado esperado: error 50001, la latitud y la longitud se informan juntas.
BEGIN TRY
    EXEC Torneo.usp_Sede_Alta 'E9-SEDE-02', 'Estadio de Prueba Latitud', 'Buenos Aires', @idPais,
         'Argentina Standard Time', 70000, @idNueva OUTPUT, -34.5453;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 14: alta con latitud y longitud fuera de rango ===';
-- Resultado esperado: error 50001, la latitud debe estar entre -90 y 90 y la longitud entre -180 y 180.
BEGIN TRY
    EXEC Torneo.usp_Sede_Alta 'E9-SEDE-03', 'Estadio de Prueba Rango', 'Buenos Aires', @idPais,
         'Argentina Standard Time', 70000, @idNueva OUTPUT, 91, 200;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

-- Se elimina la sede de prueba (la de la prueba 11).
SELECT @idNueva = IdSede FROM Torneo.Sede WHERE CodigoExterno = 'E9-SEDE-01';
EXEC Torneo.usp_Sede_Baja @idNueva;

PRINT '=== Prueba 15: vistas del BI ===';
-- Resultado esperado: una fila por vista con la cantidad de filas. Goleadores y tarjetas
-- tienen datos, los ingresos tienen una fila por sede con publicidad exhibida y las sedes
-- con coordenadas son las 8 de los datos de aceptacion.
SELECT (SELECT COUNT(*) FROM Reportes.vw_Goleadores)                              AS Goleadores,
       (SELECT COUNT(*) FROM Reportes.vw_TarjetasPorSeleccion)                    AS Selecciones,
       (SELECT COUNT(*) FROM Reportes.vw_IngresosPorSede)                         AS SedesConIngresos,
       (SELECT COUNT(*) FROM Reportes.vw_Sedes WHERE Latitud IS NOT NULL)         AS SedesConCoordenadas;

PRINT '=== Prueba 16: la base queda como estaba ===';
-- Resultado esperado: 0 sedes de prueba y 0 claves abiertas.
SELECT (SELECT COUNT(*) FROM Torneo.Sede WHERE CodigoExterno LIKE 'E9-SEDE-%')            AS SedesDePrueba,
       (SELECT COUNT(*) FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales')        AS ClavesAbiertas;
GO
