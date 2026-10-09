/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 85_Test_SP_Negocio_Convocatoria_Validaciones.sql
 Objetivo     : Testing de las validaciones de 83_SP_Negocio_Convocatoria.sql (relacion
                1:1). Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el
                numero de error y el mensaje unico que agrupa todas las condiciones que
                no se cumplen. Las pruebas 3 y 6 comprueban que la operacion es "todo
                o nada".
 Requisito    : ejecutar despues de 84_Test_SP_Negocio_Convocatoria_OK.sql. Estado de las
                convocatorias: Argentina 25 activos (ARG-26 de baja), Brasil 23 activos
                (BRA-05 de baja y BRA-24 como reemplazo), Espana con su director tecnico.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisBra INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'BRA');
DECLARE @PaisEsp INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ESP');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @IdBra05 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'BRA-05');
DECLARE @IdBra06 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'BRA-06');
DECLARE @IdArg26 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'ARG-26');

SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico,
       (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @SelBra AND FechaBaja IS NULL) AS ConvocadosBrasil;   -- esperado: 6, 2, 23

/*------------------------------------------------------------------------------
 REGISTRAR SELECCION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: director tecnico sin nombre ni apellido ===';
-- Resultado esperado: error 50001 con 2 condiciones: el nombre y el apellido del director tecnico son
-- obligatorios.
BEGIN TRY
    EXEC Torneo.usp_RegistrarSeleccion @CodigoExterno = 'SEL-NUEVA', @IdPais = @PaisEsp, @Grupo = 'G',
         @NombreDirector = '', @ApellidoDirector = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: seleccion repetida ===';
-- Resultado esperado: error 50001 de usp_Seleccion_Alta con 2 condiciones: ya existe una seleccion con ese codigo
-- externo y el pais ya tiene una seleccion registrada.
BEGIN TRY
    EXEC Torneo.usp_RegistrarSeleccion @CodigoExterno = 'SEL-ESP', @IdPais = @PaisEsp, @Grupo = 'G',
         @NombreDirector = 'Otro', @ApellidoDirector = 'Director';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico;   -- esperado: 6, 2

/*------------------------------------------------------------------------------
 BAJA Y REEMPLAZO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 3: jugador inexistente, motivo invalido y sin fecha ===';
-- Resultado esperado: error 50001 con 3 condiciones: el jugador no existe, el motivo de la baja debe ser Lesion,
-- Enfermedad u Otro y la fecha de la baja es obligatoria.
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaYReemplazo @IdJugadorBaja = 999999, @MotivoBaja = 'Cansancio', @FechaBaja = NULL,
         @CodigoExternoReemplazo = 'BRA-30', @NombreReemplazo = 'Jugador', @ApellidoReemplazo = 'Nuevo',
         @IdPaisReemplazo = @PaisBra, @DorsalReemplazo = 30, @PosicionReemplazo = 'DEL', @ClubReemplazo = 'Club Demo';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: dar de baja a un jugador que ya esta de baja ===';
-- Resultado esperado: error 50001: "El jugador ya esta dado de baja." (BRA-05 se dio de baja en el script 84).
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaYReemplazo @IdJugadorBaja = @IdBra05, @MotivoBaja = 'Lesion', @FechaBaja = '2026-06-03',
         @CodigoExternoReemplazo = 'BRA-30', @NombreReemplazo = 'Jugador', @ApellidoReemplazo = 'Nuevo',
         @IdPaisReemplazo = @PaisBra, @DorsalReemplazo = 30, @PosicionReemplazo = 'DEL', @ClubReemplazo = 'Club Demo';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: fecha de baja anterior a la fecha de alta ===';
-- Resultado esperado: error 50001: "La fecha de la baja no puede ser anterior a la fecha de alta del jugador."
-- (BRA-06 se convoco el 20/05/2026).
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaYReemplazo @IdJugadorBaja = @IdBra06, @MotivoBaja = 'Lesion', @FechaBaja = '2026-05-01',
         @CodigoExternoReemplazo = 'BRA-30', @NombreReemplazo = 'Jugador', @ApellidoReemplazo = 'Nuevo',
         @IdPaisReemplazo = @PaisBra, @DorsalReemplazo = 30, @PosicionReemplazo = 'DEL', @ClubReemplazo = 'Club Demo';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: baja valida pero reemplazo invalido (todo o nada) ===';
-- Resultado esperado: error 50001 de usp_Jugador_Alta con 2 condiciones: ya existe un jugador con ese codigo
-- externo y ese dorsal ya fue asignado en la seleccion. Como el reemplazo no se pudo registrar, la baja de BRA-06
-- tambien se deshace: su FechaBaja sigue en NULL y Brasil conserva 23 convocados activos.
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaYReemplazo @IdJugadorBaja = @IdBra06, @MotivoBaja = 'Lesion', @FechaBaja = '2026-06-03',
         @CodigoExternoReemplazo = 'BRA-01', @NombreReemplazo = 'Jugador', @ApellidoReemplazo = 'Repetido',
         @IdPaisReemplazo = @PaisBra, @DorsalReemplazo = 1, @PosicionReemplazo = 'POR', @ClubReemplazo = 'Club Demo';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT CodigoExterno, FechaBaja, MotivoBaja, IdJugadorReemplazo FROM Torneo.Jugador WHERE IdJugador = @IdBra06;     -- esperado: FechaBaja NULL
SELECT COUNT(*) AS ConvocadosBrasil FROM Torneo.Jugador WHERE IdSeleccion = @SelBra AND FechaBaja IS NULL;          -- esperado: 23

/*------------------------------------------------------------------------------
 BAJA SIN REEMPLAZO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 7: baja que deja a la seleccion por debajo del minimo ===';
-- Resultado esperado: error 50001: "La seleccion quedaria con menos de 23 convocados: registre un reemplazo."
-- (Brasil tiene justo 23 activos). BRA-06 sigue convocado.
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaJugador @IdJugador = @IdBra06, @MotivoBaja = 'Lesion', @FechaBaja = '2026-06-03';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT COUNT(*) AS ConvocadosBrasil FROM Torneo.Jugador WHERE IdSeleccion = @SelBra AND FechaBaja IS NULL;          -- esperado: 23

PRINT '=== Prueba 8: baja de un jugador inexistente, con motivo invalido y sin fecha ===';
-- Resultado esperado: error 50001 con 3 condiciones: el jugador no existe, el motivo de la baja es invalido y la
-- fecha de la baja es obligatoria.
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaJugador @IdJugador = 999999, @MotivoBaja = 'Otro motivo', @FechaBaja = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: baja de un jugador que ya esta de baja ===';
-- Resultado esperado: error 50001: "El jugador ya esta dado de baja." (ARG-26 se dio de baja en el script 84).
BEGIN TRY
    EXEC Torneo.usp_RegistrarBajaJugador @IdJugador = @IdArg26, @MotivoBaja = 'Lesion', @FechaBaja = '2026-06-04';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 ABM SOBRE JUGADORES DADOS DE BAJA (20_SP_ABM_Seleccion.sql)
------------------------------------------------------------------------------*/
PRINT '=== Prueba 10: eliminar y modificar a un jugador dado de baja ===';
-- Resultado esperado: dos errores 50001. Eliminar: el jugador tiene una baja de ultimo momento registrada, forma
-- parte del historial y no se elimina. Modificar: el jugador esta dado de baja y no puede modificarse.
BEGIN TRY
    EXEC Torneo.usp_Jugador_Baja @IdJugador = @IdBra05;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
BEGIN TRY
    EXEC Torneo.usp_Jugador_Modificacion @IdJugador = @IdBra05, @CodigoExterno = 'BRA-05', @Nombre = 'Jugador',
         @Apellido = 'Brasil 05', @IdPais = @PaisBra, @IdSeleccion = @SelBra, @Dorsal = 5, @PosicionHabitual = 'DEF',
         @ClubOrigen = 'Club Demo', @FechaAlta = '2026-05-20';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Torneo.Seleccion) AS Selecciones, (SELECT COUNT(*) FROM Torneo.CuerpoTecnico) AS CuerpoTecnico,
       (SELECT COUNT(*) FROM Torneo.Jugador WHERE IdSeleccion = @SelBra AND FechaBaja IS NULL) AS ConvocadosBrasil;   -- esperado: 6, 2, 23
GO
