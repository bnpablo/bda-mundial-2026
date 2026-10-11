/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 97_Test_SP_Negocio_Publicidad_Validaciones.sql
 Objetivo     : Testing de las validaciones de 95_SP_Negocio_Publicidad.sql (relacion
                1:1). Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el
                numero de error y el mensaje unico que agrupa todas las condiciones
                que no se cumplen.
 Requisito    : ejecutar despues de 96_Test_SP_Negocio_Publicidad_OK.sql. Estado:
                INC-P0 y INC-P2 Finalizados (INC-P2 con 2 espacios Exhibidos y 2
                Descartados), INC-P5 En juego (Cuartos, sin tarifa) e INC-P6
                Programado sin espacios.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdP0 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P0');
DECLARE @IdP2 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P2');
DECLARE @IdP5 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P5');
DECLARE @IdP6 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P6');

SELECT COUNT(*) AS Espacios FROM Publicidad.PublicidadPartido;      -- esperado: 4

/*------------------------------------------------------------------------------
 ASIGNAR PIEZAS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: asignar piezas a un partido inexistente ===';
-- Resultado esperado: error 50001: "El partido indicado no existe."
BEGIN TRY
    EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: asignar piezas a un partido finalizado ===';
-- Resultado esperado: error 50001: "El partido esta finalizado: no se le asigna publicidad." (INC-P0).
BEGIN TRY
    EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = @IdP0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: recalcular un partido con espacios exhibidos ===';
-- Resultado esperado: error 50001 con 2 condiciones: el partido esta finalizado y ya tiene espacios
-- confirmados o exhibidos (INC-P2). Lo exhibido no se toca.
BEGIN TRY
    EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = @IdP2;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: asignar piezas a un partido de una fase sin tarifa ===';
-- Resultado esperado: error 50001: "No hay una tarifa vigente para la fase del partido en su fecha." (INC-P5,
-- Cuartos).
BEGIN TRY
    EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = @IdP5;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 REGISTRAR EXHIBICION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 5: registrar la exhibicion de un partido que no se jugo ===';
-- Resultado esperado: error 50001 con 2 condiciones: el partido todavia no esta finalizado y no tiene espacios
-- propuestos ni confirmados (INC-P6).
BEGIN TRY
    EXEC Publicidad.usp_RegistrarExhibicion @IdPartido = @IdP6;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: registrar dos veces la exhibicion ===';
-- Resultado esperado: error 50001: "El partido no tiene espacios propuestos ni confirmados para cerrar."
-- (INC-P2 ya se cerro en el script 96).
BEGIN TRY
    EXEC Publicidad.usp_RegistrarExhibicion @IdPartido = @IdP2;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: registrar la exhibicion de un partido inexistente ===';
-- Resultado esperado: error 50001: "El partido indicado no existe."
BEGIN TRY
    EXEC Publicidad.usp_RegistrarExhibicion @IdPartido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT Estado, COUNT(*) AS Espacios FROM Publicidad.PublicidadPartido GROUP BY Estado;
-- esperado: Descartada 2 y Exhibida 2 (ningun caso invalido cambio datos)
GO
