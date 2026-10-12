/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-12
 Script       : 99_Datos_Aceptacion.sql
 Objetivo     : Juego de datos de aceptacion (seccion IV de la consigna). Carga,
                unicamente con los SP de las tablas y de la logica de negocio, un
                torneo completo de 16 selecciones y 32 partidos jugados:
                  - 8 sedes en 4 husos horarios distintos.
                  - 16 selecciones en 4 grupos, cada una con 23 convocados.
                  - 24 partidos de fase de grupos y 8 de eliminacion directa
                    (cuartos, semifinales, tercer puesto y final), con formacion
                    titular y banco de cada seleccion, cambios, goles, tarjetas,
                    definicion por penales y resultado final.
                  - 16 arbitros; cada partido con principal, dos asistentes, cuarto
                    arbitro y VAR.
                  - 8 anunciantes con campanias, piezas, paises de interes y tarifas;
                    las 4 piezas de cada partido se asignan con la logica de negocio
                    y se registran como exhibidas.
                Casos obligatorios que deja armados:
                  - Expulsion por doble amonestacion: Japon en su primer partido
                    (AC-P01) y roja directa de Marruecos en AC-P02.
                  - Jugadores suspendidos que quedan afuera de la formacion del
                    partido siguiente: Alemania (acumulacion de amarillas, AC-P17),
                    Japon y Marruecos (rojas). Antes de armar cada formacion se
                    intenta registrar al suspendido y se muestra el rechazo.
                  - Cambios por lesion en los primeros 20 minutos: Corea del Sur en
                    AC-P03 y Panama en AC-P10.
                  - Partido en prime time en mas de cuatro mercados: AC-P03 (23:00
                    UTC); se muestran las candidatas y las 4 elegidas.
                  - Designacion arbitral descartada por conflicto de nacionalidad:
                    el arbitro aleman AC-ARB-16 en el primer partido de Alemania.
                  - Baja de ultimo momento con reemplazo: Ghana (AC-GHA-21 por AC-GHA-24).
                La importacion con errores parciales corresponde a la Entrega 6.
 Requisito    : ejecutar despues de todos los scripts anteriores (01 a 98), una sola
                vez. Los datos usan codigos propios (AC-), asi que conviven con los
                que dejan los tests; los paises que ya existen se reutilizan. Para
                volver a ejecutarlo hay que recrear la base desde el 01.
 Supuestos    : los PIB per capita de los paises son valores aproximados de ejemplo,
                no oficiales. Los anunciantes no guardan su pais en el modelo: los
                mercados de cada campania son los paises de interes de sus piezas.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM Torneo.Partido WHERE CodigoExterno = 'AC-P01')
    THROW 50001, 'Los datos de aceptacion ya fueron cargados. Recree la base desde 01_Base_Esquemas.sql para volver a cargarlos. ', 1;

DECLARE @i INT, @j INT, @n INT;

/*------------------------------------------------------------------------------
 1. PAISES (los que ya existen se reutilizan)
------------------------------------------------------------------------------*/
PRINT '=== Paises ===';
DECLARE @Paises TABLE (Orden INT IDENTITY(1,1), Iso VARCHAR(3), Nombre VARCHAR(80), Confederacion VARCHAR(10),
                       Huso VARCHAR(60), Pib DECIMAL(18, 2));
INSERT INTO @Paises (Iso, Nombre, Confederacion, Huso, Pib) VALUES
    ('ARG', 'Argentina',      'CONMEBOL', 'Argentina Standard Time',          13650),
    ('BRA', 'Brasil',         'CONMEBOL', 'E. South America Standard Time',   10412),
    ('URY', 'Uruguay',        'CONMEBOL', 'Montevideo Standard Time',         22000),
    ('PRY', 'Paraguay',       'CONMEBOL', 'Paraguay Standard Time',            6300),
    ('COL', 'Colombia',       'CONMEBOL', 'SA Pacific Standard Time',          6900),
    ('ECU', 'Ecuador',        'CONMEBOL', 'SA Pacific Standard Time',          6400),
    ('USA', 'Estados Unidos', 'CONCACAF', 'Eastern Standard Time',            82769),
    ('MEX', 'Mexico',         'CONCACAF', 'Central Standard Time (Mexico)',   13800),
    ('CAN', 'Canada',         'CONCACAF', 'Eastern Standard Time',            53372),
    ('PAN', 'Panama',         'CONCACAF', 'SA Pacific Standard Time',         18900),
    ('DEU', 'Alemania',       'UEFA',     'W. Europe Standard Time',          52745),
    ('BEL', 'Belgica',        'UEFA',     'Romance Standard Time',            55500),
    ('HRV', 'Croacia',        'UEFA',     'Central European Standard Time',   22000),
    ('CHE', 'Suiza',          'UEFA',     'W. Europe Standard Time',          99994),
    ('AUT', 'Austria',        'UEFA',     'W. Europe Standard Time',          56500),
    ('NOR', 'Noruega',        'UEFA',     'W. Europe Standard Time',          87925),
    ('FRA', 'Francia',        'UEFA',     'Romance Standard Time',            44400),
    ('ESP', 'Espana',         'UEFA',     'Romance Standard Time',            32000),
    ('ITA', 'Italia',         'UEFA',     'W. Europe Standard Time',          38000),
    ('POR', 'Portugal',       'UEFA',     'GMT Standard Time',                28000),
    ('NED', 'Paises Bajos',   'UEFA',     'W. Europe Standard Time',          64000),
    ('GBR', 'Reino Unido',    'UEFA',     'GMT Standard Time',                48866),
    ('DNK', 'Dinamarca',      'UEFA',     'Romance Standard Time',            67220),
    ('TUR', 'Turquia',        'UEFA',     'Turkey Standard Time',             13110),
    ('JPN', 'Japon',          'AFC',      'Tokyo Standard Time',              33834),
    ('KOR', 'Corea del Sur',  'AFC',      'Korea Standard Time',              33121),
    ('AUS', 'Australia',      'AFC',      'AUS Eastern Standard Time',        64711),
    ('MAR', 'Marruecos',      'CAF',      'Morocco Standard Time',             3900),
    ('SEN', 'Senegal',        'CAF',      'Greenwich Standard Time',           1700),
    ('EGY', 'Egipto',         'CAF',      'Egypt Standard Time',               3500),
    ('GHA', 'Ghana',          'CAF',      'Greenwich Standard Time',           2400);

DECLARE @iso VARCHAR(3), @nombre VARCHAR(80), @conf VARCHAR(10), @huso VARCHAR(60), @pib DECIMAL(18, 2), @idPais INT;
SET @i = 1;
SELECT @n = MAX(Orden) FROM @Paises;
WHILE @i <= @n
BEGIN
    SELECT @iso = Iso, @nombre = Nombre, @conf = Confederacion, @huso = Huso, @pib = Pib FROM @Paises WHERE Orden = @i;
    IF NOT EXISTS (SELECT 1 FROM Torneo.Pais WHERE CodigoIso3 = @iso)
        EXEC Torneo.usp_Pais_Alta @CodigoIso3 = @iso, @Nombre = @nombre, @Confederacion = @conf, @HusoHorario = @huso,
             @PibPerCapitaUsd = @pib, @AnioPib = 2023, @IdPais = @idPais OUTPUT;
    SET @i += 1;
END;

/*------------------------------------------------------------------------------
 2. SEDES (8 sedes, husos: Mexico, Central, Eastern y Pacific)
------------------------------------------------------------------------------*/
PRINT '=== Sedes ===';
DECLARE @PaisMex INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'MEX');
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @PaisCan INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'CAN');
DECLARE @IdSede INT;

EXEC Torneo.usp_Sede_Alta 'AC-SEDE-01', 'Estadio Banorte',    'Ciudad de Mexico', @PaisMex, 'Central Standard Time (Mexico)', 83000, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-02', 'AT&T Stadium',       'Dallas',           @PaisUsa, 'Central Standard Time',          80000, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-03', 'Hard Rock Stadium',  'Miami',            @PaisUsa, 'Eastern Standard Time',          65000, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-04', 'Lumen Field',        'Seattle',          @PaisUsa, 'Pacific Standard Time',          69000, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-05', 'BC Place',           'Vancouver',        @PaisCan, 'Pacific Standard Time',          54000, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-06', 'BMO Field',          'Toronto',          @PaisCan, 'Eastern Standard Time',          45000, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-07', 'Estadio BBVA',       'Monterrey',        @PaisMex, 'Central Standard Time (Mexico)', 53500, @IdSede OUTPUT;
EXEC Torneo.usp_Sede_Alta 'AC-SEDE-08', 'Levis Stadium',      'Santa Clara',      @PaisUsa, 'Pacific Standard Time',          71000, @IdSede OUTPUT;

/*------------------------------------------------------------------------------
 3. SELECCIONES Y CONVOCATORIA (16 selecciones x 23 convocados)
 Dorsales: 1, 12 y 23 arqueros; 2-5, 13, 14, 19 y 22 defensores; 6, 8, 10, 15, 16
 y 20 mediocampistas; 7, 9, 11, 17, 18 y 21 delanteros.
------------------------------------------------------------------------------*/
PRINT '=== Selecciones y convocatoria ===';
CREATE TABLE #Equipos (Orden INT IDENTITY(1,1), Iso VARCHAR(3), Grupo CHAR(1), Pos TINYINT);
INSERT INTO #Equipos (Iso, Grupo, Pos) VALUES
    ('DEU', 'I', 1), ('JPN', 'I', 2), ('MAR', 'I', 3), ('PAN', 'I', 4),
    ('BEL', 'J', 1), ('KOR', 'J', 2), ('SEN', 'J', 3), ('CAN', 'J', 4),
    ('HRV', 'K', 1), ('AUS', 'K', 2), ('EGY', 'K', 3), ('PRY', 'K', 4),
    ('CHE', 'L', 1), ('AUT', 'L', 2), ('NOR', 'L', 3), ('GHA', 'L', 4);

DECLARE @grupo CHAR(1), @codSel VARCHAR(30), @idSel INT, @idDt INT, @dorsal INT, @pos VARCHAR(5), @codJug VARCHAR(30),
        @apellido VARCHAR(80), @nacimiento DATE;
SET @i = 1;
WHILE @i <= 16
BEGIN
    SELECT @iso = e.Iso, @grupo = e.Grupo, @idPais = p.IdPais, @nombre = p.Nombre
    FROM #Equipos e JOIN Torneo.Pais p ON p.CodigoIso3 = e.Iso
    WHERE e.Orden = @i;

    SET @codSel = 'AC-SEL-' + @iso;
    EXEC Torneo.usp_RegistrarSeleccion @CodigoExterno = @codSel, @IdPais = @idPais, @Grupo = @grupo,
         @NombreDirector = 'Director', @ApellidoDirector = @nombre, @IdSeleccion = @idSel OUTPUT, @IdDirector = @idDt OUTPUT;

    SET @dorsal = 1;
    WHILE @dorsal <= 23
    BEGIN
        SET @pos = CASE WHEN @dorsal IN (1, 12, 23)                  THEN 'POR'
                        WHEN @dorsal IN (2, 3, 4, 5, 13, 14, 19, 22) THEN 'DEF'
                        WHEN @dorsal IN (6, 8, 10, 15, 16, 20)       THEN 'MED'
                        ELSE 'DEL' END;
        SET @codJug = 'AC-' + @iso + '-' + RIGHT('0' + CAST(@dorsal AS VARCHAR(2)), 2);
        SET @apellido = @nombre + ' ' + RIGHT('0' + CAST(@dorsal AS VARCHAR(2)), 2);
        SET @nacimiento = DATEFROMPARTS(1989 + ((@dorsal + @i) % 11), 1 + ((@dorsal * 3 + @i) % 12), 1 + ((@dorsal * 7 + @i) % 27));
        EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @codJug, @Nombre = 'Jugador', @Apellido = @apellido,
             @IdPais = @idPais, @IdSeleccion = @idSel, @Dorsal = @dorsal, @PosicionHabitual = @pos,
             @ClubOrigen = 'Club de Prueba', @FechaAlta = '2026-05-25', @FechaNacimiento = @nacimiento;
        SET @dorsal += 1;
    END;
    SET @i += 1;
END;

-- Baja de ultimo momento con reemplazo: Ghana pierde al delantero 21 por lesion y suma al 24
DECLARE @idBaja INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'AC-GHA-21');
DECLARE @idPaisGha INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'GHA');
DECLARE @idReemplazo INT;
EXEC Torneo.usp_RegistrarBajaYReemplazo @IdJugadorBaja = @idBaja, @MotivoBaja = 'Lesion', @FechaBaja = '2026-06-05',
     @CodigoExternoReemplazo = 'AC-GHA-24', @NombreReemplazo = 'Jugador', @ApellidoReemplazo = 'Ghana 24',
     @IdPaisReemplazo = @idPaisGha, @DorsalReemplazo = 24, @PosicionReemplazo = 'DEL', @ClubReemplazo = 'Club de Prueba',
     @FechaNacimientoReemplazo = '1998-03-14', @IdJugadorReemplazo = @idReemplazo OUTPUT;

/*------------------------------------------------------------------------------
 4. ARBITROS (15 neutrales + 1 aleman para el caso de conflicto de nacionalidad)
------------------------------------------------------------------------------*/
PRINT '=== Arbitros ===';
CREATE TABLE #Arbitros (Orden INT IDENTITY(1,1), Iso VARCHAR(3), Idioma1 VARCHAR(10), Idioma2 VARCHAR(10));
INSERT INTO #Arbitros (Iso, Idioma1, Idioma2) VALUES
    ('ARG', 'es', 'en'), ('BRA', 'pt', 'es'), ('URY', 'es', 'pt'), ('COL', 'es', 'en'), ('ECU', 'es', 'en'),
    ('MEX', 'es', 'en'), ('USA', 'en', 'es'), ('FRA', 'fr', 'en'), ('ESP', 'es', 'en'), ('ITA', 'it', 'en'),
    ('POR', 'pt', 'en'), ('NED', 'nl', 'en'), ('GBR', 'en', 'fr'), ('DNK', 'da', 'en'), ('TUR', 'tr', 'en'),
    ('DEU', 'de', 'en');

DECLARE @codArb VARCHAR(30), @idArb INT, @idioma1 VARCHAR(10), @idioma2 VARCHAR(10);
SET @i = 1;
WHILE @i <= 16
BEGIN
    SELECT @iso = a.Iso, @idPais = p.IdPais, @nombre = p.Nombre, @idioma1 = a.Idioma1, @idioma2 = a.Idioma2
    FROM #Arbitros a JOIN Torneo.Pais p ON p.CodigoIso3 = a.Iso
    WHERE a.Orden = @i;

    SET @codArb = 'AC-ARB-' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    SET @apellido = @nombre + ' ' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    SET @nacimiento = DATEFROMPARTS(1978 + (@i % 8), 1 + ((@i * 5) % 12), 1 + ((@i * 11) % 27));
    EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = @codArb, @Nombre = 'Arbitro', @Apellido = @apellido, @IdPais = @idPais,
         @Categoria = 'FIFA', @FechaNacimiento = @nacimiento, @IdArbitro = @idArb OUTPUT;
    EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @idArb, @Idioma = @idioma1;
    EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @idArb, @Idioma = @idioma2;
    SET @i += 1;
END;

/*------------------------------------------------------------------------------
 5. PUBLICIDAD: anunciantes, campanias, piezas, mercados y tarifas
------------------------------------------------------------------------------*/
PRINT '=== Publicidad ===';
CREATE TABLE #Anunciantes (Orden INT IDENTITY(1,1), Anunciante VARCHAR(120), Campania VARCHAR(120), Pieza VARCHAR(120),
                           Idioma VARCHAR(10), Segundos INT, Mercados VARCHAR(100));
INSERT INTO #Anunciantes (Anunciante, Campania, Pieza, Idioma, Segundos, Mercados) VALUES
    ('Aurora Bebidas (Argentina)',          'Copa Aurora',      'Spot Aurora',  'es', 30, 'ARG'),
    ('Banco Verde (Brasil)',                'Verde Mundial',    'Spot Verde',   'pt', 20, 'BRA'),
    ('Rhein Motors (Alemania)',             'Rhein 2026',       'Spot Rhein',   'de', 30, 'DEU,CHE,AUT,USA'),
    ('Sakura Electronics (Japon)',          'Sakura Cup',       'Spot Sakura',  'ja', 15, 'JPN,KOR,AUS'),
    ('Maple Telecom (Canada)',              'Maple Fan Zone',   'Spot Maple',   'en', 30, 'CAN'),
    ('Atlas Travel (Marruecos)',            'Atlas Africa',     'Spot Atlas',   'fr', 20, 'MAR,SEN,EGY,GHA'),
    ('Rio de la Plata Seguros (Uruguay)',   'Plata 2026',       'Spot Plata',   'es', 30, 'URY,PRY'),
    ('Nordic Insurance (Noruega)',          'Nordic Goal',      'Spot Nordic',  'en', 20, 'NOR,BEL,HRV');

DECLARE @anunciante VARCHAR(120), @campania VARCHAR(120), @pieza VARCHAR(120), @idiomaPz VARCHAR(10), @seg INT, @mercados VARCHAR(100);
DECLARE @idAnunciante INT, @idCampania INT, @idPieza INT;
SET @i = 1;
WHILE @i <= 8
BEGIN
    SELECT @anunciante = Anunciante, @campania = Campania, @pieza = Pieza, @idiomaPz = Idioma, @seg = Segundos, @mercados = Mercados
    FROM #Anunciantes WHERE Orden = @i;

    EXEC Publicidad.usp_Anunciante_Alta @Nombre = @anunciante, @IdAnunciante = @idAnunciante OUTPUT;
    EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @idAnunciante, @Nombre = @campania,
         @FechaInicio = '2026-06-01', @FechaFin = '2026-07-31', @IdCampania = @idCampania OUTPUT;
    EXEC Publicidad.usp_Pieza_Alta @IdCampania = @idCampania, @Nombre = @pieza, @Idioma = @idiomaPz,
         @DuracionSegundos = @seg, @IdPieza = @idPieza OUTPUT;

    -- Paises de interes de la pieza: un renglon por cada codigo ISO de la lista
    SET @j = 1;
    SELECT @n = COUNT(*) FROM STRING_SPLIT(@mercados, ',');
    WHILE @j <= @n
    BEGIN
        SELECT @idPais = p.IdPais
        FROM (SELECT value AS Iso, ROW_NUMBER() OVER (ORDER BY value) AS Rn FROM STRING_SPLIT(@mercados, ',')) m
        JOIN Torneo.Pais p ON p.CodigoIso3 = m.Iso
        WHERE m.Rn = @j;
        EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @idPieza, @IdPais = @idPais;
        SET @j += 1;
    END;
    SET @i += 1;
END;

-- Tarifas por fase: solo se cargan las que todavia no tienen una vigente ese dia
CREATE TABLE #Tarifas (Orden INT IDENTITY(1,1), Fase VARCHAR(20), Desde DATE, Hasta DATE, Monto DECIMAL(18, 2));
INSERT INTO #Tarifas (Fase, Desde, Hasta, Monto) VALUES
    ('Grupos',        '2026-06-01', '2026-06-30',  50000),
    ('Dieciseisavos', '2026-06-28', '2026-07-02',  60000),
    ('Cuartos',       '2026-07-01', '2026-07-08',  80000),
    ('Semifinal',     '2026-07-09', '2026-07-14', 120000),
    ('Tercer puesto', '2026-07-01', '2026-07-31',  70000),
    ('Final',         '2026-07-15', '2026-07-31', 200000);
DECLARE @fase VARCHAR(20), @desde DATE, @hasta DATE, @monto DECIMAL(18, 2), @idTarifa INT;
SET @i = 1;
WHILE @i <= 6
BEGIN
    SELECT @fase = Fase, @desde = Desde, @hasta = Hasta, @monto = Monto FROM #Tarifas WHERE Orden = @i;
    IF Publicidad.fn_TarifaVigente(@fase, @desde) IS NULL
        EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = @fase, @Moneda = 'USD', @Monto = @monto,
             @VigenteDesde = @desde, @VigenteHasta = @hasta, @IdTarifa = @idTarifa OUTPUT;
    SET @i += 1;
END;

/*------------------------------------------------------------------------------
 6. CALENDARIO: 24 partidos de grupos y 8 de eliminacion directa
 Cada grupo juega en tres fechas (1-2 y 3-4, 3-1 y 2-4, 4-1 y 2-3, con las
 posiciones del grupo); las fechas son el 11, 17 y 23 de junio. Hay tres
 horarios por dia (17:00, 20:00 y 23:00 UTC). Los resultados dejan a las
 selecciones 1 y 2 de cada grupo clasificadas a cuartos.
------------------------------------------------------------------------------*/
PRINT '=== Calendario ===';
CREATE TABLE #Grupos (Grupo CHAR(1), T1 VARCHAR(3), T2 VARCHAR(3), T3 VARCHAR(3), T4 VARCHAR(3));
INSERT INTO #Grupos VALUES ('I', 'DEU', 'JPN', 'MAR', 'PAN'), ('J', 'BEL', 'KOR', 'SEN', 'CAN'),
                           ('K', 'HRV', 'AUS', 'EGY', 'PRY'), ('L', 'CHE', 'AUT', 'NOR', 'GHA');
CREATE TABLE #Plantilla (Fecha TINYINT, Orden TINYINT, PosL TINYINT, PosV TINYINT, GolesL TINYINT, GolesV TINYINT);
INSERT INTO #Plantilla VALUES (1, 1, 1, 2, 2, 1), (1, 2, 3, 4, 0, 0),
                              (2, 1, 3, 1, 0, 1), (2, 2, 2, 4, 2, 1),
                              (3, 1, 4, 1, 0, 3), (3, 2, 2, 3, 1, 0);

CREATE TABLE #Cal (K INT, Codigo VARCHAR(30), Numero INT, Fase VARCHAR(20), FechaHoraUtc DATETIME2, SedeCod VARCHAR(30),
                   LocalIso VARCHAR(3), VisitIso VARCHAR(3), GolesL INT, GolesV INT, PenL INT, PenV INT);

WITH Grupos AS (
    SELECT p.Fecha, g.Grupo, p.Orden,
           CHOOSE(p.PosL, g.T1, g.T2, g.T3, g.T4) AS LocalIso,
           CHOOSE(p.PosV, g.T1, g.T2, g.T3, g.T4) AS VisitIso,
           p.GolesL, p.GolesV,
           ROW_NUMBER() OVER (PARTITION BY p.Fecha ORDER BY g.Grupo, p.Orden) AS J
    FROM #Plantilla p CROSS JOIN #Grupos g
)
INSERT INTO #Cal (K, Codigo, Numero, Fase, FechaHoraUtc, SedeCod, LocalIso, VisitIso, GolesL, GolesV, PenL, PenV)
SELECT ROW_NUMBER() OVER (ORDER BY f.FechaHoraUtc, f.Grupo, f.Orden), NULL, NULL, 'Grupos', f.FechaHoraUtc, NULL,
       f.LocalIso, f.VisitIso, f.GolesL, f.GolesV, NULL, NULL
FROM (SELECT gr.*,
             DATEADD(HOUR, 17 + 3 * ((gr.J - 1) % 3),
                     CAST(DATEADD(DAY, (gr.J - 1) / 3,
                                  CAST(CASE gr.Fecha WHEN 1 THEN '2026-06-11' WHEN 2 THEN '2026-06-17' ELSE '2026-06-23' END AS DATE))
                          AS DATETIME2)) AS FechaHoraUtc
      FROM Grupos gr) f;

INSERT INTO #Cal (K, Fase, FechaHoraUtc, LocalIso, VisitIso, GolesL, GolesV, PenL, PenV) VALUES
    (25, 'Cuartos',       '2026-07-03 17:00', 'DEU', 'KOR', 2, 0, NULL, NULL),
    (26, 'Cuartos',       '2026-07-03 20:00', 'BEL', 'JPN', 1, 1, 4,    3),
    (27, 'Cuartos',       '2026-07-04 17:00', 'HRV', 'AUT', 0, 1, NULL, NULL),
    (28, 'Cuartos',       '2026-07-04 20:00', 'CHE', 'AUS', 3, 1, NULL, NULL),
    (29, 'Semifinal',     '2026-07-09 20:00', 'DEU', 'BEL', 1, 0, NULL, NULL),
    (30, 'Semifinal',     '2026-07-10 20:00', 'AUT', 'CHE', 2, 2, 5,    4),
    (31, 'Tercer puesto', '2026-07-18 17:00', 'BEL', 'CHE', 2, 1, NULL, NULL),
    (32, 'Final',         '2026-07-19 20:00', 'DEU', 'AUT', 2, 1, NULL, NULL);

UPDATE #Cal
SET Codigo  = 'AC-P' + RIGHT('0' + CAST(K AS VARCHAR(2)), 2),
    Numero  = 200 + K,
    SedeCod = 'AC-SEDE-' + RIGHT('0' + CAST(((K - 1) % 8) + 1 AS VARCHAR(2)), 2);

-- Tarjetas puntuales: (local, visitante, equipo, dorsal, tipo, periodo, minuto, motivo)
CREATE TABLE #Tarjetas (Id INT IDENTITY(1,1), LocalIso VARCHAR(3), VisitIso VARCHAR(3), EquipoIso VARCHAR(3), Dorsal INT,
                        Tipo VARCHAR(30), Periodo VARCHAR(30), Minuto INT, Motivo VARCHAR(100), Hecha BIT DEFAULT 0);
INSERT INTO #Tarjetas (LocalIso, VisitIso, EquipoIso, Dorsal, Tipo, Periodo, Minuto, Motivo) VALUES
    ('DEU', 'JPN', 'DEU', 5, 'Amarilla',     'Segundo tiempo', 55, 'Falta tactica'),
    ('DEU', 'JPN', 'JPN', 4, 'Amarilla',     'Primer tiempo',  30, 'Falta'),
    ('DEU', 'JPN', 'JPN', 4, 'Amarilla',     'Segundo tiempo', 70, 'Protesta'),
    ('MAR', 'PAN', 'MAR', 3, 'Roja directa', 'Segundo tiempo', 80, 'Juego brusco grave'),
    ('MAR', 'DEU', 'DEU', 5, 'Amarilla',     'Segundo tiempo', 60, 'Falta tactica');

-- Cambios por lesion en el primer tiempo: (local, visitante, equipo)
CREATE TABLE #Lesiones (LocalIso VARCHAR(3), VisitIso VARCHAR(3), EquipoIso VARCHAR(3));
INSERT INTO #Lesiones VALUES ('JPN', 'PAN', 'PAN'), ('BEL', 'KOR', 'KOR');

/*------------------------------------------------------------------------------
 7. JUEGO DE LOS 32 PARTIDOS, EN ORDEN CRONOLOGICO
 Para cada partido: designacion arbitral, formaciones, piezas publicitarias,
 inicio, cambios, goles, tarjetas, penales, fin y exhibicion de la publicidad.
 La formacion de cada seleccion toma por posicion a los jugadores de menor
 dorsal que no estan suspendidos: 1 arquero, 4 defensores, 3 mediocampistas y
 3 delanteros de titulares, y los 7 siguientes en el banco.
------------------------------------------------------------------------------*/
PRINT '=== Partidos ===';
DECLARE @k INT = 1, @nPartidos INT = (SELECT COUNT(*) FROM #Cal);
DECLARE @cod VARCHAR(30), @num INT, @fh DATETIME2, @sedeCod VARCHAR(30), @lIso VARCHAR(3), @vIso VARCHAR(3);
DECLARE @gl INT, @gv INT, @pl INT, @pv INT, @selL INT, @selV INT, @idP INT, @idSedeP INT;
DECLARE @lado INT, @isoEq VARCHAR(3), @selEq INT, @goles INT, @pen INT, @intento INT, @json VARCHAR(MAX), @hayLesion BIT;
DECLARE @r INT, @idRol VARCHAR(20), @idDes INT, @adv VARCHAR(300), @idJug INT, @idJugEntra INT, @alAutor INT, @alAsiste INT;
DECLARE @minuto INT, @periodo VARCHAR(30), @tipoGol VARCHAR(20), @idGol INT, @idTarjeta INT, @genero BIT, @idCambio INT;
DECLARE @ventana INT, @ventanaCambio INT, @esp INT, @idPub INT, @asis INT, @cap INT, @exh INT, @desc INT, @tId INT, @tDorsal INT;
DECLARE @tTipo VARCHAR(30), @tPer VARCHAR(30), @tMin INT, @tMot VARCHAR(100), @tIso VARCHAR(3), @alT INT;
DECLARE @desPrincipal INT, @arbPrincipal INT, @informe VARCHAR(500), @sancion VARCHAR(200), @msg VARCHAR(2000);

WHILE @k <= @nPartidos
BEGIN
    SELECT @cod = Codigo, @num = Numero, @fase = Fase, @fh = FechaHoraUtc, @sedeCod = SedeCod, @lIso = LocalIso,
           @vIso = VisitIso, @gl = GolesL, @gv = GolesV, @pl = PenL, @pv = PenV
    FROM #Cal WHERE K = @k;
    SET @selL = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'AC-SEL-' + @lIso);
    SET @selV = (SELECT IdSeleccion FROM Torneo.Seleccion WHERE CodigoExterno = 'AC-SEL-' + @vIso);

    EXEC Torneo.usp_RegistrarPartido @CodigoExterno = @cod, @NumeroPartido = @num, @Fase = @fase, @FechaHoraUtc = @fh,
         @CodigoExternoSede = @sedeCod, @IdSeleccionLocal = @selL, @IdSeleccionVisitante = @selV, @IdPartido = @idP OUTPUT;
    PRINT CONCAT('--- ', @cod, ' (', @fase, ') ', @lIso, ' - ', @vIso, ' ', CONVERT(VARCHAR(16), @fh, 120), ' UTC');

    -- Designacion arbitral completa: 5 arbitros consecutivos de los 15 neutrales
    IF @k = 1
    BEGIN
        BEGIN TRY
            SET @idArb = (SELECT IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = 'AC-ARB-16');
            EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @idP, @IdArbitro = @idArb, @RolArbitral = 'Principal';
        END TRY
        BEGIN CATCH
            PRINT CONCAT('    Designacion descartada (arbitro AC-ARB-16, aleman): ', ERROR_MESSAGE());
        END CATCH
    END;
    SET @r = 1;
    WHILE @r <= 5
    BEGIN
        SET @codArb = 'AC-ARB-' + RIGHT('0' + CAST((((@k - 1) * 5 + (@r - 1)) % 15) + 1 AS VARCHAR(2)), 2);
        SET @idArb = (SELECT IdArbitro FROM Arbitraje.Arbitro WHERE CodigoExterno = @codArb);
        SET @idRol = CHOOSE(@r, 'Principal', 'Asistente 1', 'Asistente 2', 'Cuarto', 'VAR');
        EXEC Arbitraje.usp_DesignarArbitro @IdPartido = @idP, @IdArbitro = @idArb, @RolArbitral = @idRol,
             @IdDesignacion = @idDes OUTPUT, @Advertencia = @adv OUTPUT;
        SET @r += 1;
    END;

    -- Formaciones: si hay suspendidos, primero se intenta con ellos y se muestra el rechazo
    SET @lado = 1;
    WHILE @lado <= 2
    BEGIN
        SET @selEq = CASE @lado WHEN 1 THEN @selL ELSE @selV END;
        SET @isoEq = CASE @lado WHEN 1 THEN @lIso ELSE @vIso END;
        SET @intento = CASE WHEN EXISTS (SELECT 1 FROM Torneo.Jugador j
                                         WHERE j.IdSeleccion = @selEq AND j.FechaBaja IS NULL
                                           AND Incidencia.fn_JugadorSuspendido(j.IdJugador, @idP, DEFAULT, DEFAULT, DEFAULT) = 1)
                            THEN 0 ELSE 1 END;
        WHILE @intento <= 1
        BEGIN
            ;WITH Jug AS (
                SELECT j.IdJugador, j.Dorsal, j.PosicionHabitual AS Pos
                FROM Torneo.Jugador j
                WHERE j.IdSeleccion = @selEq AND j.FechaBaja IS NULL
                  AND (@intento = 0
                       OR Incidencia.fn_JugadorSuspendido(j.IdJugador, @idP, DEFAULT, DEFAULT, DEFAULT) = 0)
            ), Orden AS (
                SELECT IdJugador, Dorsal, Pos, ROW_NUMBER() OVER (PARTITION BY Pos ORDER BY Dorsal) AS Rn FROM Jug
            ), Tit AS (
                SELECT IdJugador, Dorsal, Pos FROM Orden
                WHERE (Pos = 'POR' AND Rn <= 1) OR (Pos = 'DEF' AND Rn <= 4) OR (Pos = 'MED' AND Rn <= 3) OR (Pos = 'DEL' AND Rn <= 3)
            ), Ban AS (
                SELECT TOP (7) IdJugador, Dorsal, Pos FROM Orden
                WHERE IdJugador NOT IN (SELECT IdJugador FROM Tit)
                ORDER BY Dorsal
            )
            SELECT @json = (SELECT x.IdJugador, x.EsTitular, x.Pos AS PosicionCancha
                            FROM (SELECT IdJugador, CAST(1 AS BIT) AS EsTitular, Pos, Dorsal FROM Tit
                                  UNION ALL
                                  SELECT IdJugador, CAST(0 AS BIT), Pos, Dorsal FROM Ban) x
                            ORDER BY x.EsTitular DESC, x.Dorsal
                            FOR JSON PATH);
            IF @intento = 0
            BEGIN
                BEGIN TRY
                    EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @idP, @IdSeleccion = @selEq,
                         @EsquemaTactico = '4-3-3', @Jugadores = @json;
                END TRY
                BEGIN CATCH
                    PRINT CONCAT('    Formacion de ', @isoEq, ' con suspendidos rechazada: ', ERROR_MESSAGE());
                END CATCH
            END
            ELSE
                EXEC Formacion.usp_RegistrarAlineacion @IdPartido = @idP, @IdSeleccion = @selEq,
                     @EsquemaTactico = '4-3-3', @Jugadores = @json;
            SET @intento += 1;
        END;
        SET @lado += 1;
    END;

    -- Publicidad: se proponen las 4 piezas y se confirman antes de empezar
    EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = @idP, @EspaciosAsignados = @esp OUTPUT;
    SET @r = 1;
    WHILE @r <= 4
    BEGIN
        SELECT @idPub = IdPublicidadPartido FROM Publicidad.PublicidadPartido WHERE IdPartido = @idP AND NumeroEspacio = @r;
        EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @idPub, @NumeroEspacio = @r, @Estado = 'Confirmada';
        SET @r += 1;
    END;

    EXEC Torneo.usp_IniciarPartido @IdPartido = @idP;

    -- Cambios, goles y penales de cada seleccion
    SET @lado = 1;
    WHILE @lado <= 2
    BEGIN
        SET @selEq = CASE @lado WHEN 1 THEN @selL ELSE @selV END;
        SET @isoEq = CASE @lado WHEN 1 THEN @lIso ELSE @vIso END;
        SET @goles = CASE @lado WHEN 1 THEN @gl ELSE @gv END;
        SET @pen = CASE @lado WHEN 1 THEN @pl ELSE @pv END;

        -- Cambio por lesion (primer tiempo, minuto 15): defensor titular por defensor del banco
        SET @hayLesion = CASE WHEN EXISTS (SELECT 1 FROM #Lesiones WHERE LocalIso = @lIso AND VisitIso = @vIso AND EquipoIso = @isoEq)
                              THEN 1 ELSE 0 END;
        IF @hayLesion = 1
        BEGIN
            SET @idJug = NULL; SET @idJugEntra = NULL;
            SELECT @idJug = j.IdJugador FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 1 AND a.PosicionCancha = 'DEF'
            ORDER BY j.Dorsal OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
            SELECT @idJugEntra = j.IdJugador FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 0 AND a.PosicionCancha = 'DEF'
            ORDER BY j.Dorsal OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
            EXEC Formacion.usp_RegistrarCambio @IdPartido = @idP, @IdJugadorSale = @idJug, @IdJugadorEntra = @idJugEntra,
                 @Periodo = 'Primer tiempo', @Minuto = 15, @Motivo = 'Lesion', @NumeroVentana = 1, @IdSustitucion = @idCambio OUTPUT;
            PRINT CONCAT('    Cambio por lesion de ', @isoEq, ' al minuto 15 del primer tiempo.');
        END;

        -- Dos cambios tacticos de mediocampistas (minutos 65 y 75)
        SET @ventana = CASE WHEN @hayLesion = 1 THEN 2 ELSE 1 END;
        SET @j = 0;
        WHILE @j <= 1
        BEGIN
            SET @idJug = NULL; SET @idJugEntra = NULL;
            SELECT @idJug = j.IdJugador FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 1 AND a.PosicionCancha = 'MED'
            ORDER BY j.Dorsal OFFSET @j ROWS FETCH NEXT 1 ROWS ONLY;
            SELECT @idJugEntra = j.IdJugador FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 0 AND a.PosicionCancha = 'MED'
            ORDER BY j.Dorsal OFFSET @j ROWS FETCH NEXT 1 ROWS ONLY;
            SET @minuto = 65 + 10 * @j;
            SET @ventanaCambio = @ventana + @j;
            EXEC Formacion.usp_RegistrarCambio @IdPartido = @idP, @IdJugadorSale = @idJug, @IdJugadorEntra = @idJugEntra,
                 @Periodo = 'Segundo tiempo', @Minuto = @minuto, @Motivo = 'Tactico', @NumeroVentana = @ventanaCambio,
                 @IdSustitucion = @idCambio OUTPUT;
            SET @j += 1;
        END;

        -- Goles: delanteros titulares por turno; el primero lo asiste el primer mediocampista titular
        SET @j = 1;
        WHILE @j <= @goles
        BEGIN
            SET @minuto = 20 + 22 * (@j - 1) + (@k % 5);
            SET @periodo = CASE WHEN @minuto <= 45 THEN 'Primer tiempo' ELSE 'Segundo tiempo' END;
            SET @tipoGol = CHOOSE(((@k + @j) % 3) + 1, 'Jugada', 'Cabezazo', 'Tiro libre');
            SET @alAutor = NULL; SET @alAsiste = NULL;
            SELECT @alAutor = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 1 AND a.PosicionCancha = 'DEL'
            ORDER BY j.Dorsal OFFSET ((@j - 1) % 3) ROWS FETCH NEXT 1 ROWS ONLY;
            IF @j = 1 AND @tipoGol <> 'Tiro libre'
                SELECT @alAsiste = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 1 AND a.PosicionCancha = 'MED'
                ORDER BY j.Dorsal OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
            EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alAutor, @TipoGol = @tipoGol, @Periodo = @periodo,
                 @Minuto = @minuto, @IdAlineacionAsistente = @alAsiste, @IdGol = @idGol OUTPUT;
            SET @j += 1;
        END;
        SET @lado += 1;
    END;

    -- Tarjetas puntuales de este partido (la segunda amarilla genera la roja por doble amarilla)
    WHILE EXISTS (SELECT 1 FROM #Tarjetas WHERE Hecha = 0 AND LocalIso = @lIso AND VisitIso = @vIso)
    BEGIN
        SELECT TOP (1) @tId = Id, @tIso = EquipoIso, @tDorsal = Dorsal, @tTipo = Tipo, @tPer = Periodo, @tMin = Minuto, @tMot = Motivo
        FROM #Tarjetas WHERE Hecha = 0 AND LocalIso = @lIso AND VisitIso = @vIso ORDER BY Id;
        SELECT @alT = a.IdAlineacion
        FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
        WHERE a.IdPartido = @idP AND j.CodigoExterno = 'AC-' + @tIso + '-' + RIGHT('0' + CAST(@tDorsal AS VARCHAR(2)), 2);
        EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @idP, @TipoTarjeta = @tTipo, @Periodo = @tPer, @Minuto = @tMin,
             @IdAlineacion = @alT, @Motivo = @tMot, @IdTarjeta = @idTarjeta OUTPUT, @GeneroRoja = @genero OUTPUT;
        IF @genero = 1
            PRINT CONCAT('    Expulsion por doble amonestacion de ', @tIso, ' (dorsal ', @tDorsal, ').');
        IF @tTipo = 'Roja directa'
            PRINT CONCAT('    Roja directa a ', @tIso, ' (dorsal ', @tDorsal, ').');
        UPDATE #Tarjetas SET Hecha = 1 WHERE Id = @tId;
    END;

    -- Una amarilla al primer defensor titular del visitante en los partidos impares
    IF @k % 2 = 1
    BEGIN
        SET @alT = NULL;
        SELECT @alT = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
        WHERE a.IdPartido = @idP AND j.IdSeleccion = @selV AND a.EsTitular = 1 AND a.PosicionCancha = 'DEF'
        ORDER BY j.Dorsal OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
        EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @idP, @TipoTarjeta = 'Amarilla', @Periodo = 'Segundo tiempo',
             @Minuto = 52, @IdAlineacion = @alT, @Motivo = 'Falta tactica', @IdTarjeta = @idTarjeta OUTPUT, @GeneroRoja = @genero OUTPUT;
    END;

    -- Definicion por penales (eliminacion directa con partido empatado)
    SET @lado = 1;
    WHILE @lado <= 2 AND @pl IS NOT NULL
    BEGIN
        SET @selEq = CASE @lado WHEN 1 THEN @selL ELSE @selV END;
        SET @pen = CASE @lado WHEN 1 THEN @pl ELSE @pv END;
        SET @j = 1;
        WHILE @j <= @pen
        BEGIN
            SET @alAutor = NULL;
            SELECT @alAutor = a.IdAlineacion FROM Formacion.Alineacion a JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
            WHERE a.IdPartido = @idP AND j.IdSeleccion = @selEq AND a.EsTitular = 1 AND a.PosicionCancha IN ('DEL', 'DEF')
            ORDER BY CASE WHEN a.PosicionCancha = 'DEL' THEN 0 ELSE 1 END, j.Dorsal OFFSET (@j - 1) ROWS FETCH NEXT 1 ROWS ONLY;
            EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alAutor, @TipoGol = 'Penal', @Periodo = 'Penales',
                 @Minuto = 120, @IdGol = @idGol OUTPUT;
            SET @j += 1;
        END;
        SET @lado += 1;
    END;

    -- Fin del partido y exhibicion de la publicidad confirmada
    SELECT @cap = Capacidad FROM Torneo.Sede WHERE CodigoExterno = @sedeCod;
    SET @asis = @cap - 250 * @k;
    EXEC Torneo.usp_FinalizarPartido @IdPartido = @idP, @Asistencia = @asis;
    EXEC Publicidad.usp_RegistrarExhibicion @IdPartido = @idP, @Exhibidas = @exh OUTPUT, @Descartadas = @desc OUTPUT;

    -- Informe del arbitro principal en los partidos con expulsiones y en la final
    IF @k IN (1, 2, 32)
    BEGIN
        SELECT @desPrincipal = IdDesignacion, @arbPrincipal = IdArbitro
        FROM Arbitraje.DesignacionArbitral WHERE IdPartido = @idP AND RolArbitral = 'Principal';
        SET @informe = CASE @k WHEN 1 THEN 'Expulsion por doble amonestacion de un jugador de Japon al minuto 70.'
                               WHEN 2 THEN 'Roja directa a un defensor de Marruecos por juego brusco grave al minuto 80.'
                               ELSE 'Final sin incidentes.' END;
        SET @sancion = CASE WHEN @k IN (1, 2) THEN 'Un partido de suspension para el jugador expulsado.' ELSE NULL END;
        EXEC Arbitraje.usp_DesignacionArbitral_Modificacion @IdDesignacion = @desPrincipal, @IdArbitro = @arbPrincipal,
             @RolArbitral = 'Principal', @InformePostPartido = @informe, @Sancion = @sancion;
    END;

    SET @k += 1;
END;

/*------------------------------------------------------------------------------
 8. VERIFICACION DE LOS CRITERIOS DE ACEPTACION
 Cada fila compara lo cargado con lo requerido. Los totales incluyen los datos
 que dejaron los tests; los de partidos y formaciones cuentan solo los AC-P.
------------------------------------------------------------------------------*/
PRINT '=== Criterios de aceptacion ===';
DECLARE @idP03 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'AC-P03');
CREATE TABLE #Verif (Orden INT, Criterio VARCHAR(110), Cargado INT, Requerido INT, Exacto BIT);
INSERT INTO #Verif (Orden, Criterio, Cargado, Requerido, Exacto) VALUES
    (1,  'Sedes',
         (SELECT COUNT(*) FROM Torneo.Sede), 8, 0),
    (2,  'Husos horarios distintos entre las sedes',
         (SELECT COUNT(DISTINCT HusoHorario) FROM Torneo.Sede), 3, 0),
    (3,  'Selecciones con al menos 23 convocados activos',
         (SELECT COUNT(*) FROM (SELECT IdSeleccion FROM Torneo.Jugador WHERE FechaBaja IS NULL
                                GROUP BY IdSeleccion HAVING COUNT(*) >= 23) s), 16, 0),
    (4,  'Partidos jugados, entre grupos y eliminacion directa',
         (SELECT COUNT(*) FROM Torneo.Partido WHERE Estado = 'Finalizado' AND CodigoExterno LIKE 'AC-P%'), 24, 0),
    (5,  'Partidos con formacion titular y banco de las dos selecciones',
         (SELECT COUNT(*)
          FROM (SELECT f.IdPartido
                FROM (SELECT a.IdPartido, j.IdSeleccion
                      FROM Formacion.Alineacion a
                      JOIN Torneo.Jugador j ON j.IdJugador = a.IdJugador
                      JOIN Torneo.Partido p ON p.IdPartido = a.IdPartido
                      WHERE p.CodigoExterno LIKE 'AC-P%'
                      GROUP BY a.IdPartido, j.IdSeleccion
                      HAVING SUM(CAST(a.EsTitular AS INT)) = 11 AND SUM(CASE WHEN a.EsTitular = 0 THEN 1 ELSE 0 END) >= 1) f
                GROUP BY f.IdPartido HAVING COUNT(*) = 2) x), 24, 0),
    (6,  'Arbitros',
         (SELECT COUNT(*) FROM Arbitraje.Arbitro), 15, 0),
    (7,  'Partidos con principal, asistentes, cuarto arbitro y VAR',
         (SELECT COUNT(*)
          FROM (SELECT IdPartido FROM Arbitraje.DesignacionArbitral
                GROUP BY IdPartido HAVING COUNT(DISTINCT RolArbitral) = 5) x), 24, 0),
    (8,  'Paises de interes distintos en las piezas de las campanias',
         (SELECT COUNT(DISTINCT IdPais) FROM Publicidad.PiezaPais), 6, 0),
    (9,  'Anunciantes con campanias',
         (SELECT COUNT(DISTINCT IdAnunciante) FROM Publicidad.Campania), 6, 0),
    (10, 'Espacios publicitarios exhibidos (4 por partido jugado)',
         (SELECT COUNT(*) FROM Publicidad.PublicidadPartido pp JOIN Torneo.Partido p ON p.IdPartido = pp.IdPartido
          WHERE pp.Estado = 'Exhibida' AND p.CodigoExterno LIKE 'AC-P%'), 128, 1),
    (11, 'Expulsiones por doble amonestacion',
         (SELECT COUNT(*) FROM Incidencia.Tarjeta WHERE TipoTarjeta = 'Roja por doble amarilla'), 1, 0),
    (12, 'Rojas directas',
         (SELECT COUNT(*) FROM Incidencia.Tarjeta WHERE TipoTarjeta = 'Roja directa'), 1, 0),
    (13, 'Cambios por lesion en los primeros 20 minutos',
         (SELECT COUNT(*) FROM Formacion.Sustitucion WHERE Motivo = 'Lesion' AND Periodo = 'Primer tiempo' AND Minuto <= 20), 1, 0),
    (14, 'Mercados en prime time en el partido AC-P03 (23:00 UTC)',
         (SELECT COUNT(*) FROM Publicidad.fn_SimularPrimeTime(@idP03, DEFAULT, DEFAULT) WHERE EsPrimeTime = 1), 5, 0),
    (15, 'Piezas candidatas en prime time en AC-P03 (se eligen solo 4)',
         (SELECT COUNT(*) FROM Publicidad.fn_CandidatasPartido(@idP03, DEFAULT) WHERE EnPrimeTime = 1), 5, 0),
    (16, 'Jugadores suspendidos que quedaron afuera de la formacion',
         (SELECT COUNT(*)
          FROM Torneo.Partido p
          CROSS APPLY Incidencia.fn_SuspendidosPartido(p.IdPartido, DEFAULT, DEFAULT, DEFAULT) s
          WHERE p.CodigoExterno LIKE 'AC-P%'
            AND NOT EXISTS (SELECT 1 FROM Formacion.Alineacion a WHERE a.IdPartido = p.IdPartido AND a.IdJugador = s.IdJugador)), 3, 0),
    (17, 'Jugadores suspendidos que figuran en una formacion (debe ser 0)',
         (SELECT COUNT(*)
          FROM Torneo.Partido p
          CROSS APPLY Incidencia.fn_SuspendidosPartido(p.IdPartido, DEFAULT, DEFAULT, DEFAULT) s
          WHERE p.CodigoExterno LIKE 'AC-P%'
            AND EXISTS (SELECT 1 FROM Formacion.Alineacion a WHERE a.IdPartido = p.IdPartido AND a.IdJugador = s.IdJugador)), 0, 1);

SELECT Criterio, Cargado, Requerido,
       CASE WHEN (Exacto = 0 AND Cargado >= Requerido) OR (Exacto = 1 AND Cargado = Requerido) THEN 'Cumple' ELSE 'NO CUMPLE' END AS Resultado
FROM #Verif ORDER BY Orden;

PRINT '=== Suspendidos que quedaron afuera de la formacion ===';
SELECT p.CodigoExterno AS Partido, j.CodigoExterno AS Jugador, j.Dorsal,
       CASE WHEN EXISTS (SELECT 1 FROM Formacion.Alineacion a WHERE a.IdPartido = p.IdPartido AND a.IdJugador = j.IdJugador)
            THEN 'En la formacion' ELSE 'Afuera de la formacion' END AS Situacion
FROM Torneo.Partido p
CROSS APPLY Incidencia.fn_SuspendidosPartido(p.IdPartido, DEFAULT, DEFAULT, DEFAULT) s
JOIN Torneo.Jugador j ON j.IdJugador = s.IdJugador
WHERE p.CodigoExterno LIKE 'AC-P%'
ORDER BY p.NumeroPartido, j.CodigoExterno;

PRINT '=== Prime time simultaneo: candidatas de AC-P03 y las 4 elegidas ===';
SELECT c.Posicion, pz.Nombre AS Pieza, an.Nombre AS Anunciante, c.EsPaisDelPartido, c.EnPrimeTime, c.Puntaje, c.Criterio,
       CASE WHEN c.Posicion <= 4 THEN 'Elegida' ELSE 'Descartada' END AS Resultado
FROM Publicidad.fn_CandidatasPartido(@idP03, DEFAULT) c
JOIN Publicidad.Pieza pz     ON pz.IdPieza = c.IdPieza
JOIN Publicidad.Campania ca  ON ca.IdCampania = pz.IdCampania
JOIN Publicidad.Anunciante an ON an.IdAnunciante = ca.IdAnunciante
ORDER BY c.Posicion;

PRINT '=== Espacios exhibidos en AC-P03 ===';
SELECT pp.NumeroEspacio, pz.Nombre AS Pieza, pp.Criterio, pp.Puntaje, pp.Estado
FROM Publicidad.PublicidadPartido pp JOIN Publicidad.Pieza pz ON pz.IdPieza = pp.IdPieza
WHERE pp.IdPartido = @idP03 ORDER BY pp.NumeroEspacio;
GO
