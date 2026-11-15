/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-15
 Script       : 91_Test_SP_Reportes_Validaciones.sql
 Objetivo     : Testing de las validaciones de 89_SP_Reportes.sql (relacion 1:1).
                Cada caso invalido muestra el numero de error y el mensaje. Los
                reportes solo leen datos, asi que este test no modifica la base.
 Requisito    : ejecutar despues de 89_SP_Reportes.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

PRINT '=== Prueba 1: goleadores de una seleccion que no existe ===';
-- Resultado esperado: error 50001: "La seleccion indicada no existe."
BEGIN TRY
    EXEC Reportes.usp_ReportarGoleadores @IdSeleccion = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: tarjetas de una seleccion que no existe ===';
-- Resultado esperado: error 50001: "La seleccion indicada no existe."
BEGIN TRY
    EXEC Reportes.usp_ReportarTarjetas @IdSeleccion = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: designaciones de un arbitro que no existe ===';
-- Resultado esperado: error 50001: "El arbitro indicado no existe."
BEGIN TRY
    EXEC Reportes.usp_ReportarDesignaciones @IdArbitro = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: ocupacion publicitaria con sede y partido que no existen ===';
-- Resultado esperado: error 50001 con 2 condiciones: la sede y el partido no existen.
BEGIN TRY
    EXEC Reportes.usp_ReportarOcupacionPublicitaria @IdSede = -1, @IdPartido = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: matriz con horas fuera de rango ===';
-- Resultado esperado: error 50001 con 2 condiciones: la hora de inicio debe estar entre 0 y 23
-- y la de fin entre 1 y 24.
BEGIN TRY
    EXEC Reportes.usp_ReportarMatrizPrimeTime @HoraDesde = 25, @HoraHasta = 0;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: matriz con la hora de inicio mayor que la de fin ===';
-- Resultado esperado: error 50001: "La hora de inicio debe ser menor que la de fin."
BEGIN TRY
    EXEC Reportes.usp_ReportarMatrizPrimeTime @HoraDesde = 22, @HoraHasta = 20;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: matriz de un partido que no existe ===';
-- Resultado esperado: error 50001: "El partido indicado no existe."
BEGIN TRY
    EXEC Reportes.usp_ReportarMatrizPrimeTime @IdPartido = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: plantilla de una seleccion que no existe ===';
-- Resultado esperado: error 50001: "La seleccion indicada no existe."
BEGIN TRY
    EXEC Reportes.usp_ReportarPlantillas @IdSeleccion = -1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: resultados con seleccion y fase invalidas ===';
-- Resultado esperado: error 50001 con 2 condiciones: la seleccion no existe y la fase no es valida.
BEGIN TRY
    EXEC Reportes.usp_ReportarResultados @IdSeleccion = -1, @Fase = 'Repechaje';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO
