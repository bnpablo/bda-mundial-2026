/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-24
 Script       : 99_Seguridad_6_Test_Cargador.sql
 Objetivo     : Testing de los permisos de rol_cargador_resultados con el usuario u_cargador:
                que puede hacer (cargar datos por los SP de Torneo y ejecutar el reporte de
                resultados) y que no (leer las tablas, ver datos personales, abrir la clave
                de cifrado, usar arbitros, publicidad o el reporte de plantillas).
                El alta de prueba se da de baja al final: la base queda como estaba.
 Requisito    : ejecutar despues de 99_Seguridad_4_Roles.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @idSeleccion INT, @idPais INT, @idJugador INT;

-- Limpieza por si una corrida anterior quedo a medias.
SELECT @idJugador = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'SEG-CAR-01';
IF @idJugador IS NOT NULL
    EXEC Torneo.usp_Jugador_Baja @IdJugador = @idJugador;
SET @idJugador = NULL;

-- Una seleccion con lugar en la convocatoria y el dorsal 99 libre.
SELECT TOP 1 @idSeleccion = s.IdSeleccion, @idPais = s.IdPais
FROM Torneo.Seleccion s
WHERE (SELECT COUNT(*) FROM Torneo.Jugador j WHERE j.IdSeleccion = s.IdSeleccion AND j.FechaBaja IS NULL) < 26
  AND NOT EXISTS (SELECT 1 FROM Torneo.Jugador j WHERE j.IdSeleccion = s.IdSeleccion AND j.Dorsal = 99)
ORDER BY s.IdSeleccion;

PRINT '=== Prueba 1: da de alta un jugador por SP ===';
-- Resultado esperado: alta correcta; el SP cifra los datos aunque el usuario no tenga permiso sobre la clave.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = 'SEG-CAR-01', @Nombre = 'Prueba', @Apellido = 'Cargador',
         @IdPais = @idPais, @IdSeleccion = @idSeleccion, @Dorsal = 99, @PosicionHabitual = 'DEL',
         @ClubOrigen = 'Club de prueba', @FechaAlta = '2026-06-01', @FechaNacimiento = '2000-01-01',
         @IdJugador = @idJugador OUTPUT;
    SELECT 'Alta correcta, IdJugador = ' + CAST(@idJugador AS VARCHAR(10)) AS Resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 2: ejecuta el reporte de resultados ===';
-- Resultado esperado: filas con los resultados de los partidos (solo selecciones y marcadores).
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    EXEC Reportes.usp_ReportarResultados @IdSeleccion = @idSeleccion;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 3: lee la tabla de jugadores directamente ===';
-- Resultado esperado: error 229, permiso SELECT denegado sobre Torneo.Jugador.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    SELECT TOP 1 Apellido FROM Torneo.Jugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 4: lee la columna cifrada directamente ===';
-- Resultado esperado: error 229, permiso SELECT denegado sobre Torneo.Jugador.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    SELECT TOP 1 ApellidoCifrado FROM Torneo.Jugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 5: abre la clave de cifrado por su cuenta ===';
-- Resultado esperado: error 15151, no puede abrir la clave.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
    SELECT 'ABRIO LA CLAVE' AS Resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 6: ejecuta el reporte de plantillas, que muestra nombres de jugadores ===';
-- Resultado esperado: error 229, permiso EXECUTE denegado sobre Reportes.usp_ReportarPlantillas.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    EXEC Reportes.usp_ReportarPlantillas @IdSeleccion = @idSeleccion;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 7: ejecuta un SP de arbitros ===';
-- Resultado esperado: error 229, permiso EXECUTE denegado sobre Arbitraje.usp_Arbitro_Baja.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 8: ejecuta un SP de publicidad ===';
-- Resultado esperado: error 229, permiso EXECUTE denegado sobre Publicidad.usp_Anunciante_Baja.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 9: da de baja el jugador de prueba por SP y comprueba que no quedan claves abiertas ===';
-- Resultado esperado: baja correcta, 0 filas con el codigo SEG-CAR-01 y 0 claves abiertas.
EXECUTE AS USER = 'u_cargador';
BEGIN TRY
    EXEC Torneo.usp_Jugador_Baja @IdJugador = @idJugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;
SELECT (SELECT COUNT(*) FROM Torneo.Jugador WHERE CodigoExterno = 'SEG-CAR-01') AS JugadoresDePrueba,
       (SELECT COUNT(*) FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') AS ClavesAbiertas;
GO
