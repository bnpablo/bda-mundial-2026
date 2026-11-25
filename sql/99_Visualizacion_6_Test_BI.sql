/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-25
 Script       : 99_Visualizacion_6_Test_BI.sql
 Objetivo     : Testing de los permisos de rol_bi con el usuario u_bi, el que usa la
                plataforma de BI: que puede hacer (leer las vistas del esquema Reportes,
                con los datos personales en claro) y que no (leer las tablas, modificar
                datos, ejecutar procedimientos, abrir la clave de cifrado).
                Este test no modifica la base.
 Requisito    : ejecutar despues de 99_Visualizacion_4_Acceso_BI.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

PRINT '=== Prueba 1: lee la vista de goleadores ===';
-- Resultado esperado: los goleadores con nombre y apellido en claro.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    SELECT TOP 5 Jugador, Seleccion, Goles FROM Reportes.vw_Goleadores ORDER BY Goles DESC, Jugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 2: lee las vistas de tarjetas, ingresos y sedes ===';
-- Resultado esperado: una fila con la cantidad de filas de cada vista, sin error de permisos.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    SELECT (SELECT COUNT(*) FROM Reportes.vw_TarjetasPorSeleccion) AS Selecciones,
           (SELECT COUNT(*) FROM Reportes.vw_IngresosPorSede)      AS SedesConIngresos,
           (SELECT COUNT(*) FROM Reportes.vw_Sedes)                AS Sedes;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 3: lee la tabla de jugadores directamente ===';
-- Resultado esperado: error 229, permiso SELECT denegado sobre Torneo.Jugador.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    SELECT TOP 1 Apellido FROM Torneo.Jugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 4: lee la columna cifrada ===';
-- Resultado esperado: error 229, permiso SELECT denegado sobre Torneo.Jugador.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    SELECT TOP 1 ApellidoCifrado FROM Torneo.Jugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 5: modifica una tabla directamente ===';
-- Resultado esperado: error 229, permiso denegado sobre Torneo.Sede (no puede modificar tablas).
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    UPDATE Torneo.Sede SET Capacidad = Capacidad WHERE IdSede = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 6: ejecuta un reporte ===';
-- Resultado esperado: error 229, permiso EXECUTE denegado sobre Reportes.usp_ReportarGoleadores.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    EXEC Reportes.usp_ReportarGoleadores;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 7: ejecuta un SP de carga ===';
-- Resultado esperado: error 229, permiso EXECUTE denegado sobre Torneo.usp_Pais_Baja.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    EXEC Torneo.usp_Pais_Baja @IdPais = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 8: abre la clave de cifrado por su cuenta ===';
-- Resultado esperado: error 15151, no puede abrir la clave.
EXECUTE AS USER = 'u_bi';
BEGIN TRY
    OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
    SELECT 'ABRIO LA CLAVE' AS Resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 9: comprueba que no quedan claves abiertas ===';
-- Resultado esperado: 0 claves abiertas.
SELECT COUNT(*) AS ClavesAbiertas FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales';
GO
