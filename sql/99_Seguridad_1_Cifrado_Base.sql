/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-16
 Script       : 99_Seguridad_1_Cifrado_Base.sql
 Objetivo     : Base del cifrado de datos personales (nombre, apellido y fecha de nacimiento de
                Jugador, CuerpoTecnico y Arbitro) con una clave simetrica AES_256 protegida
                por un certificado.
                  - Crea la llave maestra de la base, el certificado y la clave.
                  - Crea las funciones que descifran, que se ejecutan con los permisos del
                    propietario: el acceso a los datos en claro se controla con los permisos
                    sobre las tablas y sobre los SP, no repartiendo permisos sobre el
                    certificado.
                  - Agrega a las tres tablas las columnas VARBINARY cifradas y cifra los
                    datos existentes, por conjuntos.
                Las columnas en claro se reemplazan en 99_Seguridad_2_Cifrado_Torneo.sql
                (Jugador y CuerpoTecnico) y 99_Seguridad_3_Cifrado_Arbitraje.sql (Arbitro).
                Los scripts 1 a 3 se pueden ejecutar mas de una vez. Este quita las columnas
                calculadas para poder redefinir las funciones y las recrean los scripts 2 y 3,
                por eso los tres se ejecutan en orden.
 Requisito    : ejecutar despues de 99_Datos_Aceptacion.sql y 99_Demo_Reportes.sql. El esquema
                Seguridad se crea en 01_Base_Esquemas.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*------------------------------------------------------------------------------
 CONFIGURACION DEL CIFRADO
 La llave maestra de la base se crea con una contrasena que llega por parametro.
 JUSTIFICACION DEL SQL DINAMICO: CREATE MASTER KEY solo acepta la contrasena como
 literal, no como variable. La cadena se arma solo con el parametro, que antes se
 valida (largo minimo y sin comillas simples).
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Seguridad.usp_ConfigurarCifrado
    @ClaveMaestra VARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sql VARCHAR(400);

    IF @ClaveMaestra IS NULL OR LEN(@ClaveMaestra) < 12
        SET @errores += 'La clave maestra debe tener al menos 12 caracteres. ';
    ELSE IF CHARINDEX('''', @ClaveMaestra) > 0
        SET @errores += 'La clave maestra no puede contener comillas simples. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    BEGIN
        SET @sql = 'CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + @ClaveMaestra + '''';
        EXEC (@sql);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'CertDatosPersonales')
        CREATE CERTIFICATE CertDatosPersonales
            WITH SUBJECT = 'Datos personales del torneo';

    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'ClaveDatosPersonales')
        CREATE SYMMETRIC KEY ClaveDatosPersonales
            WITH ALGORITHM = AES_256
            ENCRYPTION BY CERTIFICATE CertDatosPersonales;
END
GO

EXEC Seguridad.usp_ConfigurarCifrado @ClaveMaestra = 'Demo-Cifrado-2026-SoloParaDemostracion';
GO

/*------------------------------------------------------------------------------
 COLUMNAS CIFRADAS
------------------------------------------------------------------------------*/
IF COL_LENGTH('Torneo.Jugador', 'NombreCifrado') IS NULL
    ALTER TABLE Torneo.Jugador ADD NombreCifrado VARBINARY(256) NULL,
                                   ApellidoCifrado VARBINARY(256) NULL,
                                   FechaNacimientoCifrada VARBINARY(256) NULL;
GO

IF COL_LENGTH('Torneo.CuerpoTecnico', 'NombreCifrado') IS NULL
    ALTER TABLE Torneo.CuerpoTecnico ADD NombreCifrado VARBINARY(256) NULL,
                                         ApellidoCifrado VARBINARY(256) NULL;
GO

IF COL_LENGTH('Arbitraje.Arbitro', 'NombreCifrado') IS NULL
    ALTER TABLE Arbitraje.Arbitro ADD NombreCifrado VARBINARY(256) NULL,
                                      ApellidoCifrado VARBINARY(256) NULL,
                                      FechaNacimientoCifrada VARBINARY(256) NULL;
GO

/*------------------------------------------------------------------------------
 CIFRADO DE LOS DATOS EXISTENTES (por conjuntos, solo filas sin cifrar)
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Seguridad.usp_CifrarDatosPersonales
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @resumen TABLE (Tabla VARCHAR(40), FilasCifradas INT);
    DECLARE @n INT;

    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        UPDATE Torneo.Jugador
        SET NombreCifrado          = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), Nombre),
            ApellidoCifrado        = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), Apellido),
            FechaNacimientoCifrada = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), CONVERT(VARCHAR(10), FechaNacimiento, 23))
        WHERE NombreCifrado IS NULL;
        SET @n = @@ROWCOUNT;
        INSERT INTO @resumen VALUES ('Torneo.Jugador', @n);

        UPDATE Torneo.CuerpoTecnico
        SET NombreCifrado   = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), Nombre),
            ApellidoCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), Apellido)
        WHERE NombreCifrado IS NULL;
        SET @n = @@ROWCOUNT;
        INSERT INTO @resumen VALUES ('Torneo.CuerpoTecnico', @n);

        UPDATE Arbitraje.Arbitro
        SET NombreCifrado          = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), Nombre),
            ApellidoCifrado        = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), Apellido),
            FechaNacimientoCifrada = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), CONVERT(VARCHAR(10), FechaNacimiento, 23))
        WHERE NombreCifrado IS NULL;
        SET @n = @@ROWCOUNT;
        INSERT INTO @resumen VALUES ('Arbitraje.Arbitro', @n);

        COMMIT TRANSACTION;
        CLOSE SYMMETRIC KEY ClaveDatosPersonales;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales')
            CLOSE SYMMETRIC KEY ClaveDatosPersonales;
        THROW;
    END CATCH

    SELECT Tabla, FilasCifradas FROM @resumen;
END
GO

/*------------------------------------------------------------------------------
 PASO PREVIO PARA PODER REPETIR EL SCRIPT
 Las funciones de descifrado no se pueden redefinir mientras una columna calculada
 las use. Se quitan las columnas calculadas (el dato cifrado no se toca) y mas abajo
 se vuelven a crear.
------------------------------------------------------------------------------*/
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Torneo.Jugador') AND name = 'Nombre' AND is_computed = 1)
    ALTER TABLE Torneo.Jugador DROP COLUMN Nombre, Apellido, FechaNacimiento;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Torneo.CuerpoTecnico') AND name = 'Nombre' AND is_computed = 1)
    ALTER TABLE Torneo.CuerpoTecnico DROP COLUMN Nombre, Apellido;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitro') AND name = 'Nombre' AND is_computed = 1)
    ALTER TABLE Arbitraje.Arbitro DROP COLUMN Nombre, Apellido, FechaNacimiento;
GO

-- Descifrado. Se ejecutan con los permisos del propietario, que es quien tiene acceso
-- al certificado: el acceso a los datos en claro se controla con el permiso sobre la
-- tabla y sobre los SP, no repartiendo permisos sobre el certificado.
CREATE OR ALTER FUNCTION Seguridad.fn_DescifrarTexto (@Dato VARBINARY(256))
RETURNS VARCHAR(80)
WITH EXECUTE AS OWNER
AS
BEGIN
    RETURN CAST(DECRYPTBYKEYAUTOCERT(CERT_ID('CertDatosPersonales'), NULL, @Dato) AS VARCHAR(80));
END
GO

CREATE OR ALTER FUNCTION Seguridad.fn_DescifrarFecha (@Dato VARBINARY(256))
RETURNS DATE
WITH EXECUTE AS OWNER
AS
BEGIN
    RETURN TRY_CONVERT(DATE, CAST(DECRYPTBYKEYAUTOCERT(CERT_ID('CertDatosPersonales'), NULL, @Dato) AS VARCHAR(10)), 23);
END
GO

-- Solo si todavia quedan datos personales en claro (la primera vez).
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Torneo.Jugador') AND name = 'Nombre' AND is_computed = 0)
   OR EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Torneo.CuerpoTecnico') AND name = 'Nombre' AND is_computed = 0)
   OR EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitro') AND name = 'Nombre' AND is_computed = 0)
    EXEC Seguridad.usp_CifrarDatosPersonales;
GO
