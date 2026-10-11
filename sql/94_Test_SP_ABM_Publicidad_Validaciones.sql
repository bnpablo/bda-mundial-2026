/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 94_Test_SP_ABM_Publicidad_Validaciones.sql
 Objetivo     : Testing de las validaciones de 92_SP_ABM_Publicidad.sql (relacion 1:1).
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero
                de error y el mensaje unico que agrupa todas las condiciones que no
                se cumplen. La prueba 15 vende un espacio para probar las reglas
                que dependen de el y al final lo elimina, asi que el script no deja
                datos nuevos.
 Requisito    : ejecutar despues de 93_Test_SP_ABM_Publicidad_OK.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisUry INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'URY');
DECLARE @IdP0 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P0');
DECLARE @IdP5 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P5');
DECLARE @IdP6 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P6');
DECLARE @AnBebidas INT = (SELECT IdAnunciante FROM Publicidad.Anunciante WHERE Nombre = 'Bebidas del Sur');
DECLARE @CaBebidas INT = (SELECT IdCampania FROM Publicidad.Campania WHERE IdAnunciante = @AnBebidas);
DECLARE @CaTelefonia INT = (SELECT c.IdCampania FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
                            WHERE a.Nombre = 'Telefonia Global');
DECLARE @PzUruguay INT = (SELECT IdPieza FROM Publicidad.Pieza WHERE Nombre = 'Spot Uruguay');
DECLARE @PzEstadosUnidos INT = (SELECT IdPieza FROM Publicidad.Pieza WHERE Nombre = 'Spot Estados Unidos');
DECLARE @TaTercer INT = (SELECT IdTarifa FROM Publicidad.TarifaPublicitaria WHERE Fase = 'Tercer puesto');
DECLARE @IdEspacio INT;

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes, (SELECT COUNT(*) FROM Publicidad.Campania) AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza) AS Piezas, (SELECT COUNT(*) FROM Publicidad.TarifaPublicitaria) AS Tarifas,
       (SELECT COUNT(*) FROM Publicidad.PublicidadPartido) AS Espacios;      -- esperado: 5, 5, 6, 2, 0

/*------------------------------------------------------------------------------
 ANUNCIANTE Y CAMPANIA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: anunciante sin nombre ===';
-- Resultado esperado: error 50001: "El nombre del anunciante es obligatorio."
BEGIN TRY
    EXEC Publicidad.usp_Anunciante_Alta @Nombre = '';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: anunciante con nombre repetido ===';
-- Resultado esperado: error 50001: "Ya existe un anunciante con ese nombre."
BEGIN TRY
    EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Bebidas del Sur';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: baja de un anunciante con campanias ===';
-- Resultado esperado: error 50001: "El anunciante tiene campanias registradas."
BEGIN TRY
    EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = @AnBebidas;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: campania con varios datos invalidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: el anunciante no existe, el nombre es obligatorio y la
-- fecha de fin es anterior a la de inicio.
BEGIN TRY
    EXEC Publicidad.usp_Campania_Alta @IdAnunciante = 999, @Nombre = '', @FechaInicio = '2026-07-31', @FechaFin = '2026-06-01';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: modificar una campania inexistente sin fechas ===';
-- Resultado esperado: error 50001 con 2 condiciones: la campania no existe y las fechas son obligatorias.
BEGIN TRY
    EXEC Publicidad.usp_Campania_Modificacion @IdCampania = 999, @Nombre = 'Otra', @FechaInicio = NULL, @FechaFin = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: baja de una campania con piezas ===';
-- Resultado esperado: error 50001: "La campania tiene piezas registradas."
BEGIN TRY
    EXEC Publicidad.usp_Campania_Baja @IdCampania = @CaBebidas;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 PIEZA Y PIEZA PAIS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 7: pieza con todos los datos invalidos ===';
-- Resultado esperado: error 50001 con 4 condiciones: la campania no existe, el nombre y el idioma son
-- obligatorios y la duracion debe estar entre 1 y 300 segundos.
BEGIN TRY
    EXEC Publicidad.usp_Pieza_Alta @IdCampania = 999, @Nombre = '', @Idioma = '', @DuracionSegundos = 0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: baja de una pieza inexistente ===';
-- Resultado esperado: error 50001: "La pieza indicada no existe."
BEGIN TRY
    EXEC Publicidad.usp_Pieza_Baja @IdPieza = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: pais de interes con pieza y pais inexistentes ===';
-- Resultado esperado: error 50001 con 2 condiciones: la pieza no existe y el pais no existe.
BEGIN TRY
    EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = 999, @IdPais = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 10: pais de interes repetido ===';
-- Resultado esperado: error 50001: "La pieza ya tiene cargado ese pais." (Spot Uruguay ya tiene URY).
BEGIN TRY
    EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzUruguay, @IdPais = @PaisUry;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: quitar el unico pais de interes de una pieza ===';
-- Resultado esperado: error 50001: "Es el unico pais de interes de la pieza: agregue otro antes de quitarlo."
BEGIN TRY
    EXEC Publicidad.usp_PiezaPais_Baja @IdPieza = @PzUruguay, @IdPais = @PaisUry;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 TARIFA PUBLICITARIA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 12: tarifa con varios datos invalidos ===';
-- Resultado esperado: error 50001 con 4 condiciones: fase invalida, moneda que no tiene 3 letras, monto que
-- no es mayor a cero y fin de vigencia anterior al inicio.
BEGIN TRY
    EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = 'Mundial', @Moneda = 'US', @Monto = 0,
         @VigenteDesde = '2026-07-31', @VigenteHasta = '2026-07-01';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: tarifa superpuesta con otra de la misma fase ===';
-- Resultado esperado: error 50001: "La vigencia se superpone con otra tarifa de la misma fase." (ya hay una
-- tarifa de Grupos vigente en junio).
BEGIN TRY
    EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = 'Grupos', @Moneda = 'USD', @Monto = 60000,
         @VigenteDesde = '2026-06-15', @VigenteHasta = '2026-07-15';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 PUBLICIDAD PARTIDO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 14: espacio en un partido finalizado, con espacio y pieza invalidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: el partido esta finalizado (INC-P0), el numero de espacio
-- debe estar entre 1 y 4 y la pieza no existe.
BEGIN TRY
    EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @IdP0, @NumeroEspacio = 5, @IdPieza = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 15: espacio en un partido de una fase sin tarifa ===';
-- Resultado esperado: error 50001: "No hay una tarifa vigente para la fase del partido en su fecha." (INC-P5 es
-- de Cuartos y no hay tarifa de Cuartos).
BEGIN TRY
    EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @IdP5, @NumeroEspacio = 1, @IdPieza = @PzUruguay;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 16: reglas que dependen de un espacio vendido ===';
-- Se vende el espacio 1 de INC-P6 a Spot Estados Unidos (alta valida) y se prueba:
--   a) Volver a venderlo con la misma pieza: error 50001 con 2 condiciones (el espacio esta ocupado y la pieza
--      ya ocupa otro espacio en el partido).
--   b) Pasarlo a Exhibida con el partido sin jugar: "La exhibicion se registra con el partido Finalizado."
--   c) Volverlo a Propuesta: "No se puede pasar del estado Confirmada a Propuesta."
--   d) Acortar la campania de Telefonia Global al 10/07: "Con las nuevas fechas quedarian afuera partidos donde
--      la campania ya tiene espacios." (INC-P6 es el 18/07).
--   e) Cambiar el monto de la tarifa de Tercer puesto: "La tarifa ya se aplico a espacios: solo se puede cerrar su
--      vigencia y cargar el precio nuevo como otra tarifa."
--   f) Eliminar esa tarifa: "La tarifa esta aplicada a espacios de partidos: cierre su vigencia en lugar de
--      eliminarla."
-- Al final se elimina el espacio vendido (baja valida).
EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @IdP6, @NumeroEspacio = 1, @IdPieza = @PzEstadosUnidos,
     @IdPublicidadPartido = @IdEspacio OUTPUT;

BEGIN TRY
    EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @IdP6, @NumeroEspacio = 1, @IdPieza = @PzEstadosUnidos;
END TRY
BEGIN CATCH
    SELECT 'a' AS Caso, ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

BEGIN TRY
    EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @IdEspacio, @NumeroEspacio = 1, @Estado = 'Exhibida';
END TRY
BEGIN CATCH
    SELECT 'b' AS Caso, ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

BEGIN TRY
    EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @IdEspacio, @NumeroEspacio = 1, @Estado = 'Propuesta';
END TRY
BEGIN CATCH
    SELECT 'c' AS Caso, ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

BEGIN TRY
    EXEC Publicidad.usp_Campania_Modificacion @IdCampania = @CaTelefonia, @Nombre = 'Mundial 2026',
         @FechaInicio = '2026-06-01', @FechaFin = '2026-07-10';
END TRY
BEGIN CATCH
    SELECT 'd' AS Caso, ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

BEGIN TRY
    EXEC Publicidad.usp_TarifaPublicitaria_Modificacion @IdTarifa = @TaTercer, @Fase = 'Tercer puesto', @Moneda = 'USD',
         @Monto = 90000, @VigenteDesde = '2026-07-01', @VigenteHasta = '2026-07-31';
END TRY
BEGIN CATCH
    SELECT 'e' AS Caso, ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

BEGIN TRY
    EXEC Publicidad.usp_TarifaPublicitaria_Baja @IdTarifa = @TaTercer;
END TRY
BEGIN CATCH
    SELECT 'f' AS Caso, ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

EXEC Publicidad.usp_PublicidadPartido_Baja @IdPublicidadPartido = @IdEspacio;

PRINT '=== Prueba 17: modificar un espacio inexistente ===';
-- Resultado esperado: error 50001: "La asignacion indicada no existe."
BEGIN TRY
    EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = 999, @NumeroEspacio = 1, @Estado = 'Confirmada';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes, (SELECT COUNT(*) FROM Publicidad.Campania) AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza) AS Piezas, (SELECT COUNT(*) FROM Publicidad.TarifaPublicitaria) AS Tarifas,
       (SELECT COUNT(*) FROM Publicidad.PublicidadPartido) AS Espacios;      -- esperado: 5, 5, 6, 2, 0
GO
