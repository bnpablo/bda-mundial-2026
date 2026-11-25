/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-25
 Script       : 99_Visualizacion_4_Acceso_BI.sql
 Objetivo     : Entrega 9. Acceso de solo lectura para la plataforma de BI:
                  - login lg_bi (autenticacion de SQL Server: la plataforma corre
                    en un contenedor y no puede usar la cuenta de Windows);
                  - usuario u_bi y rol rol_bi, que solo puede leer las vistas del
                    esquema Reportes. Las vistas muestran los datos personales en
                    claro, pero el rol no tiene permiso sobre las tablas ni sobre la
                    clave de cifrado: el acceso se controla con la vista.
                El rol y el usuario se crean con Seguridad.usp_ConfigurarAccesoBI.
                Se puede ejecutar mas de una vez.
 Requisito    : ejecutar despues de 99_Seguridad_4_Roles.sql y de
                99_Visualizacion_3_Vistas_BI.sql.
 Nota         : la contrasena del login es un valor de demostracion; en un entorno
                real se elige otra y se guarda aparte. Para conectarse el servidor
                debe tener habilitada la autenticacion mixta y TCP/IP (ver el
                documento de la Entrega 9).
==============================================================================*/
USE master;
GO

IF SUSER_ID('lg_bi') IS NULL
    CREATE LOGIN lg_bi WITH PASSWORD = 'Demo-BI-2026-SoloParaDemostracion', CHECK_POLICY = OFF;
GO

USE MundialDB;
GO

CREATE OR ALTER PROCEDURE Seguridad.usp_ConfigurarAccesoBI
AS
BEGIN
    SET NOCOUNT ON;

    IF DATABASE_PRINCIPAL_ID('rol_bi') IS NULL
        CREATE ROLE rol_bi;

    -- Un usuario de una base restaurada puede quedar sin login: se recrea.
    IF DATABASE_PRINCIPAL_ID('u_bi') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.database_principals dp
                       JOIN sys.server_principals sp ON sp.sid = dp.sid
                       WHERE dp.name = 'u_bi')
        DROP USER u_bi;

    IF DATABASE_PRINCIPAL_ID('u_bi') IS NULL
        CREATE USER u_bi FOR LOGIN lg_bi;

    IF IS_ROLEMEMBER('rol_bi', 'u_bi') = 0 OR IS_ROLEMEMBER('rol_bi', 'u_bi') IS NULL
        ALTER ROLE rol_bi ADD MEMBER u_bi;

    -- Solo lectura de las vistas de Reportes.
    GRANT SELECT ON SCHEMA::Reportes TO rol_bi;
    DENY INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Reportes TO rol_bi;

    -- Ninguna tabla de datos ni procedimiento de los demas esquemas.
    DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Torneo      TO rol_bi;
    DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Formacion   TO rol_bi;
    DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Incidencia  TO rol_bi;
    DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Arbitraje   TO rol_bi;
    DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Publicidad  TO rol_bi;
    DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::Importacion TO rol_bi;
END
GO

EXEC Seguridad.usp_ConfigurarAccesoBI;
GO

SELECT r.name AS Rol, m.name AS Usuario
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name = 'rol_bi';
GO
