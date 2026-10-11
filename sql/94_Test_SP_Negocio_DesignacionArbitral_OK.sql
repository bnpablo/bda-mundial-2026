/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 94_Test_SP_Negocio_DesignacionArbitral_OK.sql
 Objetivo     : Testing exitoso de 93_SP_Negocio_DesignacionArbitral.sql: listar los
                arbitros elegibles de un partido y designar arbitros. Para no depender
                de las designaciones de los scripts anteriores se crean 6 arbitros
                (ARB-DES-01 a 06) y 3 partidos propios (PARTIDO-931 a 933). Los datos se
                cargan unicamente con los SP.
 Requisito    : ejecutar despues de 88_Test_SP_Negocio_Alineaciones_Validaciones.sql y
                de 52 (tests de Arbitraje), una sola vez. Usa los paises Estados Unidos,
                Espana y Mexico, las selecciones de Argentina, Brasil, Francia y Mexico y
                las sedes MetLife y SoFi, que cargan los scripts 11, 21, 81 y 84.
 Supuestos    : Arbitraje.usp_Arbitro_Alta (50_SP_ABM_Arbitraje.sql) recibe @CodigoExterno,
                @Nombre, @Apellido, @FechaNacimiento, @IdPais y @Categoria, y devuelve el
                id en @IdArbitro OUTPUT. La categoria y los roles arbitrales se declaran al
                principio (@categoriaDemo y @rol...): si 05_Tablas_Arbitraje.sql define
                otros valores permitidos, se cambian ahi, en un solo lugar.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisEsp INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ESP');
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @PaisMex INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'MEX');
DECLARE @PaisFra INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'FRA');
DECLARE @SelArg INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-ARG');
DECLARE @SelBra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-BRA');
DECLARE @SelFra INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-FRA');
DECLARE @SelMex INT = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'SEL-MEX');
DECLARE @categoriaDemo VARCHAR(20) = 'Elite';
DECLARE @rolCentral VARCHAR(20) = 'Central', @rolAsistente1 VARCHAR(20) = 'Asistente 1',
        @rolAsistente2 VARCHAR(20) = 'Asistente 2', @rolCuarto VARCHAR(20) = 'Cuarto arbitro';
DECLARE @Arb1 INT, @Arb2 INT, @Arb3 INT, @Arb4 INT, @Arb5 INT, @Arb6 INT;
DECLARE @IdPA INT, @IdPB INT, @IdPC INT;
DECLARE @tmpElegibles TABLE (IdArbitro INT, Nombre VARCHAR(80), Apellido VARCHAR(80), IdPais INT, Categoria VARCHAR(20));

/*------------------------------------------------------------------------------
 PREPARACION: arbitros y partidos de prueba
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta de los arbitros de prueba ===';
-- Resultado esperado: se crean 6 arbitros: ARB-DES-01 y 03 de Espana, 02 y 04 de Estados Unidos, 05 de Mexico
-- y 06 de Francia.
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-DES-01', @Nombre = 'Arbitro', @Apellido = 'Espana 01',
     @FechaNacimiento = '1985-03-10', @IdPais = @PaisEsp, @Categoria = @categoriaDemo, @IdArbitro = @Arb1 OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-DES-02', @Nombre = 'Arbitro', @Apellido = 'Estados Unidos 02',
     @FechaNacimiento = '1986-07-21', @IdPais = @PaisUsa, @Categoria = @categoriaDemo, @IdArbitro = @Arb2 OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-DES-03', @Nombre = 'Arbitro', @Apellido = 'Espana 03',
     @FechaNacimiento = '1987-11-02', @IdPais = @PaisEsp, @Categoria = @categoriaDemo, @IdArbitro = @Arb3 OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-DES-04', @Nombre = 'Arbitro', @Apellido = 'Estados Unidos 04',
     @FechaNacimiento = '1988-01-15', @IdPais = @PaisUsa, @Categoria = @categoriaDemo, @IdArbitro = @Arb4 OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-DES-05', @Nombre = 'Arbitro', @Apellido = 'Mexico 05',
     @FechaNacimiento = '1984-09-30', @IdPais = @PaisMex, @Categoria = @categoriaDemo, @IdArbitro = @Arb5 OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-DES-06', @Nombre = 'Arbitro', @Apellido = 'Francia 06',
     @FechaNacimiento = '1983-05-18', @IdPais = @PaisFra, @Categoria = @categoriaDemo, @IdArbitro = @Arb6 OUTPUT;
SELECT a.IdArbitro, a.CodigoExterno, p.Nombre AS Pais, a.Categoria
FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno LIKE 'ARB-DES-%' ORDER BY a.CodigoExterno;

PRINT '=== Prueba 2: alta de los partidos de prueba ===';
-- Resultado esperado: se crean 3 partidos Programado con las dos selecciones definidas: PARTIDO-931 (cuartos,
-- Francia contra Mexico, SoFi, 22:00 UTC del 12/07), PARTIDO-932 (cuartos, Argentina contra Brasil, MetLife,
-- 23:00 UTC del 12/07, una hora despues del anterior) y PARTIDO-933 (semifinal, Argentina contra Francia, MetLife,
-- 20:00 UTC del 16/07).
EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-931', @NumeroPartido = 931, @Fase = 'Cuartos',
     @FechaHoraUtc = '2026-07-12 22:00', @CodigoExternoSede = 'SEDE-SOFI', @IdSeleccionLocal = @SelFra,
     @IdSeleccionVisitante = @SelMex, @IdPartido = @IdPA OUTPUT;
EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-932', @NumeroPartido = 932, @Fase = 'Cuartos',
     @FechaHoraUtc = '2026-07-12 23:00', @CodigoExternoSede = 'SEDE-METLIFE', @IdSeleccionLocal = @SelArg,
     @IdSeleccionVisitante = @SelBra, @IdPartido = @IdPB OUTPUT;
EXEC Torneo.usp_RegistrarPartido @CodigoExterno = 'PARTIDO-933', @NumeroPartido = 933, @Fase = 'Semifinal',
     @FechaHoraUtc = '2026-07-16 20:00', @CodigoExternoSede = 'SEDE-METLIFE', @IdSeleccionLocal = @SelArg,
     @IdSeleccionVisitante = @SelFra, @IdPartido = @IdPC OUTPUT;
SELECT p.CodigoExterno, p.Fase, sl.CodigoExterno AS Local, sv.CodigoExterno AS Visitante, p.FechaHoraUtc, p.Estado
FROM Torneo.Partido p
JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
WHERE p.IdPartido IN (@IdPA, @IdPB, @IdPC) ORDER BY p.NumeroPartido;

/*------------------------------------------------------------------------------
 ARBITROS ELEGIBLES Y DESIGNACION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 3: arbitros elegibles de Francia contra Mexico, antes de designar ===';
-- Resultado esperado: 4 arbitros de prueba: ARB-DES-01 (Espana), 02 (Estados Unidos), 03 (Espana) y 04 (Estados
-- Unidos). No aparecen ARB-DES-05 (mexicano) ni ARB-DES-06 (frances): no pueden dirigir a su propia seleccion.
DELETE FROM @tmpElegibles;
INSERT INTO @tmpElegibles EXEC Arbitraje.usp_ListarArbitrosElegibles @IdPartido = @IdPA;
SELECT a.CodigoExterno, p.Nombre AS Pais
FROM @tmpElegibles e
JOIN Arbitraje.Arbitro a ON a.IdArbitro = e.IdArbitro
JOIN Torneo.Pais p       ON p.IdPais = e.IdPais
WHERE a.CodigoExterno LIKE 'ARB-DES-%' ORDER BY a.CodigoExterno;

PRINT '=== Prueba 4: designar el cuerpo arbitral de Francia contra Mexico ===';
-- Resultado esperado: se crean 4 designaciones en PARTIDO-931: ARB-DES-01 Central, ARB-DES-02 Asistente 1,
-- ARB-DES-03 Asistente 2 y ARB-DES-04 Cuarto arbitro.
EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb1, @RolArbitral = @rolCentral;
EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb2, @RolArbitral = @rolAsistente1;
EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb3, @RolArbitral = @rolAsistente2;
EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPA, @IdArbitro = @Arb4, @RolArbitral = @rolCuarto;
SELECT d.IdDesignacion, a.CodigoExterno, d.RolArbitral
FROM Arbitraje.DesignacionArbitral d
JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdPA AND a.CodigoExterno LIKE 'ARB-DES-%' ORDER BY d.IdDesignacion;

PRINT '=== Prueba 5: arbitros elegibles de Argentina contra Brasil, una hora despues ===';
-- Resultado esperado: 2 arbitros de prueba: ARB-DES-05 (Mexico) y ARB-DES-06 (Francia). ARB-DES-01 a 04 no
-- aparecen: estan designados en PARTIDO-931, con 60 minutos de diferencia (menos que el margen de 180).
DELETE FROM @tmpElegibles;
INSERT INTO @tmpElegibles EXEC Arbitraje.usp_ListarArbitrosElegibles @IdPartido = @IdPB;
SELECT a.CodigoExterno, p.Nombre AS Pais
FROM @tmpElegibles e
JOIN Arbitraje.Arbitro a ON a.IdArbitro = e.IdArbitro
JOIN Torneo.Pais p       ON p.IdPais = e.IdPais
WHERE a.CodigoExterno LIKE 'ARB-DES-%' ORDER BY a.CodigoExterno;

PRINT '=== Prueba 6: un arbitro de otra nacionalidad dirige Argentina contra Brasil ===';
-- Resultado esperado: ARB-DES-05 (mexicano) queda designado Central en PARTIDO-932. Despues de designarlo,
-- el unico arbitro de prueba elegible para ese partido es ARB-DES-06.
EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPB, @IdArbitro = @Arb5, @RolArbitral = @rolCentral;
SELECT d.IdDesignacion, a.CodigoExterno, d.RolArbitral
FROM Arbitraje.DesignacionArbitral d
JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdPB AND a.CodigoExterno LIKE 'ARB-DES-%';
DELETE FROM @tmpElegibles;
INSERT INTO @tmpElegibles EXEC Arbitraje.usp_ListarArbitrosElegibles @IdPartido = @IdPB;
SELECT a.CodigoExterno
FROM @tmpElegibles e JOIN Arbitraje.Arbitro a ON a.IdArbitro = e.IdArbitro
WHERE a.CodigoExterno LIKE 'ARB-DES-%' ORDER BY a.CodigoExterno;

PRINT '=== Prueba 7: el mismo arbitro dirige un partido posterior ===';
-- Resultado esperado: ARB-DES-01 (que dirigio PARTIDO-931) queda designado Central en PARTIDO-933 (Argentina
-- contra Francia), 4 dias despues. Los elegibles de ese partido son ARB-DES-02, 03, 04 y 05; ARB-DES-06 no, porque
-- es frances.
EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @IdPC, @IdArbitro = @Arb1, @RolArbitral = @rolCentral;
SELECT d.IdDesignacion, a.CodigoExterno, d.RolArbitral
FROM Arbitraje.DesignacionArbitral d
JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdPC AND a.CodigoExterno LIKE 'ARB-DES-%';
DELETE FROM @tmpElegibles;
INSERT INTO @tmpElegibles EXEC Arbitraje.usp_ListarArbitrosElegibles @IdPartido = @IdPC;
SELECT a.CodigoExterno
FROM @tmpElegibles e JOIN Arbitraje.Arbitro a ON a.IdArbitro = e.IdArbitro
WHERE a.CodigoExterno LIKE 'ARB-DES-%' ORDER BY a.CodigoExterno;

PRINT '=== Prueba 8: resumen de las designaciones de prueba ===';
-- Resultado esperado: 6 designaciones: 4 en PARTIDO-931, 1 en PARTIDO-932 y 1 en PARTIDO-933.
SELECT p.CodigoExterno AS Partido, a.CodigoExterno AS Arbitro, d.RolArbitral
FROM Arbitraje.DesignacionArbitral d
JOIN Torneo.Partido p    ON p.IdPartido = d.IdPartido
JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE a.CodigoExterno LIKE 'ARB-DES-%'
ORDER BY p.NumeroPartido, d.IdDesignacion;
GO
