/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 60_SP_ABM_Publicidad.sql
 Objetivo     : Procedimientos de alta, baja y modificacion de Anunciante, Campania,
                Pieza, PiezaPais, TarifaPublicitaria y PublicidadPartido. Cada SP
                informa en un unico mensaje todas las validaciones que no se
                cumplen. La modificacion es completa: se envian todos los datos y
                se reemplazan todos.
 Prerrequisito: 59_Funciones_Publicidad.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 ANUNCIANTE
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_Anunciante_Alta
    @Nombre       VARCHAR(120),
    @IdAnunciante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre del anunciante es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE Nombre = LTRIM(RTRIM(@Nombre)))
        SET @errores += 'Ya existe un anunciante con ese nombre. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Publicidad.Anunciante (Nombre)
        VALUES (LTRIM(RTRIM(@Nombre)));

        SET @IdAnunciante = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Publicidad.usp_Anunciante_Modificacion
    @IdAnunciante INT,
    @Nombre       VARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdAnunciante IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante)
        SET @errores += 'El anunciante indicado no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre del anunciante es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE Nombre = LTRIM(RTRIM(@Nombre)) AND IdAnunciante <> @IdAnunciante)
        SET @errores += 'Ya existe otro anunciante con ese nombre. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.Anunciante
        SET Nombre = LTRIM(RTRIM(@Nombre))
        WHERE IdAnunciante = @IdAnunciante;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si el anunciante no tiene campanias.
CREATE OR ALTER PROCEDURE Publicidad.usp_Anunciante_Baja
    @IdAnunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdAnunciante IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante)
        SET @errores += 'El anunciante indicado no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdAnunciante = @IdAnunciante)
        SET @errores += 'El anunciante tiene campanias registradas. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 CAMPANIA
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_Campania_Alta
    @IdAnunciante INT,
    @Nombre       VARCHAR(120),
    @FechaInicio  DATE,
    @FechaFin     DATE,
    @IdCampania   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdAnunciante IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante)
        SET @errores += 'El anunciante indicado no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre de la campania es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdAnunciante = @IdAnunciante AND Nombre = LTRIM(RTRIM(@Nombre)))
        SET @errores += 'El anunciante ya tiene una campania con ese nombre. ';

    IF @FechaInicio IS NULL OR @FechaFin IS NULL
        SET @errores += 'Las fechas de inicio y fin son obligatorias. ';
    ELSE IF @FechaFin < @FechaInicio
        SET @errores += 'La fecha de fin no puede ser anterior a la de inicio. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Publicidad.Campania (IdAnunciante, Nombre, FechaInicio, FechaFin)
        VALUES (@IdAnunciante, LTRIM(RTRIM(@Nombre)), @FechaInicio, @FechaFin);

        SET @IdCampania = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Modificacion completa (el anunciante no cambia). Las fechas nuevas no pueden
-- dejar afuera partidos donde sus piezas ya tienen un espacio (no descartado).
CREATE OR ALTER PROCEDURE Publicidad.usp_Campania_Modificacion
    @IdCampania  INT,
    @Nombre      VARCHAR(120),
    @FechaInicio DATE,
    @FechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idAnunciante INT;

    SELECT @idAnunciante = IdAnunciante FROM Publicidad.Campania WHERE IdCampania = @IdCampania;

    IF @idAnunciante IS NULL
        SET @errores += 'La campania indicada no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre de la campania es obligatorio. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Campania
                    WHERE IdAnunciante = @idAnunciante AND Nombre = LTRIM(RTRIM(@Nombre)) AND IdCampania <> @IdCampania)
        SET @errores += 'El anunciante ya tiene otra campania con ese nombre. ';

    IF @FechaInicio IS NULL OR @FechaFin IS NULL
        SET @errores += 'Las fechas de inicio y fin son obligatorias. ';
    ELSE IF @FechaFin < @FechaInicio
        SET @errores += 'La fecha de fin no puede ser anterior a la de inicio. ';
    ELSE IF EXISTS (SELECT 1
                    FROM Publicidad.PublicidadPartido pp
                    JOIN Publicidad.Pieza pz ON pz.IdPieza = pp.IdPieza
                    JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
                    WHERE pz.IdCampania = @IdCampania
                      AND pp.Estado <> 'Descartada'
                      AND CAST(p.FechaHoraUtc AS DATE) NOT BETWEEN @FechaInicio AND @FechaFin)
        SET @errores += 'Con las nuevas fechas quedarian afuera partidos donde la campania ya tiene espacios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.Campania
        SET Nombre      = LTRIM(RTRIM(@Nombre)),
            FechaInicio = @FechaInicio,
            FechaFin    = @FechaFin
        WHERE IdCampania = @IdCampania;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si la campania no tiene piezas.
CREATE OR ALTER PROCEDURE Publicidad.usp_Campania_Baja
    @IdCampania INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdCampania IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdCampania = @IdCampania)
        SET @errores += 'La campania indicada no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdCampania = @IdCampania)
        SET @errores += 'La campania tiene piezas registradas. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Publicidad.Campania WHERE IdCampania = @IdCampania;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 PIEZA
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_Pieza_Alta
    @IdCampania       INT,
    @Nombre           VARCHAR(120),
    @Idioma           VARCHAR(10),
    @DuracionSegundos INT,
    @IdPieza          INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdCampania IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdCampania = @IdCampania)
        SET @errores += 'La campania indicada no existe. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre de la pieza es obligatorio. ';

    IF @Idioma IS NULL OR LTRIM(RTRIM(@Idioma)) = ''
        SET @errores += 'El idioma de la pieza es obligatorio. ';

    IF @DuracionSegundos IS NULL OR @DuracionSegundos NOT BETWEEN 1 AND 300
        SET @errores += 'La duracion debe estar entre 1 y 300 segundos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Publicidad.Pieza (IdCampania, Idioma, Nombre, DuracionSegundos)
        VALUES (@IdCampania, LOWER(LTRIM(RTRIM(@Idioma))), LTRIM(RTRIM(@Nombre)), @DuracionSegundos);

        SET @IdPieza = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Modificacion completa (la campania no cambia). Una pieza ya exhibida no se
-- modifica: es el registro de lo que salio al aire y se factura.
CREATE OR ALTER PROCEDURE Publicidad.usp_Pieza_Modificacion
    @IdPieza          INT,
    @Nombre           VARCHAR(120),
    @Idioma           VARCHAR(10),
    @DuracionSegundos INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPieza IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @errores += 'La pieza indicada no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdPieza = @IdPieza AND Estado = 'Exhibida')
        SET @errores += 'La pieza ya fue exhibida y no puede modificarse. ';

    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        SET @errores += 'El nombre de la pieza es obligatorio. ';

    IF @Idioma IS NULL OR LTRIM(RTRIM(@Idioma)) = ''
        SET @errores += 'El idioma de la pieza es obligatorio. ';

    IF @DuracionSegundos IS NULL OR @DuracionSegundos NOT BETWEEN 1 AND 300
        SET @errores += 'La duracion debe estar entre 1 y 300 segundos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.Pieza
        SET Nombre           = LTRIM(RTRIM(@Nombre)),
            Idioma           = LOWER(LTRIM(RTRIM(@Idioma))),
            DuracionSegundos = @DuracionSegundos
        WHERE IdPieza = @IdPieza;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si la pieza nunca se asigno a un partido. Sus paises
-- de interes se borran por la clave foranea ON DELETE CASCADE.
CREATE OR ALTER PROCEDURE Publicidad.usp_Pieza_Baja
    @IdPieza INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPieza IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @errores += 'La pieza indicada no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdPieza = @IdPieza)
        SET @errores += 'La pieza esta asignada a partidos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Publicidad.Pieza WHERE IdPieza = @IdPieza;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 PIEZA PAIS (paises de interes de una pieza)
 La clave es (IdPieza, IdPais): la modificacion cambia un pais por otro.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_PiezaPais_Alta
    @IdPieza INT,
    @IdPais  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdPieza IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @errores += 'La pieza indicada no existe. ';

    IF @IdPais IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @errores += 'El pais indicado no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPais)
        SET @errores += 'La pieza ya tiene cargado ese pais. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Publicidad.PiezaPais (IdPieza, IdPais)
        VALUES (@IdPieza, @IdPais);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Publicidad.usp_PiezaPais_Modificacion
    @IdPieza     INT,
    @IdPais      INT,
    @IdPaisNuevo INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPais)
        SET @errores += 'La pieza no tiene cargado el pais a modificar. ';

    IF @IdPaisNuevo IS NULL OR NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPaisNuevo)
        SET @errores += 'El pais nuevo no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPaisNuevo)
        SET @errores += 'La pieza ya tiene cargado el pais nuevo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.PiezaPais
        SET IdPais = @IdPaisNuevo
        WHERE IdPieza = @IdPieza
          AND IdPais = @IdPais;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Una pieza sin paises de interes no podria competir por ningun espacio: no se
-- quita el ultimo.
CREATE OR ALTER PROCEDURE Publicidad.usp_PiezaPais_Baja
    @IdPieza INT,
    @IdPais  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPais)
        SET @errores += 'La pieza no tiene cargado ese pais. ';
    ELSE IF (SELECT COUNT(*) FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza) = 1
        SET @errores += 'Es el unico pais de interes de la pieza: agregue otro antes de quitarlo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Publicidad.PiezaPais
        WHERE IdPieza = @IdPieza
          AND IdPais = @IdPais;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 TARIFA PUBLICITARIA
 Dos tarifas de la misma fase no pueden estar vigentes al mismo tiempo. Una
 tarifa que ya se aplico a espacios (no descartados) conserva su fase, moneda,
 monto e inicio de vigencia, para que no cambie lo ya vendido: solo se le puede
 cerrar la vigencia, y el precio nuevo se carga como otra tarifa.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_TarifaPublicitaria_Alta
    @Fase         VARCHAR(20),
    @Moneda       VARCHAR(3),
    @Monto        DECIMAL(18, 2),
    @VigenteDesde DATE,
    @VigenteHasta DATE,
    @IdTarifa     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @Fase IS NULL OR @Fase NOT IN ('Grupos', 'Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
        SET @errores += 'La fase debe ser Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final. ';

    IF @Moneda IS NULL OR @Moneda NOT LIKE '[A-Za-z][A-Za-z][A-Za-z]'
        SET @errores += 'La moneda debe ser un codigo de 3 letras (por ejemplo USD). ';

    IF @Monto IS NULL OR @Monto <= 0
        SET @errores += 'El monto debe ser mayor a cero. ';

    IF @VigenteDesde IS NULL OR @VigenteHasta IS NULL
        SET @errores += 'Las fechas de vigencia son obligatorias. ';
    ELSE IF @VigenteHasta < @VigenteDesde
        SET @errores += 'El fin de la vigencia no puede ser anterior al inicio. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.TarifaPublicitaria
                    WHERE Fase = @Fase
                      AND VigenteDesde <= @VigenteHasta
                      AND VigenteHasta >= @VigenteDesde)
        SET @errores += 'La vigencia se superpone con otra tarifa de la misma fase. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Publicidad.TarifaPublicitaria (Fase, Moneda, Monto, VigenteDesde, VigenteHasta)
        VALUES (@Fase, UPPER(@Moneda), @Monto, @VigenteDesde, @VigenteHasta);

        SET @IdTarifa = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE Publicidad.usp_TarifaPublicitaria_Modificacion
    @IdTarifa     INT,
    @Fase         VARCHAR(20),
    @Moneda       VARCHAR(3),
    @Monto        DECIMAL(18, 2),
    @VigenteDesde DATE,
    @VigenteHasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @faseActual VARCHAR(20), @monedaActual CHAR(3), @montoActual DECIMAL(18, 2), @desdeActual DATE;

    SELECT @faseActual = Fase, @monedaActual = Moneda, @montoActual = Monto, @desdeActual = VigenteDesde
    FROM Publicidad.TarifaPublicitaria
    WHERE IdTarifa = @IdTarifa;

    IF @faseActual IS NULL
        SET @errores += 'La tarifa indicada no existe. ';

    IF @Fase IS NULL OR @Fase NOT IN ('Grupos', 'Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer puesto', 'Final')
        SET @errores += 'La fase debe ser Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final. ';

    IF @Moneda IS NULL OR @Moneda NOT LIKE '[A-Za-z][A-Za-z][A-Za-z]'
        SET @errores += 'La moneda debe ser un codigo de 3 letras (por ejemplo USD). ';

    IF @Monto IS NULL OR @Monto <= 0
        SET @errores += 'El monto debe ser mayor a cero. ';

    IF @VigenteDesde IS NULL OR @VigenteHasta IS NULL
        SET @errores += 'Las fechas de vigencia son obligatorias. ';
    ELSE IF @VigenteHasta < @VigenteDesde
        SET @errores += 'El fin de la vigencia no puede ser anterior al inicio. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.TarifaPublicitaria
                    WHERE Fase = @Fase
                      AND IdTarifa <> @IdTarifa
                      AND VigenteDesde <= @VigenteHasta
                      AND VigenteHasta >= @VigenteDesde)
        SET @errores += 'La vigencia se superpone con otra tarifa de la misma fase. ';

    -- Tarifa ya usada: solo se puede cerrar su vigencia, sin dejar afuera los partidos que la usan.
    IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdTarifa = @IdTarifa AND Estado <> 'Descartada')
    BEGIN
        IF @Fase <> @faseActual OR @Moneda <> @monedaActual OR @Monto <> @montoActual OR @VigenteDesde <> @desdeActual
            SET @errores += 'La tarifa ya se aplico a espacios: solo se puede cerrar su vigencia y cargar el precio nuevo como otra tarifa. ';

        IF EXISTS (SELECT 1
                   FROM Publicidad.PublicidadPartido pp
                   JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
                   WHERE pp.IdTarifa = @IdTarifa
                     AND pp.Estado <> 'Descartada'
                     AND CAST(p.FechaHoraUtc AS DATE) > @VigenteHasta)
            SET @errores += 'La nueva vigencia deja afuera partidos que ya usan esta tarifa. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.TarifaPublicitaria
        SET Fase         = @Fase,
            Moneda       = UPPER(@Moneda),
            Monto        = @Monto,
            VigenteDesde = @VigenteDesde,
            VigenteHasta = @VigenteHasta
        WHERE IdTarifa = @IdTarifa;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si la tarifa nunca se aplico a un espacio.
CREATE OR ALTER PROCEDURE Publicidad.usp_TarifaPublicitaria_Baja
    @IdTarifa INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdTarifa IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.TarifaPublicitaria WHERE IdTarifa = @IdTarifa)
        SET @errores += 'La tarifa indicada no existe. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdTarifa = @IdTarifa)
        SET @errores += 'La tarifa esta aplicada a espacios de partidos: cierre su vigencia en lugar de eliminarla. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Publicidad.TarifaPublicitaria WHERE IdTarifa = @IdTarifa;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 PUBLICIDAD PARTIDO
 Alta manual: venta directa de un espacio. Queda Confirmada, con criterio
 'Manual' y la tarifa vigente de la fase del partido.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_PublicidadPartido_Alta
    @IdPartido           INT,
    @NumeroEspacio       INT,
    @IdPieza             INT,
    @IdPublicidadPartido INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estadoPartido VARCHAR(20), @fase VARCHAR(20), @fechaPartido DATE, @idTarifa INT;

    SELECT @estadoPartido = Estado, @fase = Fase, @fechaPartido = CAST(FechaHoraUtc AS DATE)
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    IF @estadoPartido IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE
    BEGIN
        IF @estadoPartido = 'Finalizado'
            SET @errores += 'El partido esta finalizado: no se le pueden asignar espacios. ';

        SET @idTarifa = Publicidad.fn_TarifaVigente(@fase, @fechaPartido);
        IF @idTarifa IS NULL
            SET @errores += 'No hay una tarifa vigente para la fase del partido en su fecha. ';
    END;

    IF @NumeroEspacio IS NULL OR @NumeroEspacio NOT BETWEEN 1 AND 4
        SET @errores += 'El numero de espacio debe estar entre 1 y 4. ';
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                    WHERE IdPartido = @IdPartido AND NumeroEspacio = @NumeroEspacio AND Estado <> 'Descartada')
        SET @errores += 'Ese espacio ya esta ocupado en el partido. ';

    IF @IdPieza IS NULL OR NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @errores += 'La pieza indicada no existe. ';
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                   WHERE IdPartido = @IdPartido AND IdPieza = @IdPieza AND Estado <> 'Descartada')
            SET @errores += 'La pieza ya ocupa otro espacio en el partido. ';

        IF @fechaPartido IS NOT NULL
           AND NOT EXISTS (SELECT 1
                           FROM Publicidad.Pieza pz
                           JOIN Publicidad.Campania c ON c.IdCampania = pz.IdCampania
                           WHERE pz.IdPieza = @IdPieza
                             AND @fechaPartido BETWEEN c.FechaInicio AND c.FechaFin)
            SET @errores += 'La campania de la pieza no esta vigente en la fecha del partido. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Publicidad.PublicidadPartido (IdPartido, NumeroEspacio, IdPieza, IdTarifa, Criterio, Puntaje, Estado)
        VALUES (@IdPartido, @NumeroEspacio, @IdPieza, @idTarifa, 'Manual', NULL, 'Confirmada');

        SET @IdPublicidadPartido = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Publicidad.usp_PublicidadPartido_Modificacion
 Modificacion completa del numero de espacio y del estado. Cambios de estado:
   Propuesta  -> Confirmada o Descartada
   Confirmada -> Exhibida (solo con el partido Finalizado) o Descartada
 Exhibida y Descartada son estados finales (registro historico). Con el partido
 Finalizado ya no se cambia el espacio.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_PublicidadPartido_Modificacion
    @IdPublicidadPartido INT,
    @NumeroEspacio       INT,
    @Estado              VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @idPartido INT, @estadoActual VARCHAR(15), @espacioActual INT, @estadoPartido VARCHAR(20);

    SELECT @idPartido     = pp.IdPartido,
           @estadoActual  = pp.Estado,
           @espacioActual = pp.NumeroEspacio,
           @estadoPartido = p.Estado
    FROM Publicidad.PublicidadPartido pp
    JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
    WHERE pp.IdPublicidadPartido = @IdPublicidadPartido;

    IF @idPartido IS NULL
        THROW 50001, 'La asignacion indicada no existe. ', 1;

    -- Estado
    IF @Estado IS NULL OR @Estado NOT IN ('Propuesta', 'Confirmada', 'Exhibida', 'Descartada')
        SET @errores += 'El estado debe ser Propuesta, Confirmada, Exhibida o Descartada. ';
    ELSE IF @Estado <> @estadoActual
    BEGIN
        IF NOT ((@estadoActual = 'Propuesta'  AND @Estado IN ('Confirmada', 'Descartada'))
             OR (@estadoActual = 'Confirmada' AND @Estado IN ('Exhibida', 'Descartada')))
            SET @errores += 'No se puede pasar del estado ' + @estadoActual + ' a ' + @Estado + '. ';
        ELSE IF @Estado = 'Exhibida' AND @estadoPartido <> 'Finalizado'
            SET @errores += 'La exhibicion se registra con el partido Finalizado. ';
    END;

    -- Numero de espacio
    IF @NumeroEspacio IS NULL OR @NumeroEspacio NOT BETWEEN 1 AND 4
        SET @errores += 'El numero de espacio debe estar entre 1 y 4. ';
    ELSE IF @NumeroEspacio <> @espacioActual
    BEGIN
        IF @estadoActual IN ('Exhibida', 'Descartada') OR @estadoPartido = 'Finalizado'
            SET @errores += 'Solo se cambia el espacio de una asignacion Propuesta o Confirmada de un partido no finalizado. ';
        ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                        WHERE IdPartido = @idPartido
                          AND NumeroEspacio = @NumeroEspacio
                          AND Estado <> 'Descartada'
                          AND IdPublicidadPartido <> @IdPublicidadPartido)
            SET @errores += 'Ese espacio ya esta ocupado en el partido. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.PublicidadPartido
        SET NumeroEspacio = @NumeroEspacio,
            Estado        = @Estado
        WHERE IdPublicidadPartido = @IdPublicidadPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Baja: borrado real, solo si el partido no esta finalizado y la publicidad no
-- se exhibio (lo exhibido es el registro para facturar).
CREATE OR ALTER PROCEDURE Publicidad.usp_PublicidadPartido_Baja
    @IdPublicidadPartido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estado VARCHAR(15), @estadoPartido VARCHAR(20);

    SELECT @estado = pp.Estado, @estadoPartido = p.Estado
    FROM Publicidad.PublicidadPartido pp
    JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
    WHERE pp.IdPublicidadPartido = @IdPublicidadPartido;

    IF @estado IS NULL
        SET @errores += 'La asignacion indicada no existe. ';
    ELSE IF @estado = 'Exhibida' OR @estadoPartido = 'Finalizado'
        SET @errores += 'La asignacion forma parte del historial del partido y no se elimina. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM Publicidad.PublicidadPartido WHERE IdPublicidadPartido = @IdPublicidadPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
