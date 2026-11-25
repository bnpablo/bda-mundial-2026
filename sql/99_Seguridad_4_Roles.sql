/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-24
 Script       : 99_Seguridad_4_Roles.sql
 Objetivo     : Roles de seguridad con permisos granulares y usuarios de prueba.
                  - rol_administrador       : lee todos los esquemas y ejecuta todos sus SP.
                  - rol_cargador_resultados : ejecuta los SP de Torneo, Formacion e Incidencia
                                              y el reporte de resultados.
                  - rol_consulta            : ejecuta solo los SP del esquema Reportes.
                Ningun rol modifica las tablas directamente (INSERT, UPDATE y DELETE
                denegados): toda escritura pasa por los SP de las entregas anteriores. Ningun
                rol tiene permiso sobre el certificado ni sobre la clave de cifrado: los SP que
                leen o escriben datos personales se ejecutan con los permisos del propietario.
                Los usuarios de prueba no tienen login: se usan con EXECUTE AS USER en los
                scripts 99_Seguridad_5 a 99_Seguridad_7.
                Se puede ejecutar mas de una vez.
 Requisito    : ejecutar despues de 99_Seguridad_3_Cifrado_Arbitraje.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*------------------------------------------------------------------------------
 Seguridad.usp_ConfigurarRoles
 Crea los roles (si no existen) y asigna los permisos. GRANT y DENY se pueden
 repetir sin efecto.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Seguridad.usp_ConfigurarRoles
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL
        CREATE ROLE rol_administrador;
    IF DATABASE_PRINCIPAL_ID('rol_cargador_resultados') IS NULL
        CREATE ROLE rol_cargador_resultados;
    IF DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL
        CREATE ROLE rol_consulta;

    -- Administrador: lee todo y ejecuta todos los SP de negocio. No modifica tablas
    -- directamente ni administra la seguridad (cifrado, roles).
    GRANT SELECT, EXECUTE ON SCHEMA::Torneo       TO rol_administrador;
    GRANT SELECT, EXECUTE ON SCHEMA::Formacion    TO rol_administrador;
    GRANT SELECT, EXECUTE ON SCHEMA::Incidencia   TO rol_administrador;
    GRANT SELECT, EXECUTE ON SCHEMA::Arbitraje    TO rol_administrador;
    GRANT SELECT, EXECUTE ON SCHEMA::Publicidad   TO rol_administrador;
    GRANT SELECT, EXECUTE ON SCHEMA::Importacion  TO rol_administrador;
    GRANT SELECT, EXECUTE ON SCHEMA::Reportes     TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Torneo       TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Formacion    TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Incidencia   TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Arbitraje    TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Publicidad   TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Importacion  TO rol_administrador;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::Reportes     TO rol_administrador;

    -- Cargador de resultados: carga partidos, formaciones, goles y tarjetas por SP y
    -- consulta el reporte de resultados. Sin acceso a arbitros, publicidad ni importacion.
    GRANT EXECUTE ON SCHEMA::Torneo      TO rol_cargador_resultados;
    GRANT EXECUTE ON SCHEMA::Formacion   TO rol_cargador_resultados;
    GRANT EXECUTE ON SCHEMA::Incidencia  TO rol_cargador_resultados;
    GRANT EXECUTE ON OBJECT::Reportes.usp_ReportarResultados TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Torneo       TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Formacion    TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Incidencia   TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Arbitraje    TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Publicidad   TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Importacion  TO rol_cargador_resultados;

    -- Consulta: solo ejecuta reportes.
    GRANT EXECUTE ON SCHEMA::Reportes TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Torneo       TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Formacion    TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Incidencia   TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Arbitraje    TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Publicidad   TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Importacion  TO rol_consulta;
END
GO

/*------------------------------------------------------------------------------
 Seguridad.usp_CrearUsuariosPrueba
 Un usuario sin login por rol, para probar los permisos con EXECUTE AS USER.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Seguridad.usp_CrearUsuariosPrueba
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DATABASE_PRINCIPAL_ID('u_administrador') IS NULL
        CREATE USER u_administrador WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('u_cargador') IS NULL
        CREATE USER u_cargador WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('u_consulta') IS NULL
        CREATE USER u_consulta WITHOUT LOGIN;

    ALTER ROLE rol_administrador       ADD MEMBER u_administrador;
    ALTER ROLE rol_cargador_resultados ADD MEMBER u_cargador;
    ALTER ROLE rol_consulta            ADD MEMBER u_consulta;
END
GO

EXEC Seguridad.usp_ConfigurarRoles;
EXEC Seguridad.usp_CrearUsuariosPrueba;
GO

-- Resumen: rol, usuario de prueba y permisos de nivel de esquema u objeto.
SELECT r.name AS Rol, u.name AS Usuario
FROM sys.database_principals r
JOIN sys.database_role_members m ON m.role_principal_id = r.principal_id
JOIN sys.database_principals u   ON u.principal_id = m.member_principal_id
WHERE r.name IN ('rol_administrador', 'rol_cargador_resultados', 'rol_consulta')
ORDER BY r.name;
GO
