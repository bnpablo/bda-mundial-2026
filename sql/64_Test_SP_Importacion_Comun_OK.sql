/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 64_Test_SP_Importacion_Comun_OK.sql
 Objetivo     : Testing exitoso de 63_SP_Importacion_Comun.sql (relacion 1:1) y de
                las funciones de 58_Funciones_Importacion.sql.
 Requisito    : ejecutar despues de 07, 58 y 63. Sin C:\Importar\referees.csv, las
                pruebas 1 y 2 se omiten.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @contenido VARCHAR(MAX), @respuesta VARCHAR(MAX), @hayArchivo BIT = 1;

BEGIN TRY
    EXEC Importacion.usp_LeerArchivo @NombreArchivo = 'C:\Importar\referees.csv', @Contenido = @contenido OUTPUT;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50003 THROW;
    SET @hayArchivo = 0;
END CATCH

PRINT '=== Prueba 1: leer un archivo real completo ===';
-- Resultado esperado: mas de 60000 bytes y 494 lineas (encabezado + 493 filas).
IF @hayArchivo = 1
    SELECT DATALENGTH(@contenido) AS Bytes,
           (SELECT COUNT(*) FROM STRING_SPLIT(@contenido, CHAR(10), 1) WHERE value <> '') AS Lineas;
ELSE
    SELECT 'Prueba omitida: falta C:\Importar\referees.csv' AS Resultado;

PRINT '=== Prueba 2: los acentos del archivo UTF-8 se leen bien ===';
-- Resultado esperado: el encabezado y las filas de Adamkova y Aristizabal, con sus tildes.
IF @hayArchivo = 1
    SELECT ordinal AS Linea, LEFT(value, 45) AS Texto
    FROM STRING_SPLIT(@contenido, CHAR(10), 1)
    WHERE ordinal IN (1, 5, 27)
    ORDER BY ordinal;
ELSE
    SELECT 'Prueba omitida: falta C:\Importar\referees.csv' AS Resultado;

PRINT '=== Prueba 3: fn_CantidadCamposCsv ===';
-- Resultado esperado: 3, 1, 3, 3 y 0.
SELECT Importacion.fn_CantidadCamposCsv('a,b,c')       AS TresCampos,
       Importacion.fn_CantidadCamposCsv('a')           AS UnCampo,
       Importacion.fn_CantidadCamposCsv('a,"b,c",d')   AS ComaEntreComillas,
       Importacion.fn_CantidadCamposCsv('a,,')         AS CamposVacios,
       Importacion.fn_CantidadCamposCsv('a,"b,c')      AS ComillasSinCerrar;

PRINT '=== Prueba 4: fn_CampoCsv ===';
-- Resultado esperado: b; b,c; vacio; d"e; NULL.
SELECT Importacion.fn_CampoCsv('a,b,c', 2)         AS Simple,
       Importacion.fn_CampoCsv('a,"b,c",d', 2)     AS EntreComillas,
       Importacion.fn_CampoCsv('a,,c', 2)          AS Vacio,
       Importacion.fn_CampoCsv('a,"d""e",f', 2)    AS ComillaInterna,
       Importacion.fn_CampoCsv('a,b,c', 9)         AS NoExiste;

PRINT '=== Prueba 5: fn_CodigoPaisFuente ===';
-- Resultado esperado: DEU, DEU, GBR, NED, POR y NULL.
SELECT Importacion.fn_CodigoPaisFuente('Germany')      AS Alemania,
       Importacion.fn_CodigoPaisFuente('West Germany') AS AlemaniaOccidental,
       Importacion.fn_CodigoPaisFuente('Scotland')     AS Escocia,
       Importacion.fn_CodigoPaisFuente('Netherlands')  AS PaisesBajos,
       Importacion.fn_CodigoPaisFuente('Portugal')     AS Portugal,
       Importacion.fn_CodigoPaisFuente('Soviet Union') AS UnionSovietica;

PRINT '=== Prueba 6: consultar una URL (Frankfurter) ===';
-- Resultado esperado: un JSON valido de menos de 2048 bytes con la cotizacion de USD a ARS.
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'https://api.frankfurter.dev/v2/rate/USD/ARS', @Respuesta = @respuesta OUTPUT;
    SELECT DATALENGTH(@respuesta) AS Bytes, ISJSON(@respuesta) AS EsJson, @respuesta AS Respuesta;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: consultar una URL (Banco Mundial) ===';
-- Resultado esperado: un JSON valido con el PBI per capita de Argentina.
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'https://api.worldbank.org/v2/country/ARG/indicator/NY.GDP.PCAP.CD?format=json&mrnev=1&per_page=1', @Respuesta = @respuesta OUTPUT;
    SELECT DATALENGTH(@respuesta) AS Bytes, ISJSON(@respuesta) AS EsJson, JSON_VALUE(@respuesta, '$[1][0].countryiso3code') AS Pais;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: Banco Mundial con un pais que ignora mrnev ===';
-- Resultado esperado: Austria, en menos de 2048 bytes, con la fila del anio mas nuevo.
BEGIN TRY
    EXEC Importacion.usp_ObtenerUrl @Url = 'https://api.worldbank.org/v2/country/AUT/indicator/NY.GDP.PCAP.CD?format=json&mrnev=1&per_page=1', @Respuesta = @respuesta OUTPUT;
    SELECT DATALENGTH(@respuesta) AS Bytes, ISJSON(@respuesta) AS EsJson, JSON_VALUE(@respuesta, '$[1][0].countryiso3code') AS Pais, JSON_VALUE(@respuesta, '$[1][0].date') AS Anio;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO
