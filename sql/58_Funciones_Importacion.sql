/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 58_Funciones_Importacion.sql
 Objetivo     : Funciones que usan los procesos de importacion:
                  Importacion.fn_CantidadCamposCsv  cuantos campos tiene una linea de un CSV.
                  Importacion.fn_CampoCsv           un campo de una linea de un CSV.
                  Importacion.fn_CodigoPaisFuente   codigo de pais a partir del nombre en ingles.
 Prerrequisito: 01_Base_Esquemas.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Importacion.fn_CantidadCamposCsv
 Una coma entre comillas no separa campos. Devuelve 0 si hay comillas sin cerrar.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Importacion.fn_CantidadCamposCsv (@Linea VARCHAR(MAX))
RETURNS INT
AS
BEGIN
    DECLARE @i INT = 1, @largo INT = DATALENGTH(@Linea), @campos INT = 1, @enComillas BIT = 0;
    DECLARE @caracter CHAR(1);

    WHILE @i <= @largo
    BEGIN
        SET @caracter = SUBSTRING(@Linea, @i, 1);

        IF @caracter = '"'
            SET @enComillas = 1 - @enComillas;
        ELSE IF @caracter = ',' AND @enComillas = 0
            SET @campos += 1;

        SET @i += 1;
    END;

    IF @enComillas = 1
        RETURN 0;

    RETURN @campos;
END
GO

/*------------------------------------------------------------------------------
 Importacion.fn_CampoCsv
 Devuelve el campo numero @Numero (el primero es el 1), sin las comillas que lo
 rodean. Dentro de comillas, dos comillas seguidas son una comilla. NULL si la
 linea no tiene ese campo.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Importacion.fn_CampoCsv (@Linea VARCHAR(MAX), @Numero INT)
RETURNS VARCHAR(8000)
AS
BEGIN
    DECLARE @i INT = 1, @largo INT = DATALENGTH(@Linea), @campo INT = 1, @enComillas BIT = 0;
    DECLARE @caracter CHAR(1), @resultado VARCHAR(8000) = '';

    WHILE @i <= @largo
    BEGIN
        SET @caracter = SUBSTRING(@Linea, @i, 1);

        IF @caracter = '"'
        BEGIN
            IF @enComillas = 1 AND SUBSTRING(@Linea, @i + 1, 1) = '"'
            BEGIN
                IF @campo = @Numero
                    SET @resultado += '"';
                SET @i += 1;
            END
            ELSE
                SET @enComillas = 1 - @enComillas;
        END
        ELSE IF @caracter = ',' AND @enComillas = 0
        BEGIN
            IF @campo = @Numero
                RETURN @resultado;
            SET @campo += 1;
        END
        ELSE IF @campo = @Numero
            SET @resultado += @caracter;

        SET @i += 1;
    END;

    IF @campo = @Numero
        RETURN @resultado;

    RETURN NULL;
END
GO

/*------------------------------------------------------------------------------
 Importacion.fn_CodigoPaisFuente
 Lista fija de nombres en ingles y su codigo en Torneo.Pais. NULL si no hay
 equivalencia. Paises Bajos y Portugal usan NED y POR, los codigos de Torneo.Pais.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Importacion.fn_CodigoPaisFuente (@NombrePais VARCHAR(80))
RETURNS CHAR(3)
AS
BEGIN
    RETURN CASE LTRIM(RTRIM(@NombrePais))
               WHEN 'Argentina'        THEN 'ARG'
               WHEN 'Australia'        THEN 'AUS'
               WHEN 'Austria'          THEN 'AUT'
               WHEN 'Belgium'          THEN 'BEL'
               WHEN 'Brazil'           THEN 'BRA'
               WHEN 'Canada'           THEN 'CAN'
               WHEN 'Colombia'         THEN 'COL'
               WHEN 'Croatia'          THEN 'HRV'
               WHEN 'Denmark'          THEN 'DNK'
               WHEN 'Ecuador'          THEN 'ECU'
               WHEN 'Egypt'            THEN 'EGY'
               WHEN 'France'           THEN 'FRA'
               WHEN 'Germany'          THEN 'DEU'
               WHEN 'West Germany'     THEN 'DEU'
               WHEN 'Ghana'            THEN 'GHA'
               WHEN 'Italy'            THEN 'ITA'
               WHEN 'Japan'            THEN 'JPN'
               WHEN 'Mexico'           THEN 'MEX'
               WHEN 'Morocco'          THEN 'MAR'
               WHEN 'Netherlands'      THEN 'NED'
               WHEN 'Norway'           THEN 'NOR'
               WHEN 'Panama'           THEN 'PAN'
               WHEN 'Paraguay'         THEN 'PRY'
               WHEN 'Portugal'         THEN 'POR'
               WHEN 'Senegal'          THEN 'SEN'
               WHEN 'South Korea'      THEN 'KOR'
               WHEN 'Spain'            THEN 'ESP'
               WHEN 'Switzerland'      THEN 'CHE'
               WHEN 'Turkey'           THEN 'TUR'
               WHEN 'United States'    THEN 'USA'
               WHEN 'Uruguay'          THEN 'URY'
               WHEN 'England'          THEN 'GBR'
               WHEN 'Scotland'         THEN 'GBR'
               WHEN 'Wales'            THEN 'GBR'
               WHEN 'Northern Ireland' THEN 'GBR'
           END;
END
GO
