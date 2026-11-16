/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-05
 Script       : 66_SP_Importacion_Arbitros_Csv.sql
 Objetivo     : Importa los arbitros historicos del archivo referees.csv en
                Arbitraje.Arbitro, con los SP de 50_SP_ABM_Arbitraje.sql.
 Prerrequisito: 50_SP_ABM_Arbitraje.sql, 58_Funciones_Importacion.sql y
                63_SP_Importacion_Comun.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Importacion.usp_ImportarArbitrosCsv
 Recibe @NombreArchivo o @Contenido (el texto, para probar sin archivo).
 - Upsert por CodigoExterno: alta si no existe, modificacion si cambio el nombre,
   el apellido o el pais, y nada si no cambio.
 - Las filas invalidas se anotan en #errores y las demas se procesan. Al final
   muestra el resumen y los errores.
 Errores: 50001 parametros invalidos; 50003 archivo inaccesible o encabezado
 distinto; 50004 importacion parcial.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Importacion.usp_ImportarArbitrosCsv
    @NombreArchivo VARCHAR(260) = NULL,
    @Contenido     VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @encabezado VARCHAR(500) = 'key_id,referee_id,family_name,given_name,female,country_name,confederation_id,confederation_name,confederation_code,referee_wikipedia_link';
    DECLARE @camposEsperados INT = 10;
    DECLARE @categoriaAlta VARCHAR(20) = 'FIFA';

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @i INT = 1, @cantidadFilas INT;
    DECLARE @nuevas INT = 0, @actualizadas INT = 0, @sinCambios INT = 0, @conError INT;
    DECLARE @mensaje VARCHAR(2000);

    DECLARE @fila INT, @linea VARCHAR(MAX), @campos INT;
    DECLARE @codigo VARCHAR(8000), @apellido VARCHAR(8000), @nombre VARCHAR(8000), @pais VARCHAR(8000);
    DECLARE @codigoPais CHAR(3), @idPais INT;

    DECLARE @idArbitro INT, @nombreActual VARCHAR(80), @apellidoActual VARCHAR(80), @idPaisActual INT;
    DECLARE @categoriaActual VARCHAR(20), @nacimientoActual DATE;

    -- Sin transaccion general: un ROLLBACK de un SP desharia tambien las filas validas.
    IF @@TRANCOUNT > 0
        SET @errores += 'La importacion no se puede ejecutar dentro de una transaccion abierta. ';

    IF @NombreArchivo IS NULL AND @Contenido IS NULL
        SET @errores += 'Hay que indicar el nombre del archivo o el contenido. ';
    ELSE IF @NombreArchivo IS NOT NULL AND @Contenido IS NOT NULL
        SET @errores += 'Hay que indicar el nombre del archivo o el contenido, no los dos. ';
    ELSE IF @NombreArchivo IS NOT NULL AND RIGHT(RTRIM(@NombreArchivo), 4) <> '.csv'
        SET @errores += 'El archivo debe tener extension .csv. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @NombreArchivo IS NOT NULL
        EXEC Importacion.usp_LeerArchivo @NombreArchivo = @NombreArchivo, @Contenido = @Contenido OUTPUT;

    -- COLLATE DATABASE_DEFAULT: sin esto, las columnas toman la intercalacion de tempdb, que puede ser distinta.
    CREATE TABLE #filas (
        Orden    INT IDENTITY(1, 1) PRIMARY KEY,
        Fila     INT,
        Linea    VARCHAR(MAX)  COLLATE DATABASE_DEFAULT,
        Campos   INT,
        Codigo   VARCHAR(8000) COLLATE DATABASE_DEFAULT,
        Apellido VARCHAR(8000) COLLATE DATABASE_DEFAULT,
        Nombre   VARCHAR(8000) COLLATE DATABASE_DEFAULT,
        Pais     VARCHAR(8000) COLLATE DATABASE_DEFAULT
    );

    CREATE TABLE #errores (
        Fila       INT,
        Clave      VARCHAR(30)   COLLATE DATABASE_DEFAULT,
        Numero     INT,
        Mensaje    VARCHAR(2000) COLLATE DATABASE_DEFAULT,
        TextoCrudo VARCHAR(500)  COLLATE DATABASE_DEFAULT
    );

    IF NOT EXISTS (SELECT 1
                   FROM STRING_SPLIT(@Contenido, CHAR(10), 1)
                   WHERE ordinal = 1
                     AND REPLACE(value, CHAR(13), '') = @encabezado)
        THROW 50003, 'El encabezado del archivo no es el esperado: no parece el dataset de arbitros. ', 1;

    INSERT INTO #filas (Fila, Linea, Campos, Codigo, Apellido, Nombre, Pais)
    SELECT s.ordinal, s.Linea,
           Importacion.fn_CantidadCamposCsv(s.Linea),
           LTRIM(RTRIM(Importacion.fn_CampoCsv(s.Linea, 2))),
           LTRIM(RTRIM(Importacion.fn_CampoCsv(s.Linea, 3))),
           LTRIM(RTRIM(Importacion.fn_CampoCsv(s.Linea, 4))),
           LTRIM(RTRIM(Importacion.fn_CampoCsv(s.Linea, 6)))
    FROM (SELECT ordinal, REPLACE(value, CHAR(13), '') AS Linea
          FROM STRING_SPLIT(@Contenido, CHAR(10), 1)
          WHERE ordinal > 1) s
    WHERE s.Linea <> ''
    ORDER BY s.ordinal;

    SET @cantidadFilas = @@ROWCOUNT;

    IF @cantidadFilas = 0
        THROW 50003, 'El archivo no tiene filas de datos. ', 1;

    WHILE @i <= @cantidadFilas
    BEGIN
        SELECT @fila = Fila, @linea = Linea, @campos = Campos,
               @codigo = Codigo, @apellido = Apellido, @nombre = Nombre, @pais = Pais
        FROM #filas
        WHERE Orden = @i;

        SET @errores = '';
        SET @idPais = NULL;
        SET @codigoPais = NULL;

        IF @campos <> @camposEsperados
            SET @errores += 'La fila tiene ' + CAST(@campos AS VARCHAR(5)) + ' columnas y se esperaban '
                          + CAST(@camposEsperados AS VARCHAR(5)) + '. ';
        ELSE
        BEGIN
            IF @codigo = ''
                SET @errores += 'El codigo externo esta vacio. ';
            ELSE IF LEN(@codigo) > 30
                SET @errores += 'El codigo externo supera los 30 caracteres. ';
            ELSE IF EXISTS (SELECT 1 FROM #filas WHERE Codigo = @codigo AND Orden < @i)
                SET @errores += 'El codigo externo esta repetido en el archivo. ';

            IF @apellido = ''
                SET @errores += 'El apellido esta vacio. ';
            ELSE IF LEN(@apellido) > 80
                SET @errores += 'El apellido supera los 80 caracteres. ';

            IF @nombre = ''
                SET @errores += 'El nombre esta vacio. ';
            ELSE IF LEN(@nombre) > 80
                SET @errores += 'El nombre supera los 80 caracteres. ';

            SET @codigoPais = Importacion.fn_CodigoPaisFuente(LEFT(@pais, 80));
            SELECT @idPais = IdPais FROM Torneo.Pais WHERE CodigoIso3 = @codigoPais;

            IF @codigoPais IS NULL
                SET @errores += 'El pais ' + LEFT(@pais, 80) + ' no tiene equivalencia. ';
            ELSE IF @idPais IS NULL
                SET @errores += 'El pais ' + LEFT(@pais, 80) + ' no esta cargado en Torneo.Pais. ';
        END;

        IF @errores <> ''
            INSERT INTO #errores (Fila, Clave, Numero, Mensaje, TextoCrudo)
            VALUES (@fila, LEFT(@codigo, 30), 50001, @errores, LEFT(@linea, 500));
        ELSE
        BEGIN
            -- Un SELECT sin filas no cambia la variable: sin esto quedaria el arbitro de la vuelta anterior.
            SET @idArbitro = NULL;

            SELECT @idArbitro = IdArbitro, @nombreActual = Nombre, @apellidoActual = Apellido, @idPaisActual = IdPais,
                   @categoriaActual = Categoria, @nacimientoActual = FechaNacimiento
            FROM Arbitraje.Arbitro
            WHERE CodigoExterno = @codigo;

            BEGIN TRY
                IF @idArbitro IS NULL
                BEGIN
                    EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = @codigo, @Nombre = @nombre, @Apellido = @apellido,
                         @IdPais = @idPais, @Categoria = @categoriaAlta;
                    SET @nuevas += 1;
                END
                ELSE IF @nombre = @nombreActual AND @apellido = @apellidoActual AND @idPais = @idPaisActual
                    SET @sinCambios += 1;
                ELSE
                BEGIN
                    -- La modificacion es completa: se reenvian la categoria y la fecha, que el archivo no trae.
                    EXEC Arbitraje.usp_Arbitro_Modificacion @IdArbitro = @idArbitro, @CodigoExterno = @codigo, @Nombre = @nombre,
                         @Apellido = @apellido, @IdPais = @idPais, @Categoria = @categoriaActual,
                         @FechaNacimiento = @nacimientoActual;
                    SET @actualizadas += 1;
                END
            END TRY
            BEGIN CATCH
                INSERT INTO #errores (Fila, Clave, Numero, Mensaje, TextoCrudo)
                VALUES (@fila, LEFT(@codigo, 30), ERROR_NUMBER(), ERROR_MESSAGE(), LEFT(@linea, 500));
            END CATCH
        END;

        SET @i += 1;
    END;

    SELECT @conError = COUNT(*) FROM #errores;

    SELECT @cantidadFilas AS Leidas, @nuevas AS Nuevas, @actualizadas AS Actualizadas,
           @sinCambios AS SinCambios, @conError AS ConError;

    SELECT Fila, Clave, Numero, Mensaje, TextoCrudo FROM #errores ORDER BY Fila;

    IF @conError > 0
    BEGIN
        SET @mensaje = 'Importacion parcial: ' + CAST(@conError AS VARCHAR(10)) + ' de ' + CAST(@cantidadFilas AS VARCHAR(10))
                     + ' filas con error. Las demas se procesaron. ';
        THROW 50004, @mensaje, 1;
    END
END
GO
