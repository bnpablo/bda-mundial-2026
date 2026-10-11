/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 93_SP_Negocio_DesignacionArbitral.sql
 Objetivo     : Logica de negocio de la designacion arbitral. Cada SP valida todo
                primero (un unico mensaje, THROW 50001) y despues opera dentro de
                una transaccion:
                  Arbitraje.usp_DesignarArbitro          designa un arbitro en un
                                                         partido con un rol.
                  Arbitraje.usp_ListarArbitrosElegibles  lista los arbitros que se
                                                         pueden designar en un partido.
                Reglas: el arbitro no puede ser de la misma nacionalidad que ninguna
                de las dos selecciones del partido, no puede estar ya designado en el
                partido y no puede estar designado en otro partido con menos de 180
                minutos de diferencia (el mismo margen que usan los partidos de una
                misma sede). El rol debe ser uno de los de la tabla (Principal,
                Asistente 1, Asistente 2, Cuarto o VAR) y un partido no puede tener
                dos arbitros con el mismo rol.
 Depende de   : 50_SP_ABM_Arbitraje.sql y las tablas de Arbitraje de Avila
                (04_Tablas_Arbitraje_Incidencia.sql)
==============================================================================*/
USE MundialDB;
GO

CREATE OR ALTER PROCEDURE Arbitraje.usp_DesignarArbitro
    @IdPartido      INT,
    @IdArbitro      INT,
    @RolArbitral    VARCHAR(20),
    @IdDesignacion  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @margenMinutos INT = 180;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @rol VARCHAR(20) = LTRIM(RTRIM(@RolArbitral));
    DECLARE @partidoExiste BIT = 0, @arbitroExiste BIT = 0;
    DECLARE @paisArbitro INT, @paisLocal INT, @paisVisitante INT, @fechaUtc DATETIME2;

    SELECT @arbitroExiste = 1, @paisArbitro = IdPais
    FROM Arbitraje.Arbitro
    WHERE IdArbitro = @IdArbitro;

    SELECT @partidoExiste = 1, @paisLocal = sl.IdPais, @paisVisitante = sv.IdPais, @fechaUtc = p.FechaHoraUtc
    FROM Torneo.Partido p
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    WHERE p.IdPartido = @IdPartido;

    IF @partidoExiste = 0
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @paisLocal IS NULL OR @paisVisitante IS NULL
        SET @errores += 'El partido necesita las dos selecciones definidas para designar arbitro. ';

    IF @arbitroExiste = 0
        SET @errores += 'El arbitro indicado no existe. ';

    IF @rol IS NULL OR @rol = ''
        SET @errores += 'El rol arbitral es obligatorio. ';
    ELSE IF @rol NOT IN ('Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR')
        SET @errores += 'El rol arbitral debe ser Principal, Asistente 1, Asistente 2, Cuarto o VAR. ';
    ELSE IF @partidoExiste = 1
         AND EXISTS (SELECT 1
                     FROM Arbitraje.DesignacionArbitral
                     WHERE IdPartido = @IdPartido AND RolArbitral = @rol)
        SET @errores += 'El partido ya tiene un arbitro designado con ese rol. ';

    IF @partidoExiste = 1 AND @arbitroExiste = 1
    BEGIN
        IF @paisLocal IS NOT NULL AND @paisVisitante IS NOT NULL
           AND @paisArbitro IN (@paisLocal, @paisVisitante)
            SET @errores += 'El arbitro no puede ser de la misma nacionalidad que alguna de las selecciones del partido. ';

        IF EXISTS (SELECT 1
                   FROM Arbitraje.DesignacionArbitral
                   WHERE IdPartido = @IdPartido AND IdArbitro = @IdArbitro)
            SET @errores += 'El arbitro ya esta designado en este partido. ';

        IF EXISTS (SELECT 1
                   FROM Arbitraje.DesignacionArbitral d
                   JOIN Torneo.Partido p2 ON p2.IdPartido = d.IdPartido
                   WHERE d.IdArbitro = @IdArbitro
                     AND d.IdPartido <> @IdPartido
                     AND ABS(DATEDIFF(MINUTE, p2.FechaHoraUtc, @fechaUtc)) < @margenMinutos)
            SET @errores += CONCAT('El arbitro ya esta designado en otro partido con menos de ', @margenMinutos, ' minutos de diferencia. ');
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Arbitraje.DesignacionArbitral (IdPartido, IdArbitro, RolArbitral)
        VALUES (@IdPartido, @IdArbitro, @rol);

        SET @IdDesignacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @IdDesignacion = NULL;
        THROW;
    END CATCH
END
GO

-- Arbitros elegibles para un partido (para ayudar a elegir antes de designar).
-- Igual que usp_DesignarArbitro, necesita el partido con sus dos selecciones definidas:
-- si no, informa el error en lugar de devolver una lista vacia.
CREATE OR ALTER PROCEDURE Arbitraje.usp_ListarArbitrosElegibles
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @margenMinutos INT = 180;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @partidoExiste BIT = 0, @paisLocal INT, @paisVisitante INT;

    SELECT @partidoExiste = 1, @paisLocal = sl.IdPais, @paisVisitante = sv.IdPais
    FROM Torneo.Partido p
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    WHERE p.IdPartido = @IdPartido;

    IF @partidoExiste = 0
        SET @errores += 'El partido indicado no existe. ';
    ELSE IF @paisLocal IS NULL OR @paisVisitante IS NULL
        SET @errores += 'El partido necesita las dos selecciones definidas para listar arbitros elegibles. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SELECT ar.IdArbitro, ar.Nombre, ar.Apellido, ar.IdPais, ar.Categoria
    FROM Torneo.Partido p
    JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    CROSS JOIN Arbitraje.Arbitro ar
    WHERE p.IdPartido = @IdPartido
      AND ar.IdPais NOT IN (sl.IdPais, sv.IdPais)
      AND NOT EXISTS (SELECT 1
                      FROM Arbitraje.DesignacionArbitral d
                      WHERE d.IdPartido = p.IdPartido AND d.IdArbitro = ar.IdArbitro)
      AND NOT EXISTS (SELECT 1
                      FROM Arbitraje.DesignacionArbitral d2
                      JOIN Torneo.Partido p2 ON p2.IdPartido = d2.IdPartido
                      WHERE d2.IdArbitro = ar.IdArbitro
                        AND ABS(DATEDIFF(MINUTE, p2.FechaHoraUtc, p.FechaHoraUtc)) < @margenMinutos)
    ORDER BY ar.Apellido, ar.Nombre;
END
GO
