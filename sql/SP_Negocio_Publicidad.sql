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

- Stored Procedure de Lógica de Negocio para la selección y asignación automática 
  de los 4 espacios publicitarios por partido según las pautas FIFA.
=====================================================================
*/

USE MundialFutbol;
GO

CREATE OR ALTER PROCEDURE Publicidad.PublicidadPartido_Asignar
    @IdPartido         INT,
    @EspaciosAsignados INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @PartidoExiste BIT = 0, @EstadoPartido VARCHAR(20), @Fase VARCHAR(20), @FechaPartido DATE;
    DECLARE @IdTarifa INT;

    SET @EspaciosAsignados = 0;

    /* ---------- Buscar ---------- */
    SELECT @PartidoExiste = 1,
           @EstadoPartido = Estado,
           @Fase          = Fase,
           @FechaPartido  = CAST(FechaHoraUtc AS DATE)
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    /* ---------- Validar ---------- */
    IF @PartidoExiste = 0
        SET @Errores += N'- El partido indicado no existe.' + CHAR(10);
    ELSE
    BEGIN
        IF @EstadoPartido = 'Finalizado'
            SET @Errores += N'- El partido está finalizado; no se le asigna publicidad.' + CHAR(10);

        -- La propuesta automática se hace antes de vender: no pisa lo confirmado ni lo exhibido.
        IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                   WHERE IdPartido = @IdPartido AND Estado IN ('Confirmada', 'Exhibida'))
            SET @Errores += N'- El partido ya tiene espacios confirmados o exhibidos; descártelos antes de recalcular la propuesta.' + CHAR(10);

        SET @IdTarifa = Publicidad.fn_TarifaVigente(@Fase, @FechaPartido);
        IF @IdTarifa IS NULL
            SET @Errores += N'- No hay una tarifa vigente para la fase ' + @Fase + N' en la fecha del partido.' + CHAR(10);

        IF NOT EXISTS (SELECT 1 FROM Publicidad.fn_CandidatasPartido(@IdPartido) WHERE Posicion IS NOT NULL)
            SET @Errores += N'- No hay piezas de campañas vigentes en la fecha del partido.' + CHAR(10);
    END;

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PublicidadPartido_Asignar: no se pudo asignar la publicidad del partido.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    /* ---------- Ejecutar ---------- */
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Se quitan las propuestas anteriores (las descartadas quedan como historial).
        DELETE FROM Publicidad.PublicidadPartido
        WHERE IdPartido = @IdPartido
          AND Estado = 'Propuesta';

        -- 2) Se insertan las 4 mejores: la posición es el número de espacio.
        INSERT INTO Publicidad.PublicidadPartido (IdPartido, NumeroEspacio, IdPieza, IdTarifa, Criterio, Puntaje, Estado)
        SELECT @IdPartido, c.Posicion, c.IdPieza, @IdTarifa, c.Criterio, c.Puntaje, 'Propuesta'
        FROM Publicidad.fn_CandidatasPartido(@IdPartido) c
        WHERE c.Posicion <= 4;

        SET @EspaciosAsignados = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @EspaciosAsignados = 0;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE Publicidad.PublicidadPartido_RegistrarExhibicion
    @IdPartido   INT,
    @Exhibidas   INT = NULL OUTPUT,
    @Descartadas INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errores NVARCHAR(MAX) = N'';
    DECLARE @Mensaje NVARCHAR(2048);
    DECLARE @PartidoExiste BIT = 0, @EstadoPartido VARCHAR(20);

    SET @Exhibidas = 0;
    SET @Descartadas = 0;

    SELECT @PartidoExiste = 1,
           @EstadoPartido = Estado
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    IF @PartidoExiste = 0
        SET @Errores += N'- El partido indicado no existe.' + CHAR(10);
    ELSE
    BEGIN
        IF ISNULL(@EstadoPartido, '') <> 'Finalizado'
            SET @Errores += N'- El partido todavía no está finalizado.' + CHAR(10);

        IF NOT EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                       WHERE IdPartido = @IdPartido AND Estado IN ('Confirmada', 'Propuesta'))
            SET @Errores += N'- El partido no tiene espacios confirmados ni propuestos pendientes de cerrar.' + CHAR(10);
    END;

    IF LEN(@Errores) > 0
    BEGIN
        SET @Mensaje = LEFT(N'PublicidadPartido_RegistrarExhibicion: no se pudo registrar la exhibición.' + CHAR(10) + @Errores, 2048);
        THROW 50001, @Mensaje, 1;
    END;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Lo confirmado salió al aire: queda como registro para facturar.
        UPDATE Publicidad.PublicidadPartido
        SET Estado = 'Exhibida'
        WHERE IdPartido = @IdPartido
          AND Estado = 'Confirmada';

        SET @Exhibidas = @@ROWCOUNT;

        -- 2) Lo que quedó como propuesta no se vendió: se descarta (queda como historial).
        UPDATE Publicidad.PublicidadPartido
        SET Estado = 'Descartada'
        WHERE IdPartido = @IdPartido
          AND Estado = 'Propuesta';

        SET @Descartadas = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Exhibidas = 0;
        SET @Descartadas = 0;
        THROW;
    END CATCH;
END;
GO

PRINT 'SP de lógica de negocio de publicidad creados.';
GO
