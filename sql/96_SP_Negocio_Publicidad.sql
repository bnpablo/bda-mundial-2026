/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 96_SP_Negocio_Publicidad.sql
 Objetivo     : Logica de negocio de publicidad. Cada SP valida todo primero (un
                unico mensaje) y despues opera dentro de una transaccion:
                  Publicidad.usp_AsignarPiezasPartido  propone las 4 piezas de un
                                                       partido segun los criterios
                                                       de la consigna (seccion H).
                  Publicidad.usp_RegistrarExhibicion   al terminar el partido, lo
                                                       confirmado pasa a Exhibida
                                                       (para facturar) y lo propuesto
                                                       a Descartada.
 Prerrequisito: 60_SP_ABM_Publicidad.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Publicidad.usp_AsignarPiezasPartido
 Toma las 4 primeras piezas de Publicidad.fn_CandidatasPartido y las guarda como
 Propuesta en los espacios 1 a 4, con la tarifa vigente de la fase. Si el
 partido ya tenia una propuesta, se reemplaza. No se ejecuta si ya hay espacios
 confirmados o exhibidos (lo vendido no se pisa).
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_AsignarPiezasPartido
    @IdPartido              INT,
    @MaxPiezasPorAnunciante INT = 1,
    @EspaciosAsignados      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estadoPartido VARCHAR(20), @fase VARCHAR(20), @fechaPartido DATE, @local INT, @visitante INT, @idTarifa INT;

    SELECT @estadoPartido = Estado, @fase = Fase, @fechaPartido = CAST(FechaHoraUtc AS DATE),
           @local = IdSeleccionLocal, @visitante = IdSeleccionVisitante
    FROM Torneo.Partido
    WHERE IdPartido = @IdPartido;

    IF @estadoPartido IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE
    BEGIN
        IF @estadoPartido = 'Finalizado'
            SET @errores += 'El partido esta finalizado: no se le asigna publicidad. ';

        IF @local IS NULL OR @visitante IS NULL
            SET @errores += 'El partido necesita las dos selecciones definidas. ';

        IF EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                   WHERE IdPartido = @IdPartido AND Estado IN ('Confirmada', 'Exhibida'))
            SET @errores += 'El partido ya tiene espacios confirmados o exhibidos. ';

        SET @idTarifa = Publicidad.fn_TarifaVigente(@fase, @fechaPartido);
        IF @idTarifa IS NULL
            SET @errores += 'No hay una tarifa vigente para la fase del partido en su fecha. ';

        IF NOT EXISTS (SELECT 1 FROM Publicidad.fn_CandidatasPartido(@IdPartido, @MaxPiezasPorAnunciante))
            SET @errores += 'No hay piezas de campanias vigentes en la fecha del partido. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) Se borra la propuesta anterior (lo descartado queda como historial).
        DELETE FROM Publicidad.PublicidadPartido
        WHERE IdPartido = @IdPartido
          AND Estado = 'Propuesta';

        -- 2) Se guardan las 4 mejores: la posicion es el numero de espacio.
        INSERT INTO Publicidad.PublicidadPartido (IdPartido, NumeroEspacio, IdPieza, IdTarifa, Criterio, Puntaje, Estado)
        SELECT @IdPartido, Posicion, IdPieza, @idTarifa, Criterio, Puntaje, 'Propuesta'
        FROM Publicidad.fn_CandidatasPartido(@IdPartido, @MaxPiezasPorAnunciante)
        WHERE Posicion <= 4;

        SET @EspaciosAsignados = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @EspaciosAsignados = 0;
        THROW;
    END CATCH
END
GO

/*------------------------------------------------------------------------------
 Publicidad.usp_RegistrarExhibicion
 Cierre de la publicidad de un partido Finalizado, en una sola transaccion:
   1) lo Confirmado salio al aire: pasa a Exhibida (registro para facturar);
   2) lo que quedo como Propuesta no se vendio: pasa a Descartada.
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Publicidad.usp_RegistrarExhibicion
    @IdPartido   INT,
    @Exhibidas   INT = NULL OUTPUT,
    @Descartadas INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @estadoPartido VARCHAR(20);

    SELECT @estadoPartido = Estado FROM Torneo.Partido WHERE IdPartido = @IdPartido;

    IF @estadoPartido IS NULL
        SET @errores += 'El partido indicado no existe. ';
    ELSE
    BEGIN
        IF @estadoPartido <> 'Finalizado'
            SET @errores += 'El partido todavia no esta finalizado. ';

        IF NOT EXISTS (SELECT 1 FROM Publicidad.PublicidadPartido
                       WHERE IdPartido = @IdPartido AND Estado IN ('Propuesta', 'Confirmada'))
            SET @errores += 'El partido no tiene espacios propuestos ni confirmados para cerrar. ';
    END;

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Publicidad.PublicidadPartido
        SET Estado = 'Exhibida'
        WHERE IdPartido = @IdPartido
          AND Estado = 'Confirmada';

        SET @Exhibidas = @@ROWCOUNT;

        UPDATE Publicidad.PublicidadPartido
        SET Estado = 'Descartada'
        WHERE IdPartido = @IdPartido
          AND Estado = 'Propuesta';

        SET @Descartadas = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Exhibidas = 0;
        SET @Descartadas = 0;
        THROW;
    END CATCH
END
GO
