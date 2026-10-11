/*
================================================================================
UNIVERSIDAD NACIONAL DE LA MATANZA
Departamento de Ingeniería e Investigaciones Tecnológicas
Asignatura: 3641 - Bases de Datos Aplicadas
Comisión: 5600

Integrantes:
- LEOPALDI PINAZZI, AGUSTIN EMANUEL
- AVILA, ALEX AGUSTIN
- SOSA, JESÚS SANTIAGO
- BLANCO, PABLO NICOLAS

Objetivo del Script:
- Definición de Stored Procedures de operaciones ABM con validación de condiciones.
================================================================================
*/

USE MundialDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =================================================================
   ANUNCIANTE
   ================================================================= */

CREATE OR ALTER PROCEDURE Publicidad.Anunciante_Insertar
    @Nombre       VARCHAR(120),
    @IdPais       INT,
    @IdAnunciante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NULLIF(TRIM(@Nombre), '') IS NULL
        SET @Errores += N'- El nombre del anunciante es obligatorio.' + CHAR(10);
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE Nombre = TRIM(@Nombre))
        SET @Errores += N'- Ya existe un anunciante con el nombre ' + TRIM(@Nombre) + N'.' + CHAR(10);

    IF NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @Errores += N'- El país indicado no existe.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Anunciante_Insertar: no se pudo dar de alta el anunciante.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    INSERT INTO Publicidad.Anunciante (Nombre, IdPais)
    VALUES (TRIM(@Nombre), @IdPais);

    SET @IdAnunciante = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.Anunciante_Modificar
    @IdAnunciante INT,
    @Nombre       VARCHAR(120) = NULL,
    @IdPais       INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante)
    BEGIN
        SET @Mensaje = N'Anunciante_Modificar: no se pudo modificar el anunciante.' + CHAR(10)
                     + N'- El anunciante indicado no existe.';
        THROW 50001, @Mensaje, 1;
    END;

    IF @Nombre IS NOT NULL AND TRIM(@Nombre) = ''
        SET @Errores += N'- El nombre no puede quedar vacío.' + CHAR(10);
    ELSE IF @Nombre IS NOT NULL
         AND EXISTS (SELECT 1 FROM Publicidad.Anunciante
                     WHERE Nombre = TRIM(@Nombre) AND IdAnunciante <> @IdAnunciante)
        SET @Errores += N'- Ya existe otro anunciante con el nombre ' + TRIM(@Nombre) + N'.' + CHAR(10);

    IF @IdPais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @Errores += N'- El país indicado no existe.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Anunciante_Modificar: no se pudo modificar el anunciante.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    UPDATE Publicidad.Anunciante
    SET Nombre = ISNULL(TRIM(@Nombre), Nombre),
        IdPais = ISNULL(@IdPais, IdPais)
    WHERE IdAnunciante = @IdAnunciante;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.Anunciante_Eliminar
    @IdAnunciante INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante)
        SET @Errores += N'- El anunciante indicado no existe.' + CHAR(10);

    IF EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdAnunciante = @IdAnunciante)
        SET @Errores += N'- El anunciante tiene campañas registradas; elimínelas primero.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Anunciante_Eliminar: no se pudo eliminar el anunciante.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    DELETE FROM Publicidad.Anunciante
    WHERE IdAnunciante = @IdAnunciante;
END;
GO

/* =================================================================
   CAMPANIA
   ================================================================= */

CREATE OR ALTER PROCEDURE Publicidad.Campania_Insertar
    @IdAnunciante INT,
    @Nombre       VARCHAR(120),
    @FechaInicio  DATE,
    @FechaFin     DATE,
    @IdCampania   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Anunciante WHERE IdAnunciante = @IdAnunciante)
        SET @Errores += N'- El anunciante indicado no existe.' + CHAR(10);

    IF NULLIF(TRIM(@Nombre), '') IS NULL
        SET @Errores += N'- El nombre de la campaña es obligatorio.' + CHAR(10);
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.Campania
                    WHERE IdAnunciante = @IdAnunciante AND Nombre = TRIM(@Nombre))
        SET @Errores += N'- El anunciante ya tiene una campaña con el nombre ' + TRIM(@Nombre) + N'.' + CHAR(10);

    IF @FechaInicio IS NULL OR @FechaFin IS NULL
        SET @Errores += N'- Las fechas de inicio y fin son obligatorias.' + CHAR(10);
    ELSE IF @FechaFin < @FechaInicio
        SET @Errores += N'- La fecha de fin no puede ser anterior a la de inicio.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Campania_Insertar: no se pudo dar de alta la campaña.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    INSERT INTO Publicidad.Campania (IdAnunciante, Nombre, FechaInicio, FechaFin)
    VALUES (@IdAnunciante, TRIM(@Nombre), @FechaInicio, @FechaFin);

    SET @IdCampania = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.Campania_Modificar
    @IdCampania  INT,
    @Nombre      VARCHAR(120) = NULL,
    @FechaInicio DATE         = NULL,
    @FechaFin    DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @Existe BIT = 0, @IdAnunciante INT, @InicioFinal DATE, @FinFinal DATE;

    SELECT @Existe       = 1,
           @IdAnunciante = IdAnunciante,
           @InicioFinal  = ISNULL(@FechaInicio, FechaInicio),
           @FinFinal     = ISNULL(@FechaFin, FechaFin)
    FROM Publicidad.Campania
    WHERE IdCampania = @IdCampania;

    IF @Existe = 0
    BEGIN
        SET @Mensaje = N'Campania_Modificar: no se pudo modificar la campaña.' + CHAR(10)
                     + N'- La campaña indicada no existe.';
        THROW 50001, @Mensaje, 1;
    END;

    IF @Nombre IS NOT NULL AND TRIM(@Nombre) = ''
        SET @Errores += N'- El nombre no puede quedar vacío.' + CHAR(10);
    ELSE IF @Nombre IS NOT NULL
         AND EXISTS (SELECT 1 FROM Publicidad.Campania
                     WHERE IdAnunciante = @IdAnunciante AND Nombre = TRIM(@Nombre) AND IdCampania <> @IdCampania)
        SET @Errores += N'- El anunciante ya tiene otra campaña con el nombre ' + TRIM(@Nombre) + N'.' + CHAR(10);

    IF @FinFinal < @InicioFinal
        SET @Errores += N'- La fecha de fin no puede ser anterior a la de inicio.' + CHAR(10);

    -- Lo ya vendido o exhibido no puede quedar fuera de la vigencia de su campaña.
    IF EXISTS (SELECT 1
               FROM Publicidad.PublicidadPartido pp
               JOIN Publicidad.Pieza pz ON pz.IdPieza = pp.IdPieza
               JOIN Torneo.Partido p    ON p.IdPartido = pp.IdPartido
               WHERE pz.IdCampania = @IdCampania
                 AND pp.Estado IN ('Confirmada', 'Exhibida')
                 AND CAST(p.FechaHoraUtc AS DATE) NOT BETWEEN @InicioFinal AND @FinFinal)
        SET @Errores += N'- Con las nuevas fechas quedarían fuera de la campaña partidos donde sus piezas ya están confirmadas o exhibidas.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Campania_Modificar: no se pudo modificar la campaña.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    UPDATE Publicidad.Campania
    SET Nombre      = ISNULL(TRIM(@Nombre), Nombre),
        FechaInicio = @InicioFinal,
        FechaFin    = @FinFinal
    WHERE IdCampania = @IdCampania;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.Campania_Eliminar
    @IdCampania INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdCampania = @IdCampania)
        SET @Errores += N'- La campaña indicada no existe.' + CHAR(10);

    IF EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdCampania = @IdCampania)
        SET @Errores += N'- La campaña tiene piezas registradas; elimínelas primero.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Campania_Eliminar: no se pudo eliminar la campaña.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    DELETE FROM Publicidad.Campania
    WHERE IdCampania = @IdCampania;
END;
GO

/* =================================================================
   PIEZA
   ================================================================= */

CREATE OR ALTER PROCEDURE Publicidad.Pieza_Insertar
    @IdCampania       INT,
    @Nombre           VARCHAR(120),
    @Idioma           VARCHAR(10),
    @DuracionSegundos INT,
    @IdPieza          INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Campania WHERE IdCampania = @IdCampania)
        SET @Errores += N'- La campaña indicada no existe.' + CHAR(10);

    IF NULLIF(TRIM(@Nombre), '') IS NULL
        SET @Errores += N'- El nombre de la pieza es obligatorio.' + CHAR(10);

    IF NULLIF(TRIM(@Idioma), '') IS NULL
        SET @Errores += N'- El idioma de la pieza es obligatorio.' + CHAR(10);

    IF @DuracionSegundos IS NULL OR @DuracionSegundos NOT BETWEEN 1 AND 300
        SET @Errores += N'- La duración debe estar entre 1 y 300 segundos.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Pieza_Insertar: no se pudo dar de alta la pieza.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    INSERT INTO Publicidad.Pieza (IdCampania, Idioma, Nombre, DuracionSegundos)
    VALUES (@IdCampania, LOWER(TRIM(@Idioma)), TRIM(@Nombre), @DuracionSegundos);

    SET @IdPieza = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.Pieza_Modificar
    @IdPieza          INT,
    @Nombre           VARCHAR(120) = NULL,
    @Idioma           VARCHAR(10)  = NULL,
    @DuracionSegundos INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
    BEGIN
        SET @Mensaje = N'Pieza_Modificar: no se pudo modificar la pieza.' + CHAR(10)
                     + N'- La pieza indicada no existe.';
        THROW 50001, @Mensaje, 1;
    END;

    IF @Nombre IS NOT NULL AND TRIM(@Nombre) = ''
        SET @Errores += N'- El nombre no puede quedar vacío.' + CHAR(10);

    IF @Idioma IS NOT NULL AND TRIM(@Idioma) = ''
        SET @Errores += N'- El idioma no puede quedar vacío.' + CHAR(10);

    IF @DuracionSegundos IS NOT NULL AND @DuracionSegundos NOT BETWEEN 1 AND 300
        SET @Errores += N'- La duración debe estar entre 1 y 300 segundos.' + CHAR(10);

    -- Lo exhibido se factura tal como salió al aire.
    IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdPieza = @IdPieza AND Estado = 'Exhibida')
        SET @Errores += N'- La pieza ya fue exhibida; no puede modificarse (es registro histórico).' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Pieza_Modificar: no se pudo modificar la pieza.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    UPDATE Publicidad.Pieza
    SET Nombre           = ISNULL(TRIM(@Nombre), Nombre),
        Idioma           = ISNULL(LOWER(TRIM(@Idioma)), Idioma),
        DuracionSegundos = ISNULL(@DuracionSegundos, DuracionSegundos)
    WHERE IdPieza = @IdPieza;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.Pieza_Eliminar
    @IdPieza INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @Errores += N'- La pieza indicada no existe.' + CHAR(10);

    IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdPieza = @IdPieza)
        SET @Errores += N'- La pieza está asignada a partidos; no puede eliminarse.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'Pieza_Eliminar: no se pudo eliminar la pieza.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    -- Los países de interés se eliminan por la FK con ON DELETE CASCADE.
    DELETE FROM Publicidad.Pieza
    WHERE IdPieza = @IdPieza;
END;
GO

/* =================================================================
   PIEZA PAIS
   ================================================================= */

CREATE OR ALTER PROCEDURE Publicidad.PiezaPais_Insertar
    @IdPieza INT,
    @IdPais  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @Errores += N'- La pieza indicada no existe.' + CHAR(10);

    IF NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPais)
        SET @Errores += N'- El país indicado no existe.' + CHAR(10);

    IF EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPais)
        SET @Errores += N'- La pieza ya tiene cargado ese país.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PiezaPais_Insertar: no se pudo agregar el país a la pieza.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    INSERT INTO Publicidad.PiezaPais (IdPieza, IdPais)
    VALUES (@IdPieza, @IdPais);
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.PiezaPais_Modificar
    @IdPieza      INT,
    @IdPaisActual INT,
    @IdPaisNuevo  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPaisActual)
        SET @Errores += N'- La pieza no tiene cargado el país que se quiere reemplazar.' + CHAR(10);

    IF NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE IdPais = @IdPaisNuevo)
        SET @Errores += N'- El país nuevo no existe.' + CHAR(10);
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPaisNuevo)
        SET @Errores += N'- La pieza ya tiene cargado el país nuevo.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PiezaPais_Modificar: no se pudo modificar el país de la pieza.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    UPDATE Publicidad.PiezaPais
    SET IdPais = @IdPaisNuevo
    WHERE IdPieza = @IdPieza AND IdPais = @IdPaisActual;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.PiezaPais_Eliminar
    @IdPieza INT,
    @IdPais  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza AND IdPais = @IdPais)
        SET @Errores += N'- La pieza no tiene cargado ese país.' + CHAR(10);
    ELSE IF (SELECT COUNT(*) FROM Publicidad.PiezaPais WHERE IdPieza = @IdPieza) = 1
        -- Sin países de interés la pieza no podría competir por ningún espacio.
        SET @Errores += N'- Es el único país de interés de la pieza; agregue otro antes de quitarlo.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PiezaPais_Eliminar: no se pudo quitar el país de la pieza.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    DELETE FROM Publicidad.PiezaPais
    WHERE IdPieza = @IdPieza AND IdPais = @IdPais;
END;
GO

/* =================================================================
   TARIFA PUBLICITARIA
   ================================================================= */

CREATE OR ALTER PROCEDURE Publicidad.TarifaPublicitaria_Insertar
    @Fase         VARCHAR(20),
    @Moneda       VARCHAR(10),
    @Monto        DECIMAL(18,2),
    @VigenteDesde DATE,
    @VigenteHasta DATE = NULL,
    @IdTarifa     INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF Torneo.fn_OrdenFase(@Fase) IS NULL
        SET @Errores += N'- La fase indicada no existe (Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final).' + CHAR(10);

    IF @Moneda IS NULL OR UPPER(@Moneda) COLLATE Latin1_General_BIN NOT LIKE '[A-Z][A-Z][A-Z]'
        SET @Errores += N'- La moneda debe ser un código de 3 letras (por ejemplo, USD).' + CHAR(10);

    IF @Monto IS NULL OR @Monto <= 0
        SET @Errores += N'- El monto debe ser mayor que cero.' + CHAR(10);

    IF @VigenteDesde IS NULL
        SET @Errores += N'- La fecha de inicio de vigencia es obligatoria.' + CHAR(10);
    ELSE IF @VigenteHasta < @VigenteDesde
        SET @Errores += N'- El fin de la vigencia no puede ser anterior al inicio.' + CHAR(10);
    -- Dos tarifas de la misma fase no pueden estar vigentes a la vez (NULL = sin fecha de fin).
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.TarifaPublicitaria
                    WHERE Fase = @Fase
                      AND VigenteDesde <= ISNULL(@VigenteHasta, '9999-12-31')
                      AND @VigenteDesde <= ISNULL(VigenteHasta, '9999-12-31'))
        SET @Errores += N'- La vigencia se superpone con otra tarifa de la fase ' + @Fase + N'.' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'TarifaPublicitaria_Insertar: no se pudo dar de alta la tarifa.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    INSERT INTO Publicidad.TarifaPublicitaria (Fase, Moneda, Monto, VigenteDesde, VigenteHasta)
    VALUES (@Fase, UPPER(@Moneda), @Monto, @VigenteDesde, @VigenteHasta);

    SET @IdTarifa = SCOPE_IDENTITY();
END;
GO

/*
   TarifaPublicitaria_Modificar
   Una tarifa que ya se aplicó a algún espacio no cambia de precio, moneda
   ni inicio de vigencia: para cambiar el precio se cierra su vigencia
   (@VigenteHasta) y se da de alta una tarifa nueva. Así la facturación de lo
   ya vendido no cambia. @VigenciaAbierta = 1 deja la tarifa sin fecha de fin.
*/
CREATE OR ALTER PROCEDURE Publicidad.TarifaPublicitaria_Modificar
    @IdTarifa        INT,
    @Moneda          VARCHAR(10)   = NULL,
    @Monto           DECIMAL(18,2) = NULL,
    @VigenteDesde    DATE          = NULL,
    @VigenteHasta    DATE          = NULL,
    @VigenciaAbierta BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @Existe BIT = 0, @EnUso BIT = 0, @Fase VARCHAR(20);
    DECLARE @MonedaActual CHAR(3), @MontoActual DECIMAL(18,2), @DesdeActual DATE;
    DECLARE @DesdeFinal DATE, @HastaFinal DATE;

    SELECT @Existe       = 1,
           @Fase         = Fase,
           @MonedaActual = Moneda,
           @MontoActual  = Monto,
           @DesdeActual  = VigenteDesde,
           @DesdeFinal   = ISNULL(@VigenteDesde, VigenteDesde),
           @HastaFinal   = CASE WHEN @VigenciaAbierta = 1 THEN NULL
                                ELSE ISNULL(@VigenteHasta, VigenteHasta) END
    FROM Publicidad.TarifaPublicitaria
    WHERE IdTarifa = @IdTarifa;

    IF @Existe = 0
    BEGIN
        SET @Mensaje = N'TarifaPublicitaria_Modificar: no se pudo modificar la tarifa.' + CHAR(10)
                     + N'- La tarifa indicada no existe.';
        THROW 50001, @Mensaje, 1;
    END;

    IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdTarifa = @IdTarifa AND Estado <> 'Descartada')
        SET @EnUso = 1;

    IF @Moneda IS NOT NULL AND UPPER(@Moneda) COLLATE Latin1_General_BIN NOT LIKE '[A-Z][A-Z][A-Z]'
        SET @Errores += N'- La moneda debe ser un código de 3 letras (por ejemplo, USD).' + CHAR(10);

    IF @Monto IS NOT NULL AND @Monto <= 0
        SET @Errores += N'- El monto debe ser mayor que cero.' + CHAR(10);

    IF @EnUso = 1
       AND ((@Monto IS NOT NULL AND @Monto <> @MontoActual)
            OR (@Moneda IS NOT NULL AND UPPER(@Moneda) <> @MonedaActual)
            OR (@VigenteDesde IS NOT NULL AND @VigenteDesde <> @DesdeActual))
        SET @Errores += N'- La tarifa ya se aplicó a espacios vendidos: para cambiar el precio, cierre su vigencia y dé de alta una tarifa nueva.' + CHAR(10);

    IF @HastaFinal < @DesdeFinal
        SET @Errores += N'- El fin de la vigencia no puede ser anterior al inicio.' + CHAR(10);
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM Publicidad.TarifaPublicitaria
                   WHERE Fase = @Fase
                     AND IdTarifa <> @IdTarifa
                     AND VigenteDesde <= ISNULL(@HastaFinal, '9999-12-31')
                     AND @DesdeFinal <= ISNULL(VigenteHasta, '9999-12-31'))
            SET @Errores += N'- La nueva vigencia se superpone con otra tarifa de la fase ' + @Fase + N'.' + CHAR(10);

        IF EXISTS (SELECT 1
                   FROM Publicidad.PublicidadPartido pp
                   JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
                   WHERE pp.IdTarifa = @IdTarifa
                     AND pp.Estado <> 'Descartada'
                     AND CAST(p.FechaHoraUtc AS DATE) NOT BETWEEN @DesdeFinal AND ISNULL(@HastaFinal, '9999-12-31'))
            SET @Errores += N'- La nueva vigencia deja afuera partidos que ya usan esta tarifa.' + CHAR(10);
    END;

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'TarifaPublicitaria_Modificar: no se pudo modificar la tarifa.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    UPDATE Publicidad.TarifaPublicitaria
    SET Moneda       = ISNULL(UPPER(@Moneda), Moneda),
        Monto        = ISNULL(@Monto, Monto),
        VigenteDesde = @DesdeFinal,
        VigenteHasta = @HastaFinal
    WHERE IdTarifa = @IdTarifa;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.TarifaPublicitaria_Eliminar
    @IdTarifa INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.TarifaPublicitaria WHERE IdTarifa = @IdTarifa)
        SET @Errores += N'- La tarifa indicada no existe.' + CHAR(10);

    IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido WHERE IdTarifa = @IdTarifa)
        SET @Errores += N'- La tarifa está aplicada a espacios de partidos; no puede eliminarse (cierre su vigencia).' + CHAR(10);

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'TarifaPublicitaria_Eliminar: no se pudo eliminar la tarifa.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    DELETE FROM Publicidad.TarifaPublicitaria
    WHERE IdTarifa = @IdTarifa;
END;
GO

/* =================================================================
   PUBLICIDAD PARTIDO
   ================================================================= */

/*
   PublicidadPartido_Insertar: alta manual (venta directa de un espacio).
   Queda Confirmada, con criterio 'Manual' y la tarifa vigente de la fase.
*/
CREATE OR ALTER PROCEDURE Publicidad.PublicidadPartido_Insertar
    @IdPartido           INT,
    @NumeroEspacio       TINYINT,
    @IdPieza             INT,
    @IdPublicidadPartido INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @PartidoExiste BIT = 0, @EstadoPartido VARCHAR(20), @Fase VARCHAR(20), @FechaPartido DATE;
    DECLARE @IdTarifa INT;

    SELECT @PartidoExiste = 1,
           @EstadoPartido = Estado,
           @Fase          = Fase,
           @FechaPartido  = CAST(FechaHoraUtc AS DATE)
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    IF @PartidoExiste = 0
        SET @Errores += N'- El partido indicado no existe.' + CHAR(10);
    ELSE
    BEGIN
        IF @EstadoPartido = 'Finalizado'
            SET @Errores += N'- El partido está finalizado; no se le pueden asignar espacios.' + CHAR(10);

        SET @IdTarifa = Publicidad.fn_TarifaVigente(@Fase, @FechaPartido);
        IF @IdTarifa IS NULL
            SET @Errores += N'- No hay una tarifa vigente para la fase ' + @Fase + N' en la fecha del partido.' + CHAR(10);
    END;

    IF @NumeroEspacio IS NULL OR @NumeroEspacio NOT BETWEEN 1 AND 4
        SET @Errores += N'- El número de espacio debe estar entre 1 y 4.' + CHAR(10);
    ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                    WHERE IdPartido = @IdPartido AND NumeroEspacio = @NumeroEspacio AND Estado <> 'Descartada')
        SET @Errores += N'- El espacio ' + CAST(@NumeroEspacio AS NVARCHAR(1)) + N' ya está ocupado en ese partido.' + CHAR(10);

    IF NOT EXISTS (SELECT 1 FROM Publicidad.Pieza WHERE IdPieza = @IdPieza)
        SET @Errores += N'- La pieza indicada no existe.' + CHAR(10);
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                   WHERE IdPartido = @IdPartido AND IdPieza = @IdPieza AND Estado <> 'Descartada')
            SET @Errores += N'- La pieza ya ocupa otro espacio en ese partido.' + CHAR(10);

        IF @PartidoExiste = 1
           AND NOT EXISTS (SELECT 1
                           FROM Publicidad.Pieza pz
                           JOIN Publicidad.Campania c ON c.IdCampania = pz.IdCampania
                           WHERE pz.IdPieza = @IdPieza
                             AND @FechaPartido BETWEEN c.FechaInicio AND c.FechaFin)
            SET @Errores += N'- La campaña de la pieza no está vigente en la fecha del partido.' + CHAR(10);
    END;

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PublicidadPartido_Insertar: no se pudo asignar el espacio.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    INSERT INTO Publicidad.PublicidadPartido (IdPartido, NumeroEspacio, IdPieza, IdTarifa, Criterio, Puntaje, Estado)
    VALUES (@IdPartido, @NumeroEspacio, @IdPieza, @IdTarifa, 'Manual', NULL, 'Confirmada');

    SET @IdPublicidadPartido = SCOPE_IDENTITY();
END;
GO

/*
   PublicidadPartido_Modificar: cambia el estado o el número de espacio.
   Cambios de estado permitidos:
     Propuesta  -> Confirmada o Descartada
     Confirmada -> Descartada o Exhibida (Exhibida solo con el partido finalizado)
   Exhibida y Descartada son finales (registro histórico).
*/
CREATE OR ALTER PROCEDURE Publicidad.PublicidadPartido_Modificar
    @IdPublicidadPartido INT,
    @Estado              VARCHAR(15) = NULL,
    @NumeroEspacio       TINYINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @Existe BIT = 0, @IdPartido INT, @EstadoActual VARCHAR(15), @EspacioActual TINYINT, @EstadoPartido VARCHAR(20);
    DECLARE @EstadoFinal VARCHAR(15), @CambiaEstado BIT = 0, @CambiaEspacio BIT = 0;

    SELECT @Existe        = 1,
           @IdPartido     = pp.IdPartido,
           @EstadoActual  = pp.Estado,
           @EspacioActual = pp.NumeroEspacio,
           @EstadoPartido = p.Estado,
           @EstadoFinal   = ISNULL(@Estado, pp.Estado)
    FROM Publicidad.PublicidadPartido pp
    JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
    WHERE pp.IdPublicidadPartido = @IdPublicidadPartido;

    IF @Existe = 0
    BEGIN
        SET @Mensaje = N'PublicidadPartido_Modificar: no se pudo modificar el espacio.' + CHAR(10)
                     + N'- La asignación indicada no existe.';
        THROW 50001, @Mensaje, 1;
    END;

    IF @EstadoFinal <> @EstadoActual
        SET @CambiaEstado = 1;
    IF @NumeroEspacio IS NOT NULL AND @NumeroEspacio <> @EspacioActual
        SET @CambiaEspacio = 1;

    IF @EstadoFinal NOT IN ('Propuesta', 'Confirmada', 'Exhibida', 'Descartada')
        SET @Errores += N'- Estado inválido (Propuesta, Confirmada, Exhibida o Descartada).' + CHAR(10);
    ELSE IF @CambiaEstado = 1
         AND NOT ((@EstadoActual = 'Propuesta'  AND @EstadoFinal IN ('Confirmada', 'Descartada'))
               OR (@EstadoActual = 'Confirmada' AND @EstadoFinal IN ('Descartada', 'Exhibida')))
        SET @Errores += N'- No se puede pasar del estado ' + @EstadoActual + N' a ' + @EstadoFinal + N'.' + CHAR(10);

    -- Al confirmar una propuesta se revisa que la campaña siga vigente en la fecha del partido
    -- (pudo haberse acortado después de calcular la propuesta).
    IF @CambiaEstado = 1 AND @EstadoFinal = 'Confirmada'
       AND NOT EXISTS (SELECT 1
                       FROM Publicidad.PublicidadPartido pp
                       JOIN Publicidad.Pieza pz    ON pz.IdPieza = pp.IdPieza
                       JOIN Publicidad.Campania c  ON c.IdCampania = pz.IdCampania
                       JOIN Torneo.Partido p       ON p.IdPartido = pp.IdPartido
                       WHERE pp.IdPublicidadPartido = @IdPublicidadPartido
                         AND CAST(p.FechaHoraUtc AS DATE) BETWEEN c.FechaInicio AND c.FechaFin)
        SET @Errores += N'- La campaña de la pieza ya no está vigente en la fecha del partido.' + CHAR(10);

    IF @CambiaEstado = 1 AND @EstadoFinal = 'Exhibida' AND ISNULL(@EstadoPartido, '') <> 'Finalizado'
        SET @Errores += N'- Solo se registra la exhibición cuando el partido está finalizado.' + CHAR(10);

    IF @EstadoPartido = 'Finalizado'
       AND (@CambiaEspacio = 1 OR (@CambiaEstado = 1 AND @EstadoFinal NOT IN ('Exhibida', 'Descartada')))
        SET @Errores += N'- El partido está finalizado: solo puede registrarse la exhibición o descartarse lo no vendido.' + CHAR(10);

    IF @CambiaEspacio = 1
    BEGIN
        IF @EstadoActual IN ('Exhibida', 'Descartada')
            SET @Errores += N'- Una asignación ' + @EstadoActual + N' no puede cambiar de espacio.' + CHAR(10);

        IF @NumeroEspacio NOT BETWEEN 1 AND 4
            SET @Errores += N'- El número de espacio debe estar entre 1 y 4.' + CHAR(10);
        ELSE IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                        WHERE IdPartido = @IdPartido
                          AND NumeroEspacio = @NumeroEspacio
                          AND Estado <> 'Descartada'
                          AND IdPublicidadPartido <> @IdPublicidadPartido)
            SET @Errores += N'- El espacio ' + CAST(@NumeroEspacio AS NVARCHAR(1)) + N' ya está ocupado en ese partido.' + CHAR(10);
    END;

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PublicidadPartido_Modificar: no se pudo modificar el espacio.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    UPDATE Publicidad.PublicidadPartido
    SET Estado        = @EstadoFinal,
        NumeroEspacio = ISNULL(@NumeroEspacio, NumeroEspacio)
    WHERE IdPublicidadPartido = @IdPublicidadPartido;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.PublicidadPartido_Eliminar
    @IdPublicidadPartido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @Existe BIT = 0, @Estado VARCHAR(15), @EstadoPartido VARCHAR(20);

    SELECT @Existe        = 1,
           @Estado        = pp.Estado,
           @EstadoPartido = p.Estado
    FROM Publicidad.PublicidadPartido pp
    JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
    WHERE pp.IdPublicidadPartido = @IdPublicidadPartido;

    IF @Existe = 0
        SET @Errores += N'- La asignación indicada no existe.' + CHAR(10);
    ELSE
    BEGIN
        IF @Estado = 'Exhibida'
            SET @Errores += N'- La publicidad ya fue exhibida; es registro histórico para facturar y no puede eliminarse.' + CHAR(10);

        IF @EstadoPartido = 'Finalizado'
            SET @Errores += N'- El partido está finalizado; sus espacios no pueden eliminarse.' + CHAR(10);
    END;

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PublicidadPartido_Eliminar: no se pudo eliminar el espacio.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    DELETE FROM Publicidad.PublicidadPartido
    WHERE IdPublicidadPartido = @IdPublicidadPartido;
END;
GO

PRINT 'SP de ABM de publicidad creados.';
GO
