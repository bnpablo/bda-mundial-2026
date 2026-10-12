/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 52_Test_SP_ABM_Arbitraje_Validaciones.sql
 Objetivo     : Testing de las validaciones de 50_SP_ABM_Arbitraje.sql (relacion 1:1).
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero
                de error y el mensaje unico que agrupa todas las condiciones que no
                se cumplen. Incluye el conflicto de nacionalidad (error 50002).
 Requisito    : ejecutar despues de 51_Test_SP_ABM_Arbitraje_OK.sql. Estado: INC-P0
                Finalizado (Silva Principal con informe, Rossi VAR); INC-P1 Programado
                (Uruguay - Colombia: Rossi Principal, Silva Cuarto).
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisUry INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'URY');
DECLARE @PaisPor INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'POR');
DECLARE @ArbIta INT = (SELECT IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = 'ARB-ITA');
DECLARE @ArbPor INT = (SELECT IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = 'ARB-POR');
DECLARE @ArbUry INT = (SELECT IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = 'ARB-URY');
DECLARE @IdP0 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P0');
DECLARE @IdP1 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P1');
DECLARE @DesigItaP1 INT = (SELECT IdDesignacion FROM Arbitraje.DesignacionArbitral WHERE IdPartido = @IdP1 AND IdArbitro = @ArbIta);
DECLARE @DesigPorP0 INT = (SELECT IdDesignacion FROM Arbitraje.DesignacionArbitral WHERE IdPartido = @IdP0 AND IdArbitro = @ArbPor);

SELECT (SELECT COUNT(*) FROM Arbitraje.Arbitro) AS Arbitros,
       (SELECT COUNT(*) FROM Arbitraje.DesignacionArbitral) AS Designaciones;   -- esperado: 3, 4

/*------------------------------------------------------------------------------
 ARBITRO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta con varios datos invalidos ===';
-- Resultado esperado: error 50001 con 5 condiciones: codigo externo obligatorio, nombre obligatorio, pais
-- inexistente, categoria invalida y arbitro menor de 18 anios.
BEGIN TRY
    EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = '', @Nombre = '', @Apellido = 'Gomez', @IdPais = 999,
         @Categoria = 'Local', @FechaNacimiento = '2015-01-01';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: alta con codigo externo repetido ===';
-- Resultado esperado: error 50001: "Ya existe un arbitro con ese codigo externo."
BEGIN TRY
    EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-ITA', @Nombre = 'Otro', @Apellido = 'Arbitro',
         @IdPais = @PaisPor, @Categoria = 'FIFA';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: modificacion de un arbitro inexistente ===';
-- Resultado esperado: error 50001: "El arbitro indicado no existe."
BEGIN TRY
    EXEC Arbitraje.usp_Arbitro_Modificacion @IdArbitro = 999, @CodigoExterno = 'ARB-NUEVO', @Nombre = 'Nadie',
         @Apellido = 'Nadie', @IdPais = @PaisPor, @Categoria = 'FIFA';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: cambiar el pais de un arbitro designado a un pais del partido ===';
-- Resultado esperado: error 50002 (conflicto de negocio): Silva esta designado en INC-P1 (Uruguay - Colombia),
-- que todavia no se jugo, y pasaria a ser uruguayo. El arbitro no cambia.
BEGIN TRY
    EXEC Arbitraje.usp_Arbitro_Modificacion @IdArbitro = @ArbPor, @CodigoExterno = 'ARB-POR', @Nombre = 'Joao',
         @Apellido = 'Silva', @IdPais = @PaisUry, @Categoria = 'Confederacion', @FechaNacimiento = '1988-11-02';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT p.CodigoIso3 AS PaisDeSilva FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.IdArbitro = @ArbPor;                                                       -- esperado: POR

PRINT '=== Prueba 5: baja de un arbitro con designaciones ===';
-- Resultado esperado: error 50001: "El arbitro tiene designaciones registradas."
BEGIN TRY
    EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @ArbIta;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 ARBITRO IDIOMA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 6: alta de idioma para un arbitro inexistente y sin idioma ===';
-- Resultado esperado: error 50001 con 2 condiciones: el arbitro no existe y el idioma es obligatorio.
BEGIN TRY
    EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = 999, @Idioma = '';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: alta de un idioma repetido ===';
-- Resultado esperado: error 50001: "El arbitro ya tiene registrado ese idioma." (Rossi ya habla en).
BEGIN TRY
    EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @ArbIta, @Idioma = 'en';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: modificar un idioma que no tiene por uno que ya tiene ===';
-- Resultado esperado: error 50001 con 2 condiciones: Silva no tiene registrado fr y ya tiene registrado pt.
BEGIN TRY
    EXEC Arbitraje.usp_ArbitroIdioma_Modificacion @IdArbitro = @ArbPor, @Idioma = 'fr', @IdiomaNuevo = 'pt';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: baja de un idioma que el arbitro no tiene ===';
-- Resultado esperado: error 50001: "El arbitro no tiene registrado ese idioma."
BEGIN TRY
    EXEC Arbitraje.usp_ArbitroIdioma_Baja @IdArbitro = @ArbIta, @Idioma = 'fr';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 DESIGNACION ARBITRAL
------------------------------------------------------------------------------*/
PRINT '=== Prueba 10: rol ocupado y arbitro ya designado ===';
-- Resultado esperado: error 50001 con 2 condiciones: el rol Principal ya esta cubierto en INC-P1 y Silva ya
-- tiene otro rol en ese partido.
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP1, @IdArbitro = @ArbPor, @RolArbitral = 'Principal';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: conflicto de nacionalidad (caso obligatorio) ===';
-- Resultado esperado: error 50002: "Conflicto de nacionalidad: el arbitro es del mismo pais que una de las
-- selecciones del partido." Cunha es uruguayo y juega Uruguay. No se registra la designacion.
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP1, @IdArbitro = @ArbUry, @RolArbitral = 'VAR';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
SELECT COUNT(*) AS DesignacionesDeCunha FROM Arbitraje.DesignacionArbitral WHERE IdArbitro = @ArbUry;   -- esperado: 0

PRINT '=== Prueba 12: designacion en un partido finalizado, con arbitro y rol invalidos ===';
-- Resultado esperado: error 50001 con 3 condiciones: no se pueden designar arbitros en un partido Finalizado
-- (INC-P0), el arbitro no existe y el rol es invalido.
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP0, @IdArbitro = 999, @RolArbitral = 'Linea';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 13: cambiar el arbitro de una designacion por uno con conflicto de nacionalidad ===';
-- Resultado esperado: error 50002: Rossi no puede ser reemplazado por Cunha en INC-P1.
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Modificacion @IdDesignacion = @DesigItaP1, @IdArbitro = @ArbUry,
         @RolArbitral = 'Principal';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 14: cargar el informe post-partido antes de que se juegue el partido ===';
-- Resultado esperado: error 50001: "El informe post-partido y la sancion se cargan cuando el partido esta
-- Finalizado." (INC-P1 esta Programado).
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Modificacion @IdDesignacion = @DesigItaP1, @IdArbitro = @ArbIta,
         @RolArbitral = 'Principal', @InformePostPartido = 'Partido sin incidentes.';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 15: cambiar el rol con el partido finalizado ===';
-- Resultado esperado: error 50001: "Con el partido finalizado no se pueden cambiar el arbitro ni el rol."
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Modificacion @IdDesignacion = @DesigPorP0, @IdArbitro = @ArbPor,
         @RolArbitral = 'Cuarto', @InformePostPartido = 'Partido sin incidentes graves.', @Sancion = 'Sin sancion';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 16: baja de una designacion de un partido finalizado ===';
-- Resultado esperado: error 50001: "El partido esta finalizado: la designacion forma parte del historial y no se
-- elimina."
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Baja @IdDesignacion = @DesigPorP0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 17: baja de una designacion inexistente ===';
-- Resultado esperado: error 50001: "La designacion indicada no existe."
BEGIN TRY
    EXEC Arbitraje.usp_DesignacionArbitral_Baja @IdDesignacion = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

SELECT (SELECT COUNT(*) FROM Arbitraje.Arbitro) AS Arbitros,
       (SELECT COUNT(*) FROM Arbitraje.DesignacionArbitral) AS Designaciones;   -- esperado: 3, 4
GO
