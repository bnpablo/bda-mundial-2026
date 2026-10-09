/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 01_Base_Esquemas.sql
 Objetivo     : Crea la base de datos MundialDB y los esquemas del sistema.
                Se puede ejecutar mas de una vez: recrea la base desde cero.
 Prerrequisito: las carpetas indicadas en @RutaDatos y @RutaLogs deben existir y
                el servicio de SQL Server debe tener permiso de escritura sobre ellas.
 Uso          : cada integrante ajusta SOLO las dos rutas de la seccion CONFIGURACION.
                Equipo de un solo volumen: D:\SQLData y D:\SQLLogs.
==============================================================================*/
USE master;


GO
-- Si la base ya existe se elimina para poder recrearla desde cero.
IF DB_ID('MundialDB') IS NOT NULL
    BEGIN
        ALTER DATABASE MundialDB
            SET SINGLE_USER 
            WITH ROLLBACK IMMEDIATE;
        DROP DATABASE MundialDB;
    END

/*------------------------------------------------------------------------------
 JUSTIFICACION DEL SQL DINAMICO
 El argumento FILENAME de CREATE DATABASE solo acepta literales, no variables.
 "FILENAME = N'D:\SQLData\MundialDB.mdf'"
 Para que cada maquina pueda usar su propia carpeta sin editar el CREATE
 DATABASE, la sentencia se arma como texto y se ejecuta con EXEC. Es el unico
 uso de SQL dinamico del proyecto y no recibe datos de usuarios.
------------------------------------------------------------------------------*/
-- CONFIGURACION (sin barra final en las rutas)
DECLARE @RutaDatos AS NVARCHAR (260) = N'D:\SQLData';

DECLARE @RutaLogs AS NVARCHAR (260) = N'D:\SQLLogs';

DECLARE @sql AS NVARCHAR (MAX) = CONCAT(N'CREATE DATABASE MundialDB ', N'ON PRIMARY (NAME = N''MundialDB'', FILENAME = N''', @RutaDatos, N'\MundialDB.mdf'', ', N'SIZE = 3GB, FILEGROWTH = 256MB, MAXSIZE = 9GB) ', N'LOG ON (NAME = N''MundialDB_log'', FILENAME = N''', @RutaLogs, N'\MundialDB_log.ldf'', ', N'SIZE = 1GB, FILEGROWTH = 256MB, MAXSIZE = 4GB) ', N'COLLATE Modern_Spanish_CI_AS;');

EXECUTE (@sql);


GO
ALTER DATABASE MundialDB
    SET RECOVERY SIMPLE;


GO
USE MundialDB;


GO
-- Esquemas. Cada CREATE SCHEMA va en su propio lote (por eso el GO).
CREATE SCHEMA Torneo;


GO
CREATE SCHEMA Formacion;


GO
CREATE SCHEMA Incidencia;


GO
CREATE SCHEMA Arbitraje;


GO
CREATE SCHEMA Publicidad;


GO
CREATE SCHEMA Importacion;


GO
CREATE SCHEMA Reportes;


GO

