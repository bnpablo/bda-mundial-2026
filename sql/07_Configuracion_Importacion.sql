/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 07_Configuracion_Importacion.sql
 Objetivo     : Habilita 'Ole Automation Procedures', que usan los procesos de
                importacion para leer archivos y consultar URL. Es una opcion de la
                instancia. Se puede ejecutar mas de una vez.
 Prerrequisito: un inicio de sesion con permiso ALTER SETTINGS.
==============================================================================*/
USE master;
GO

-- Es una opcion avanzada: para cambiarla hay que mostrar esas opciones.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO

EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

-- Resultado esperado: Ole Automation Procedures con EnUso = 1 y show advanced options con EnUso = 0.
SELECT name AS Opcion, value_in_use AS EnUso
FROM sys.configurations
WHERE name IN ('Ole Automation Procedures', 'show advanced options');
GO
