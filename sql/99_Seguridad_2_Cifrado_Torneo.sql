/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-16
 Script       : 99_Seguridad_2_Cifrado_Torneo.sql
 Objetivo     : Reemplaza las columnas en claro de Torneo.Jugador y Torneo.CuerpoTecnico por
                columnas calculadas con el mismo nombre (Nombre, Apellido y, en Jugador,
                FechaNacimiento) que descifran la columna cifrada. Las consultas existentes no
                cambian. Nunca elimina las columnas en claro si queda alguna fila sin cifrar.
                Reemplaza los SP de alta y modificacion de Jugador y CuerpoTecnico: mismas
                validaciones que antes, pero cifran al escribir y se ejecutan con los permisos
                del propietario, asi quien los invoca no necesita permisos sobre la clave.
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
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Torneo.Jugador') AND name = 'Nombre' AND is_computed = 0)
BEGIN
    IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE NombreCifrado IS NULL OR ApellidoCifrado IS NULL)
        THROW 50001, 'Hay filas sin cifrar: no se eliminan las columnas en claro. ', 1;
    ALTER TABLE Torneo.Jugador ALTER COLUMN NombreCifrado VARBINARY(256) NOT NULL;
    ALTER TABLE Torneo.Jugador ALTER COLUMN ApellidoCifrado VARBINARY(256) NOT NULL;
    ALTER TABLE Torneo.Jugador DROP COLUMN Nombre, Apellido, FechaNacimiento;
END;

IF COL_LENGTH('Torneo.Jugador', 'Nombre') IS NULL
    ALTER TABLE Torneo.Jugador ADD Nombre          AS Seguridad.fn_DescifrarTexto(NombreCifrado),
                                   Apellido        AS Seguridad.fn_DescifrarTexto(ApellidoCifrado),
                                   FechaNacimiento AS Seguridad.fn_DescifrarFecha(FechaNacimientoCifrada);
GO


IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Torneo.CuerpoTecnico') AND name = 'Nombre' AND is_computed = 0)
BEGIN
    IF EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE NombreCifrado IS NULL OR ApellidoCifrado IS NULL)
        THROW 50001, 'Hay filas sin cifrar: no se eliminan las columnas en claro. ', 1;
    ALTER TABLE Torneo.CuerpoTecnico ALTER COLUMN NombreCifrado VARBINARY(256) NOT NULL;
    ALTER TABLE Torneo.CuerpoTecnico ALTER COLUMN ApellidoCifrado VARBINARY(256) NOT NULL;
    ALTER TABLE Torneo.CuerpoTecnico DROP COLUMN Nombre, Apellido;
END;

IF COL_LENGTH('Torneo.CuerpoTecnico', 'Nombre') IS NULL
    ALTER TABLE Torneo.CuerpoTecnico ADD Nombre   AS Seguridad.fn_DescifrarTexto(NombreCifrado),
                                         Apellido AS Seguridad.fn_DescifrarTexto(ApellidoCifrado);
GO


/*------------------------------------------------------------------------------
 SP DE ESCRITURA CON CIFRADO (mismas validaciones que los originales)
 Abren la clave solo si no estaba abierta y la cierran al terminar o ante un error.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Torneo.usp_Jugador_Alta
    @CodigoExterno    VARCHAR(30),
    @Nombre           VARCHAR(80),
    @Apellido         VARCHAR(80),
    @IdPais           INT,
    @IdSeleccion      INT,
    @Dorsal           INT,
    @PosicionHabitual VARCHAR(5),
    @ClubOrigen       VARCHAR(120),
    @FechaAlta        DATE,
    @FechaNacimiento  DATE = NULL,
    @IdJugador        INT  = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxConvocados INT = 26;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @claveAbierta BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') THEN 1 ELSE 0 END;

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Jugador WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)))
        SET @errores += 'Ya existe un jugador con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @FechaNacimiento IS NOT NULL AND @FechaNacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais (nacionalidad) indicado no existe. ';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';
    ELSE
    BEGIN
        IF @Dorsal IS NOT NULL
           AND EXISTS (SELECT 1 FROM Torneo.Jugador WHERE IdSeleccion = @IdSeleccion AND Dorsal = @Dorsal)
            SET @errores += 'Ese dorsal ya fue asignado en la seleccion. ';

        IF (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @IdSeleccion AND FechaBaja IS NULL) >= @maxConvocados
            SET @errores += 'La seleccion ya tiene el maximo de ' + CAST(@maxConvocados AS VARCHAR(5))
                          + ' convocados. ';
    END;

    IF @Dorsal IS NULL OR @Dorsal NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal debe estar entre 1 y 99. ';

    IF @PosicionHabitual IS NULL OR @PosicionHabitual NOT IN ('POR', 'DEF', 'MED', 'DEL')
        SET @errores += 'La posicion habitual debe ser POR, DEF, MED o DEL. ';

    IF @ClubOrigen IS NULL OR LTRIM(RTRIM(@ClubOrigen)) = ''
        SET @errores += 'El club de origen es obligatorio. ';

    IF @FechaAlta IS NULL
        SET @errores += 'La fecha de alta en la convocatoria es obligatoria. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        IF @claveAbierta = 0
            OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        INSERT INTO Torneo.Jugador (CodigoExterno, NombreCifrado, ApellidoCifrado, FechaNacimientoCifrada, IdPais, IdSeleccion,
                                    Dorsal, PosicionHabitual, ClubOrigen, FechaAlta)
        VALUES (LTRIM(RTRIM(@CodigoExterno)),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Nombre))),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Apellido))),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), CONVERT(VARCHAR(10), @FechaNacimiento, 23)),
                @IdPais, @IdSeleccion, @Dorsal, @PosicionHabitual, LTRIM(RTRIM(@ClubOrigen)), @FechaAlta);

        SET @IdJugador = SCOPE_IDENTITY();

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

CREATE OR ALTER PROCEDURE Torneo.usp_Jugador_Modificacion
    @IdJugador        INT,
    @CodigoExterno    VARCHAR(30),
    @Nombre           VARCHAR(80),
    @Apellido         VARCHAR(80),
    @IdPais           INT,
    @IdSeleccion      INT,
    @Dorsal           INT,
    @PosicionHabitual VARCHAR(5),
    @ClubOrigen       VARCHAR(120),
    @FechaAlta        DATE,
    @FechaNacimiento  DATE = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @seleccionActual INT, @fechaBajaActual DATE;
    DECLARE @claveAbierta BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') THEN 1 ELSE 0 END;

    SELECT @seleccionActual = IdSeleccion, @fechaBajaActual = FechaBaja
    FROM Torneo.Jugador
    WHERE IdJugador = @IdJugador;

    IF @seleccionActual IS NULL
        SET @errores += 'El jugador indicado no existe. ';
    ELSE
    BEGIN
        IF @fechaBajaActual IS NOT NULL
            SET @errores += 'El jugador esta dado de baja y no puede modificarse. ';
        IF @IdSeleccion IS NULL OR @IdSeleccion <> @seleccionActual
            SET @errores += 'No se puede cambiar la seleccion de un jugador: elimine el jugador y registre una nueva alta. ';
        ELSE IF @Dorsal IS NOT NULL
             AND EXISTS (SELECT 1 FROM Torneo.Jugador
                         WHERE IdSeleccion = @IdSeleccion AND Dorsal = @Dorsal AND IdJugador <> @IdJugador)
            SET @errores += 'Ese dorsal ya fue asignado en la seleccion. ';
    END;

    IF @CodigoExterno IS NULL OR LTRIM(RTRIM(@CodigoExterno)) = ''
        SET @errores += 'El codigo externo es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Torneo.Jugador
                    WHERE CodigoExterno = LTRIM(RTRIM(@CodigoExterno)) AND IdJugador <> @IdJugador)
        SET @errores += 'Ya existe otro jugador con ese codigo externo. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @FechaNacimiento IS NOT NULL AND @FechaNacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais (nacionalidad) indicado no existe. ';

    IF @Dorsal IS NULL OR @Dorsal NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal debe estar entre 1 y 99. ';

    IF @PosicionHabitual IS NULL OR @PosicionHabitual NOT IN ('POR', 'DEF', 'MED', 'DEL')
        SET @errores += 'La posicion habitual debe ser POR, DEF, MED o DEL. ';

    IF @ClubOrigen IS NULL OR LTRIM(RTRIM(@ClubOrigen)) = ''
        SET @errores += 'El club de origen es obligatorio. ';

    IF @FechaAlta IS NULL
        SET @errores += 'La fecha de alta en la convocatoria es obligatoria. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        IF @claveAbierta = 0
            OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        UPDATE Torneo.Jugador
        SET CodigoExterno          = LTRIM(RTRIM(@CodigoExterno)),
            NombreCifrado          = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Nombre))),
            ApellidoCifrado        = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Apellido))),
            FechaNacimientoCifrada = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), CONVERT(VARCHAR(10), @FechaNacimiento, 23)),
            IdPais                 = @IdPais,
            Dorsal                 = @Dorsal,
            PosicionHabitual       = @PosicionHabitual,
            ClubOrigen             = LTRIM(RTRIM(@ClubOrigen)),
            FechaAlta              = @FechaAlta
        WHERE IdJugador = @IdJugador;

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

CREATE OR ALTER PROCEDURE Torneo.usp_CuerpoTecnico_Alta
    @IdSeleccion     INT,
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @Rol             VARCHAR(30),
    @IdCuerpoTecnico INT = NULL OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @claveAbierta BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') THEN 1 ELSE 0 END;

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @Rol IS NULL OR @Rol NOT IN ('Director tecnico', 'Ayudante')
        SET @errores += 'El rol debe ser Director tecnico o Ayudante. ';
    ELSE IF @Rol = 'Director tecnico'
        AND EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE IdSeleccion = @IdSeleccion AND Rol = 'Director tecnico')
        SET @errores += 'La seleccion ya tiene un director tecnico. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        IF @claveAbierta = 0
            OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        INSERT INTO Torneo.CuerpoTecnico (IdSeleccion, NombreCifrado, ApellidoCifrado, Rol)
        VALUES (@IdSeleccion,
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Nombre))),
                ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Apellido))),
                @Rol);

        SET @IdCuerpoTecnico = SCOPE_IDENTITY();

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

CREATE OR ALTER PROCEDURE Torneo.usp_CuerpoTecnico_Modificacion
    @IdCuerpoTecnico INT,
    @IdSeleccion     INT,
    @Nombre          VARCHAR(80),
    @Apellido        VARCHAR(80),
    @Rol             VARCHAR(30)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @claveAbierta BIT = CASE WHEN EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveDatosPersonales') THEN 1 ELSE 0 END;

    IF @IdCuerpoTecnico IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico)
        SET @errores += 'El integrante del cuerpo tecnico indicado no existe. ';

    IF @IdSeleccion IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre es obligatorio. ';

    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        SET @errores += 'El apellido es obligatorio. ';

    IF @Rol IS NULL OR @Rol NOT IN ('Director tecnico', 'Ayudante')
        SET @errores += 'El rol debe ser Director tecnico o Ayudante. ';
    ELSE IF @Rol = 'Director tecnico'
        AND EXISTS (SELECT 1 FROM Torneo.CuerpoTecnico
                    WHERE IdSeleccion = @IdSeleccion AND Rol = 'Director tecnico'
                      AND IdCuerpoTecnico <> @IdCuerpoTecnico)
        SET @errores += 'La seleccion ya tiene un director tecnico. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        IF @claveAbierta = 0
            OPEN SYMMETRIC KEY ClaveDatosPersonales DECRYPTION BY CERTIFICATE CertDatosPersonales;
        BEGIN TRANSACTION;

        UPDATE Torneo.CuerpoTecnico
        SET IdSeleccion     = @IdSeleccion,
            NombreCifrado   = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Nombre))),
            ApellidoCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveDatosPersonales'), LTRIM(RTRIM(@Apellido))),
            Rol             = @Rol
        WHERE IdCuerpoTecnico = @IdCuerpoTecnico;

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
