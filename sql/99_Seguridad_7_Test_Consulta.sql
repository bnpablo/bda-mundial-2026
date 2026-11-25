/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-24
 Script       : 99_Seguridad_7_Test_Consulta.sql
 Objetivo     : Testing de los permisos de rol_consulta con el usuario u_consulta: que puede
                hacer (ejecutar los reportes) y que no (leer las tablas, modificar datos,
                ejecutar SP de carga, abrir la clave de cifrado). Los reportes muestran los
                datos personales en claro aunque el usuario no tenga acceso a las tablas ni
                a la clave: el acceso lo controla el permiso sobre cada SP.
                Este test no modifica la base.
 Requisito    : ejecutar despues de 99_Seguridad_4_Roles.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @idSeleccion INT;
SELECT TOP 1 @idSeleccion = IdSeleccion FROM Torneo.Seleccion ORDER BY IdSeleccion;

PRINT '=== Prueba 1: ejecuta el reporte de goleadores ===';
-- Resultado esperado: filas con los goleadores, con nombre y apellido en claro.
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    EXEC Reportes.usp_ReportarGoleadores;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 2: ejecuta el reporte de plantillas (XML) ===';
-- Resultado esperado: un XML con la seleccion y sus convocados, con nombre y apellido en claro.
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    EXEC Reportes.usp_ReportarPlantillas @IdSeleccion = @idSeleccion;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 3: ejecuta la matriz de prime time (usa SQL dinamico) ===';
-- Resultado esperado: la matriz de partidos por pais, sin error de permisos.
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    EXEC Reportes.usp_ReportarMatrizPrimeTime;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 4: lee la tabla de jugadores directamente ===';
-- Resultado esperado: error 229, permiso SELECT denegado sobre Torneo.Jugador.
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    SELECT TOP 1 Apellido FROM Torneo.Jugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 5: modifica una tabla directamente ===';
-- Resultado esperado: error 229, permiso denegado sobre Torneo.Jugador (no puede modificar tablas).
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    UPDATE Torneo.Jugador SET Dorsal = Dorsal WHERE IdJugador = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 6: ejecuta un SP de carga ===';
-- Resultado esperado: error 229, permiso EXECUTE denegado sobre Torneo.usp_Pais_Baja.
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    EXEC Torneo.usp_Pais_Baja @IdPais = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 7: abre la clave de cifrado por su cuenta ===';
-- Resultado esperado: error 15151, no puede abrir la clave.
EXECUTE AS USER = 'u_consulta';
BEGIN TRY
    OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
    SELECT 'ABRIO LA CLAVE' AS Resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 8: comprueba que no quedan claves abiertas ===';
-- Resultado esperado: 0 claves abiertas.
SELECT COUNT(*) AS ClavesAbiertas FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales';
GO
