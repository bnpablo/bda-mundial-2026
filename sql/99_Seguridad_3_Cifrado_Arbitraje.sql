/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-24
 Script       : 99_Seguridad_3_Cifrado_Arbitraje.sql
 Objetivo     : Reemplaza las columnas en claro de Arbitraje.Arbitro por columnas calculadas con el
                mismo nombre (Nombre, Apellido y FechaNacimiento) que descifran la columna
                cifrada. Las consultas existentes, la importacion de arbitros y los reportes no
                cambian. Nunca elimina las columnas en claro si queda alguna fila sin cifrar.
                Reemplaza los SP de alta y modificacion de Arbitro: mismas validaciones que
                antes, pero cifran al escribir y se ejecutan con los permisos del propietario.
 Requisito    : ejecutar despues de 99_Seguridad_1_Cifrado_Base.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*------------------------------------------------------------------------------
 REEMPLAZO DE LAS COLUMNAS EN CLARO POR COLUMNAS CALCULADAS
------------------------------------------------------------------------------*/
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitro') AND name = 'Nombre' AND is_computed = 0)
BEGIN
    IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE NombreCifrado IS NULL OR ApellidoCifrado IS NULL)
        THROW 50001, 'Hay filas sin cifrar: no se eliminan las columnas en claro. ', 1;
    ALTER TABLE Arbitraje.Arbitro ALTER COLUMN NombreCifrado VARBINARY(256) NOT NULL;
    ALTER TABLE Arbitraje.Arbitro ALTER COLUMN ApellidoCifrado VARBINARY(256) NOT NULL;
    ALTER TABLE Arbitraje.Arbitro DROP COLUMN Nombre, Apellido, FechaNacimiento;
END;

IF COL_LENGTH('Arbitraje.Arbitro', 'Nombre') IS NULL
    ALTER TABLE Arbitraje.Arbitro ADD Nombre          AS Seguridad.fn_DescifrarTexto(NombreCifrado),
                                      Apellido        AS Seguridad.fn_DescifrarTexto(ApellidoCifrado),
                                      FechaNacimiento AS Seguridad.fn_DescifrarFecha(FechaNacimientoCifrada);
GO


/*------------------------------------------------------------------------------
 SP DE ESCRITURA CON CIFRADO (mismas validaciones que los originales)
 Abren la clave solo si no estaba abierta y la cierran al terminar o ante un error.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Arbitraje.usp_Arbitro_Alta
    @CodigoExterno   VARCHAR(30),
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @IdPais          INT,
    @Categoria       VARCHAR(20),
    @FechaNacimiento DATE = NULL,
    @IdArbitro       INT  = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @claveAbierta BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') THEN 1 ELSE 0 END;

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe un arbitro con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @Categoria IS NULL OR @Categoria NOT IN ('FIFA', 'Confederacion')
        SET @errores += 'La categoria debe ser FIFA o Confederacion. ';

    IF @FechaNacimiento > DATEADD(YEAR, -18, CAST(GETDATE() AS DATE))
        SET @errores += 'El arbitro debe ser mayor de 18 anios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        IF @claveAbierta = 0
            OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        INSERT INTO Arbitraje.Arbitro (CodigoExterno, NombreCifrado, ApellidoCifrado, FechaNacimientoCifrada, IdPais, Categoria)
        VALUES (LTRIM(RTRIM(@CodigoExterno)),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Nombre))),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Apellido))),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), CONVERT(VARCHAR(10), @FechaNacimiento, 23)),
                @IdPais, @Categoria);

        SET @IdArbitro = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        IF @claveAbierta = 0
            CLOSE SYMMETRIC KEY ClaveDatosPersonales;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF @claveAbierta = 0 AND EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales')
            CLOSE SYMMETRIC KEY ClaveDatosPersonales;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Arbitraje.usp_Arbitro_Modificacion
    @IdArbitro       INT,
    @CodigoExterno   VARCHAR(30),
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @IdPais          INT,
    @Categoria       VARCHAR(20),
    @FechaNacimiento DATE = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @claveAbierta BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') THEN 1 ELSE 0 END;

    IF @IdArbitro IS NULL OR NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro)
        SET @errores += 'El arbitro indicado no existe. ';

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro
                    WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdArbitro <> @IdArbitro)
        SET @errores += 'Ya existe otro arbitro con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';

    IF @Categoria IS NULL OR @Categoria NOT IN ('FIFA', 'Confederacion')
        SET @errores += 'La categoria debe ser FIFA o Confederacion. ';

    IF @FechaNacimiento > DATEADD(YEAR, -18, CAST(GETDATE() AS DATE))
        SET @errores += 'El arbitro debe ser mayor de 18 anios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF EXISTS (SELECT 1
               FROM Arbitraje.DesignacionArbitral d
               JOIN Torneo.Partido p ON p.IdPartido = d.IdPartido
               JOIN Torneo.Seleccion s ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
               WHERE d.IdArbitro = @IdArbitro
                 AND p.Estado <> 'Finalizado'
                 AND s.IdPais = @IdPais)
        THROW 50002, 'Con el nuevo pais el arbitro tendria la misma nacionalidad que una seleccion de un partido en el que esta designado. ', 1;

    BEGIN TRY
        IF @claveAbierta = 0
            OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        UPDATE Arbitraje.Arbitro
        SET CodigoExterno          = LTRIM(RTRIM(@CodigoExterno)),
            NombreCifrado          = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Nombre))),
            ApellidoCifrado        = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Apellido))),
            FechaNacimientoCifrada = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), CONVERT(VARCHAR(10), @FechaNacimiento, 23)),
            IdPais                 = @IdPais,
            Categoria              = @Categoria
        WHERE IdArbitro = @IdArbitro;

        COMMIT TRANSACTION;
        IF @claveAbierta = 0
            CLOSE SYMMETRIC KEY ClaveDatosPersonales;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF @claveAbierta = 0 AND EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales')
            CLOSE SYMMETRIC KEY ClaveDatosPersonales;
        THROW;
    END CATCH
END
GO
