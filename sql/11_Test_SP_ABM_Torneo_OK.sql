/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 11_Test_SP_ABM_Torneo_OK.sql
 Objetivo     : Testing exitoso de 10_SP_ABM_Torneo.sql (relacion 1:1). Muestra
                los datos antes y despues de cada operacion.
 Requisito    : ejecutar sobre la base recien creada (scripts 01, 02 y 10), una
                sola vez. Los datos se cargan unicamente con los SP.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @IdArgentina INT, @IdUsa INT, @IdMexico INT, @IdTemporal INT;
DECLARE @IdSedeMetLife INT, @IdSedeAzteca INT, @IdSedeTemporal INT;
DECLARE @IdPartido1 INT, @IdPartido2 INT;

/*------------------------------------------------------------------------------
 PAIS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta de paises ===';
-- Resultado esperado: se insertan 3 paises (Argentina, Estados Unidos y Mexico) con
-- IdPais autogenerado, codigo ISO en mayusculas y el PIB de Argentina informado.
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'arg', @Nombre = 'Argentina', @Confederacion = 'CONMEBOL',
     @HusoHorario = 'Argentina Standard Time', @PibPerCapitaUsd = 13650.50, @AnioPib = 2023, @IdPais = @IdArgentina OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'USA', @Nombre = 'Estados Unidos', @Confederacion = 'CONCACAF',
     @HusoHorario = 'Eastern Standard Time', @IdPais = @IdUsa OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'MEX', @Nombre = 'Mexico', @Confederacion = 'CONCACAF',
     @HusoHorario = 'Central Standard Time (Mexico)', @IdPais = @IdMexico OUTPUT;
SELECT IdPais, CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib FROM Torneo.Pais ORDER BY IdPais;

PRINT '=== Prueba 2: modificacion de un pais ===';
-- Resultado esperado: el PIB de Argentina pasa a 14000.00 (anio 2024). Los demas datos no cambian.
EXEC Torneo.usp_Pais_Modificacion @IdPais = @IdArgentina, @CodigoIso3 = 'ARG', @Nombre = 'Argentina',
     @Confederacion = 'CONMEBOL', @HusoHorario = 'Argentina Standard Time', @PibPerCapitaUsd = 14000.00, @AnioPib = 2024;
SELECT IdPais, CodigoIso3, Nombre, PibPerCapitaUsd, AnioPib FROM Torneo.Pais WHERE IdPais = @IdArgentina;

PRINT '=== Prueba 3: baja de un pais sin datos asociados ===';
-- Resultado esperado: se crea un pais temporal (Chile) y se elimina; la cantidad de paises vuelve a 3.
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'CHL', @Nombre = 'Chile', @Confederacion = 'CONMEBOL',
     @HusoHorario = 'Pacific SA Standard Time', @IdPais = @IdTemporal OUTPUT;
SELECT COUNT(*) AS PaisesConChile FROM Torneo.Pais;
EXEC Torneo.usp_Pais_Baja @IdPais = @IdTemporal;
SELECT COUNT(*) AS PaisesSinChile FROM Torneo.Pais;

/*------------------------------------------------------------------------------
 SEDE
------------------------------------------------------------------------------*/
PRINT '=== Prueba 4: alta de sedes ===';
-- Resultado esperado: se insertan 2 sedes con husos horarios distintos (Eastern y Central Mexico).
EXEC Torneo.usp_Sede_Alta @CodigoExterno = 'SEDE-METLIFE', @NombreEstadio = 'Estadio MetLife', @Ciudad = 'East Rutherford',
     @IdPais = @IdUsa, @HusoHorario = 'Eastern Standard Time', @Capacidad = 82500, @IdSede = @IdSedeMetLife OUTPUT;
EXEC Torneo.usp_Sede_Alta @CodigoExterno = 'SEDE-AZTECA', @NombreEstadio = 'Estadio Azteca', @Ciudad = 'Ciudad de Mexico',
     @IdPais = @IdMexico, @HusoHorario = 'Central Standard Time (Mexico)', @Capacidad = 83000, @IdSede = @IdSedeAzteca OUTPUT;
SELECT IdSede, CodigoExterno, NombreEstadio, Ciudad, IdPais, HusoHorario, Capacidad FROM Torneo.Sede ORDER BY IdSede;

PRINT '=== Prueba 5: modificacion de una sede ===';
-- Resultado esperado: la capacidad del Estadio Azteca pasa de 83000 a 87523.
EXEC Torneo.usp_Sede_Modificacion @IdSede = @IdSedeAzteca, @CodigoExterno = 'SEDE-AZTECA', @NombreEstadio = 'Estadio Azteca',
     @Ciudad = 'Ciudad de Mexico', @IdPais = @IdMexico, @HusoHorario = 'Central Standard Time (Mexico)', @Capacidad = 87523;
SELECT IdSede, NombreEstadio, Capacidad FROM Torneo.Sede WHERE IdSede = @IdSedeAzteca;

PRINT '=== Prueba 6: baja de una sede sin partidos ===';
-- Resultado esperado: se crea una sede temporal y se elimina; la cantidad de sedes vuelve a 2.
EXEC Torneo.usp_Sede_Alta @CodigoExterno = 'SEDE-TEMP', @NombreEstadio = 'Estadio Temporal', @Ciudad = 'Rosario',
     @IdPais = @IdArgentina, @HusoHorario = 'Argentina Standard Time', @Capacidad = 40000, @IdSede = @IdSedeTemporal OUTPUT;
SELECT COUNT(*) AS SedesConTemporal FROM Torneo.Sede;
EXEC Torneo.usp_Sede_Baja @IdSede = @IdSedeTemporal;
SELECT COUNT(*) AS SedesSinTemporal FROM Torneo.Sede;

/*------------------------------------------------------------------------------
 PARTIDO
 Se usan partidos de Octavos con las selecciones sin definir (el cruce todavia no
 se conoce). Los partidos con selecciones se prueban en 21_Test_SP_ABM_Seleccion_OK.sql.
------------------------------------------------------------------------------*/
PRINT '=== Prueba 7: alta de partidos ===';
-- Resultado esperado: se insertan 2 partidos 'Programado' en el Estadio MetLife, sin goles.
-- El primero es a las 20:00 UTC: la hora local calculada es 16:00 (Eastern, horario de verano).
-- El segundo, 4 horas despues (240 minutos, mas que el margen de 180), es a las 20:00 locales.
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'PARTIDO-001', @NumeroPartido = 1, @Fase = 'Octavos', @IdSede = @IdSedeMetLife,
     @FechaHoraUtc = '2026-07-04 20:00', @IdPartido = @IdPartido1 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'PARTIDO-002', @NumeroPartido = 2, @Fase = 'Octavos', @IdSede = @IdSedeMetLife,
     @FechaHoraUtc = '2026-07-05 00:00', @IdPartido = @IdPartido2 OUTPUT;
SELECT IdPartido, CodigoExterno, NumeroPartido, Fase, IdSede, FechaHoraUtc, FechaHoraLocal, Estado, GolesLocal, GolesVisitante
FROM Torneo.Partido ORDER BY IdPartido;

PRINT '=== Prueba 8: modificacion de un partido ===';
-- Resultado esperado: el partido 1 pasa a la sede Azteca a las 22:00 UTC; la hora local se recalcula
-- con el huso de Mexico (16:00, sin horario de verano) y se carga el esquema tactico local.
EXEC Torneo.usp_Partido_Modificacion @IdPartido = @IdPartido1, @CodigoExterno = 'PARTIDO-001', @NumeroPartido = 1,
     @Fase = 'Octavos', @IdSede = @IdSedeAzteca, @FechaHoraUtc = '2026-07-04 22:00', @EsquemaTacticoLocal = '4-3-3';
SELECT IdPartido, IdSede, FechaHoraUtc, FechaHoraLocal, EsquemaTacticoLocal FROM Torneo.Partido WHERE IdPartido = @IdPartido1;

PRINT '=== Prueba 9: baja de un partido programado ===';
-- Resultado esperado: se elimina el partido 2; queda solo el partido 1.
SELECT COUNT(*) AS PartidosAntes FROM Torneo.Partido;
EXEC Torneo.usp_Partido_Baja @IdPartido = @IdPartido2;
SELECT COUNT(*) AS PartidosDespues FROM Torneo.Partido;
GO
