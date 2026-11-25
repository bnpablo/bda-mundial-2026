/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-24
 Script       : 99_Seguridad_5_Test_Administrador.sql
 Objetivo     : Testing de los permisos de rol_administrador con el usuario u_administrador:
                que puede hacer (leer todo, ver los datos personales en claro, ejecutar los
                SP) y que no (modificar tablas directamente, crear objetos, abrir la clave
                de cifrado). Muestra tambien que en disco los datos personales estan cifrados.
                El alta de prueba se da de baja al final: la base queda como estaba.
 Requisito    : ejecutar despues de 99_Seguridad_4_Roles.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @idSeleccion INT, @idPais INT, @idJugador INT;

-- Limpieza por si una corrida anterior quedo a medias.
SELECT @idJugador = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'SEG-ADM-01';
IF @idJugador IS NOT NULL
    EXEC Torneo.usp_Jugador_Baja @IdJugador = @idJugador;
SET @idJugador = NULL;

-- Una seleccion con lugar en la convocatoria y el dorsal 99 libre.
SELECT TOP 1 @idSeleccion = s.IdSeleccion, @idPais = s.IdPais
FROM Torneo.Seleccion s
WHERE (SELECT COUNT(*) FROM Torneo.Jugador j WHERE j.IdSeleccion = s.IdSeleccion AND j.FechaBaja IS NULL) < 26
  AND NOT EXISTS (SELECT 1 FROM Torneo.Jugador j WHERE j.IdSeleccion = s.IdSeleccion AND j.Dorsal = 99)
ORDER BY s.IdSeleccion;

PRINT '=== Prueba 1: lee los datos personales de la tabla ===';
-- Resultado esperado: 3 filas con nombre, apellido y fecha de nacimiento legibles.
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    SELECT TOP 3 IdJugador, Nombre, Apellido, FechaNacimiento FROM Torneo.Jugador ORDER BY IdJugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 2: lee la columna cifrada, que es la que esta en disco ===';
-- Resultado esperado: 3 filas con el apellido como valor hexadecimal ilegible (0x...).
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    SELECT TOP 3 IdJugador, CONVERT(VARCHAR(40), ApellidoCifrado, 1) AS ApellidoEnDisco FROM Torneo.Jugador ORDER BY IdJugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 3: ejecuta un reporte de otro esquema ===';
-- Resultado esperado: filas del reporte de goleadores de una seleccion, con los apellidos en claro.
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    EXEC Reportes.usp_ReportarGoleadores @IdSeleccion = @idSeleccion;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 4: da de alta un jugador por SP ===';
-- Resultado esperado: alta correcta; el SP cifra los datos sin que el usuario tenga permiso sobre la clave.
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = 'SEG-ADM-01', @Nombre = 'Prueba', @Apellido = 'Administrador',
         @IdPais = @idPais, @IdSeleccion = @idSeleccion, @Dorsal = 99, @PosicionHabitual = 'DEL',
         @ClubOrigen = 'Club de prueba', @FechaAlta = '2026-06-01', @FechaNacimiento = '2000-01-01',
         @IdJugador = @idJugador OUTPUT;
    SELECT 'Alta correcta, IdJugador = ' + CAST(@idJugador AS VARCHAR(10)) AS Resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 5: borra datos de una tabla directamente ===';
-- Resultado esperado: error 229, permiso DELETE denegado sobre Torneo.Pais (toda escritura pasa por SP).
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    DELETE FROM Torneo.Pais WHERE IdPais = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 6: crea una tabla ===';
-- Resultado esperado: error 262, permiso CREATE TABLE denegado en la base.
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    CREATE TABLE dbo.PruebaSeguridad (Id INT);
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;
IF OBJECT_ID('dbo.PruebaSeguridad') IS NOT NULL
    DROP TABLE dbo.PruebaSeguridad;

PRINT '=== Prueba 7: abre la clave de cifrado por su cuenta ===';
-- Resultado esperado: error 15151, no puede abrir la clave: ve los datos en claro por la tabla y los SP, no por la clave.
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
    SELECT 'ABRIO LA CLAVE' AS Resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;

PRINT '=== Prueba 8: da de baja el jugador de prueba por SP y comprueba que no quedan claves abiertas ===';
-- Resultado esperado: baja correcta, 0 filas con el codigo SEG-ADM-01 y 0 claves abiertas.
EXECUTE AS USER = 'u_administrador';
BEGIN TRY
    EXEC Torneo.usp_Jugador_Baja @IdJugador = @idJugador;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
REVERT;
SELECT (SELECT COUNT(*) FROM Torneo.Jugador WHERE CodigoExterno = 'SEG-ADM-01') AS JugadoresDePrueba,
       (SELECT COUNT(*) FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') AS ClavesAbiertas;
GO
