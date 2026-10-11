/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 95_Test_SP_Negocio_DesignacionArbitral_Validaciones.sql
 Objetivo     : Testing de las validaciones de 93_SP_Negocio_DesignacionArbitral.sql.
                Cada caso invalido se ejecuta dentro de TRY/CATCH: muestra el numero de
                error y el mensaje unico que agrupa todas las condiciones que no se
                cumplen. Para las pruebas con un partido sin selecciones se crea un
                partido temporal (PARTIDO-934) que se elimina al terminar.
 Requisito    : ejecutar despues de 94_Test_SP_Negocio_DesignacionArbitral_OK.sql. Estado:
                ARB-DES-01 a 04 designados en PARTIDO-931 (Francia contra Mexico, 22:00
                UTC del 12/07); ARB-DES-05 Principal en PARTIDO-932 (Argentina contra Brasil,
                23:00 UTC del 12/07); ARB-DES-01 Principal en PARTIDO-933 (Argentina contra
                Francia, 16/07); ARB-DES-06 (frances) sin designaciones.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdPA INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-931');
DECLARE @IdPB INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'PARTIDO-932');
DECLARE @IdPD INT;
DECLARE @Arb1 INT, @Arb2 INT, @Arb5 INT, @Arb6 INT;

SELECT @Arb1 = MAX(CASE WHEN CodigoExterno = 'ARB-DES-01' THEN IdArbitro ELSE 0 END),
       @Arb2 = MAX(CASE WHEN CodigoExterno = 'ARB-DES-02' THEN IdArbitro ELSE 0 END),
       @Arb5 = MAX(CASE WHEN CodigoExterno = 'ARB-DES-05' THEN IdArbitro ELSE 0 END),
       @Arb6 = MAX(CASE WHEN CodigoExterno = 'ARB-DES-06' THEN IdArbitro ELSE 0 END)
FROM Arbitraje.Arbitro;

-- Partido temporal de semifinal con el cruce todavia sin definir (sin selecciones)
EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-934', @NumeroPartido = 934, @Fase = 'Semifinal',
     @FechaHoraUtc = '2026-07-20 20:00', @CodigoExternoSede = 'SEDE-SOFI', @IdPartido = @IdPD OUTPUT;

SELECT COUNT(*) AS DesignacionesDePrueba
FROM Arbitraje.DesignacionArbitral d JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE a.CodigoExterno LIKE 'ARB-DES-%';     -- esperado: 6

/*------------------------------------------------------------------------------
 DESIGNAR ARBITRO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: partido y arbitro inexistentes, y rol vacio ===';
-- Resultado esperado: error 50001 con 3 condiciones: el partido no existe, el arbitro no existe y el rol
-- arbitral es obligatorio.
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = 999, @IdArbitro = 999, @RolArbitral = '';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 2: partido sin selecciones definidas ===';
-- Resultado esperado: error 50001 con 1 condicion: el partido necesita las dos selecciones definidas para
-- designar arbitro (PARTIDO-934 es una semifinal con el cruce por definir).
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPD, @IdArbitro = @Arb6, @RolArbitral = 'Principal';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 3: partido sin selecciones y arbitro inexistente ===';
-- Resultado esperado: error 50001 con 2 condiciones: el partido necesita las dos selecciones definidas y el
-- arbitro indicado no existe.
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPD, @IdArbitro = 999, @RolArbitral = 'Principal';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 4: arbitro de la misma nacionalidad que una de las selecciones ===';
-- Resultado esperado: error 50001 con 1 condicion: el arbitro no puede ser de la misma nacionalidad que alguna
-- de las selecciones del partido (ARB-DES-06 es frances y PARTIDO-931 es Francia contra Mexico).
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb6, @RolArbitral = 'VAR';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 5: arbitro de la misma nacionalidad y designado en otro partido a una hora ===';
-- Resultado esperado: error 50001 con 2 condiciones: el arbitro no puede ser de la misma nacionalidad que alguna
-- de las selecciones (ARB-DES-05 es mexicano y PARTIDO-931 es Francia contra Mexico) y ya esta designado en
-- otro partido con menos de 180 minutos de diferencia (PARTIDO-932, una hora despues).
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb5, @RolArbitral = 'VAR';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 6: arbitro ya designado en el partido y sin rol ===';
-- Resultado esperado: error 50001 con 2 condiciones: el rol arbitral es obligatorio y el arbitro ya esta
-- designado en este partido (ARB-DES-01 ya es Principal de PARTIDO-931).
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb1, @RolArbitral = NULL;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 7: arbitro designado en otro partido con menos de 180 minutos de diferencia ===';
-- Resultado esperado: error 50001 con 1 condicion: el arbitro ya esta designado en otro partido con menos de
-- 180 minutos de diferencia (ARB-DES-02 es Asistente 1 de PARTIDO-931, a las 22:00 UTC, y PARTIDO-932 es a las
-- 23:00 UTC).
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPB, @IdArbitro = @Arb2, @RolArbitral = 'Asistente 1';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 8: rol que no existe ===';
-- Resultado esperado: error 50001 con 1 condicion: el rol arbitral debe ser Principal, Asistente 1,
-- Asistente 2, Cuarto o VAR ('Linea' no es un rol valido). Sin esta validacion fallaria el CHECK de la tabla con
-- el error crudo de la constraint.
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPB, @IdArbitro = @Arb6, @RolArbitral = 'Linea';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 9: rol que el partido ya tiene cubierto ===';
-- Resultado esperado: error 50001 con 1 condicion: el partido ya tiene un arbitro designado con ese rol
-- (ARB-DES-05 ya es Principal de PARTIDO-932). Sin esta validacion fallaria el UNIQUE (IdPartido, RolArbitral)
-- con el error crudo de la constraint.
BEGIN TRY
    EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPB, @IdArbitro = @Arb6, @RolArbitral = 'Principal';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

/*------------------------------------------------------------------------------
 ARBITROS ELEGIBLES
------------------------------------------------------------------------------*/
PRINT '=== Prueba 10: elegibles de un partido inexistente ===';
-- Resultado esperado: error 50001: "El partido indicado no existe."
BEGIN TRY
    EXEC Arbitraje.usp_ListarArbitrosElegibles @IdPartido = 999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

PRINT '=== Prueba 11: elegibles de un partido sin selecciones definidas ===';
-- Resultado esperado: error 50001: "El partido necesita las dos selecciones definidas para listar arbitros
-- elegibles." (en lugar de devolver una lista vacia).
BEGIN TRY
    EXEC Arbitraje.usp_ListarArbitrosElegibles @IdPartido = @IdPD;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;
END CATCH

-- Se elimina el partido temporal
EXEC Torneo.usp_Partido_Baja @IdPartido = @IdPD;

SELECT (SELECT COUNT(*)
        FROM Arbitraje.DesignacionArbitral d JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
        WHERE a.CodigoExterno LIKE 'ARB-DES-%') AS DesignacionesDePrueba,
       (SELECT COUNT(*) FROM Torneo.Partido
        WHERE CodigoExterno IN ('PARTIDO-931', 'PARTIDO-932', 'PARTIDO-933', 'PARTIDO-934')) AS PartidosDePrueba;   -- esperado: 6, 3 (las pruebas no cambiaron nada)
GO
