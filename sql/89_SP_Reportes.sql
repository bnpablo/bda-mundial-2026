/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-15
 Script       : 89_SP_Reportes.sql
 Objetivo     : Entrega 7. Procedimientos de reportes del esquema Reportes:
                  usp_ReportarGoleadores            goleadores por seleccion, fase y torneo
                  usp_ReportarTarjetas              tarjetas por seleccion y jugador, con suspensiones
                  usp_ReportarDesignaciones         partidos de cada arbitro y tarjetas que senalo (XML)
                  usp_ReportarOcupacionPublicitaria anunciantes por espacio e ingresos por sede y partido
                  usp_ReportarMatrizPrimeTime       tabla cruzada partido x mercado (PIVOT dinamico)
                  usp_ReportarPlantillas            selecciones con sus convocados anidados (XML)
                  usp_ReportarResultados            tabla de posiciones y resultados de los partidos
                Los reportes solo leen datos. Los filtros son opcionales: con NULL
                muestran todo. Un filtro con un id que no existe da error 50001.
 Requisito    : ejecutar despues de 59_Funciones_Publicidad.sql y de
                75_Funciones_Incidencia.sql (usa sus funciones).
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarGoleadores
 Una fila por jugador con los goles de cada fase (columnas fijas: las fases son
 siempre las mismas 7) y el total del torneo. Puesto es el ranking del torneo:
 jugadores con los mismos goles comparten puesto (DENSE_RANK).
 Mismo criterio que Incidencia.fn_TablaGoleadores: no cuentan los goles en
 contra ni los de la definicion por penales.
 Ejemplo: EXEC Reportes.usp_ReportarGoleadores @IdSeleccion = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarGoleadores
    @IdSeleccion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        THROW 50001, 'La seleccion indicada no existe. ', 1;

    WITH Goles AS (
        SELECT j.IdJugador, j.Apellido, j.Nombre, pa.Nombre AS Seleccion, p.Fase, g.TipoGol
        FROM Incidencia.Gol g
        JOIN Formacion.Alineacion a ON a.IdAlineacion = g.IdAlineacionAutor
        JOIN Torneo.Partido p       ON p.IdPartido = a.IdPartido
        JOIN Torneo.Jugador j       ON j.IdJugador = a.IdJugador
        JOIN Torneo.Seleccion s     ON s.IdSeleccion = j.IdSeleccion
        JOIN Torneo.Pais pa         ON pa.IdPais = s.IdPais
        WHERE g.TipoGol <> 'En contra'
          AND g.Periodo <> 'Penales'
          AND (@IdSeleccion IS NULL OR s.IdSeleccion = @IdSeleccion)
    )
    SELECT DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)                  AS Puesto,
           Seleccion, Apellido, Nombre,
           SUM(CASE WHEN Fase = 'Grupos'        THEN 1 ELSE 0 END) AS Grupos,
           SUM(CASE WHEN Fase = 'Dieciseisavos' THEN 1 ELSE 0 END) AS Dieciseisavos,
           SUM(CASE WHEN Fase = 'Octavos'       THEN 1 ELSE 0 END) AS Octavos,
           SUM(CASE WHEN Fase = 'Cuartos'       THEN 1 ELSE 0 END) AS Cuartos,
           SUM(CASE WHEN Fase = 'Semifinal'     THEN 1 ELSE 0 END) AS Semifinal,
           SUM(CASE WHEN Fase = 'Tercer puesto' THEN 1 ELSE 0 END) AS TercerPuesto,
           SUM(CASE WHEN Fase = 'Final'         THEN 1 ELSE 0 END) AS Final,
           COUNT(*)                                                AS Total,
           SUM(CASE WHEN TipoGol = 'Penal' THEN 1 ELSE 0 END)      AS DePenal
    FROM Goles
    GROUP BY IdJugador, Seleccion, Apellido, Nombre
    ORDER BY Total DESC, Seleccion, Apellido, Nombre;
END
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarTarjetas
 Devuelve dos resultados:
   1. Tarjetas por seleccion (Incidencia.fn_TarjetasPorSeleccion): incluye las
      del cuerpo tecnico y las selecciones sin tarjetas.
   2. Tarjetas por jugador (solo jugadores con alguna tarjeta) y su situacion
      para el proximo partido de su seleccion.
 Supuesto: una suspension esta activa si el jugador esta suspendido para el
 proximo partido Programado de su seleccion (Incidencia.fn_JugadorSuspendido,
 con los criterios del reglamento). Si la seleccion no tiene partidos
 pendientes, la columna lo indica.
 Ejemplo: EXEC Reportes.usp_ReportarTarjetas @IdSeleccion = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarTarjetas
    @IdSeleccion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        THROW 50001, 'La seleccion indicada no existe. ', 1;

    -- 1. Por seleccion.
    SELECT Pais AS Seleccion, Amarillas, RojasDirectas, RojasPorDobleAmarilla
    FROM Incidencia.fn_TarjetasPorSeleccion()
    WHERE @IdSeleccion IS NULL OR IdSeleccion = @IdSeleccion
    ORDER BY Amarillas + RojasDirectas + RojasPorDobleAmarilla DESC, Pais;

    -- 2. Por jugador, con la situacion para el proximo partido.
    WITH TarjetasJugador AS (
        SELECT j.IdJugador, j.IdSeleccion, pa.Nombre AS Seleccion, j.Dorsal, j.Apellido, j.Nombre,
               SUM(CASE WHEN t.TipoTarjeta = 'Amarilla' THEN 1 ELSE 0 END)                AS Amarillas,
               SUM(CASE WHEN t.TipoTarjeta = 'Roja directa' THEN 1 ELSE 0 END)            AS RojasDirectas,
               SUM(CASE WHEN t.TipoTarjeta = 'Roja por doble amarilla' THEN 1 ELSE 0 END) AS RojasPorDobleAmarilla
        FROM Incidencia.Tarjeta t
        JOIN Formacion.Alineacion a ON a.IdAlineacion = t.IdAlineacion
        JOIN Torneo.Jugador j       ON j.IdJugador = a.IdJugador
        JOIN Torneo.Seleccion s     ON s.IdSeleccion = j.IdSeleccion
        JOIN Torneo.Pais pa         ON pa.IdPais = s.IdPais
        WHERE @IdSeleccion IS NULL OR j.IdSeleccion = @IdSeleccion
        GROUP BY j.IdJugador, j.IdSeleccion, pa.Nombre, j.Dorsal, j.Apellido, j.Nombre
    )
    SELECT tj.Seleccion, tj.Dorsal, tj.Apellido, tj.Nombre,
           tj.Amarillas, tj.RojasDirectas, tj.RojasPorDobleAmarilla,
           prox.NumeroPartido AS ProximoPartido,
           CASE
               WHEN prox.IdPartido IS NULL THEN 'Sin partidos pendientes'
               WHEN Incidencia.fn_JugadorSuspendido(tj.IdJugador, prox.IdPartido, DEFAULT, DEFAULT, DEFAULT) = 1
                   THEN 'Suspendido'
               ELSE 'Habilitado'
           END AS SituacionProximoPartido
    FROM TarjetasJugador tj
    OUTER APPLY (SELECT TOP (1) p.IdPartido, p.NumeroPartido
                 FROM Torneo.Partido p
                 WHERE tj.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
                   AND p.Estado = 'Programado'
                 ORDER BY p.FechaHoraUtc) prox
    ORDER BY tj.Seleccion, tj.Apellido, tj.Nombre;
END
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarDesignaciones (devuelve XML)
 Un elemento Arbitro por cada arbitro con designaciones; adentro, un elemento
 Partido por cada designacion (con el rol) y, en los partidos donde fue
 Principal, las tarjetas de ese partido.
 Supuesto: las tarjetas de un partido las senala el arbitro Principal. En la
 tabla Tarjeta no se guarda el arbitro, y segun las Reglas de Juego (regla 5)
 las sanciones disciplinarias las toma el arbitro; asistentes y VAR solo avisan
 o recomiendan. Las tarjetas de un partido sin arbitro Principal designado no
 aparecen en este reporte.
 Ejemplo: EXEC Reportes.usp_ReportarDesignaciones @IdArbitro = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarDesignaciones
    @IdArbitro INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdArbitro IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro WHERE IdArbitro = @IdArbitro)
        THROW 50001, 'El arbitro indicado no existe. ', 1;

    SELECT (
        SELECT ar.CodigoExterno AS '@Codigo',
               ar.Apellido      AS '@Apellido',
               ar.Nombre        AS '@Nombre',
               pa.Nombre        AS '@Pais',
               ar.Categoria     AS '@Categoria',
               (SELECT COUNT(*) FROM Arbitraje.DesignacionArbitral d
                WHERE d.IdArbitro = ar.IdArbitro) AS '@Partidos',
               (SELECT COUNT(*) FROM Arbitraje.DesignacionArbitral d
                JOIN Incidencia.Tarjeta t ON t.IdPartido = d.IdPartido
                WHERE d.IdArbitro = ar.IdArbitro AND d.RolArbitral = 'Principal'
                  AND t.TipoTarjeta = 'Amarilla') AS '@Amonestaciones',
               (SELECT COUNT(*) FROM Arbitraje.DesignacionArbitral d
                JOIN Incidencia.Tarjeta t ON t.IdPartido = d.IdPartido
                WHERE d.IdArbitro = ar.IdArbitro AND d.RolArbitral = 'Principal'
                  AND t.TipoTarjeta <> 'Amarilla') AS '@Expulsiones',
               -- Partidos del arbitro.
               (SELECT p.NumeroPartido                  AS '@Numero',
                       p.Fase                           AS '@Fase',
                       p.FechaHoraUtc                   AS '@FechaHoraUtc',
                       p.Estado                         AS '@Estado',
                       ISNULL(pl.Nombre, 'A definir')   AS '@Local',
                       ISNULL(pv.Nombre, 'A definir')   AS '@Visitante',
                       d.RolArbitral                    AS '@Rol',
                       -- Tarjetas del partido, solo si fue Principal.
                       (SELECT t.Periodo                AS '@Periodo',
                               t.Minuto                 AS '@Minuto',
                               t.TipoTarjeta            AS '@Tipo',
                               ISNULL(j.Apellido + ', ' + j.Nombre,
                                      ct.Apellido + ', ' + ct.Nombre + ' (cuerpo tecnico)') AS '@Sancionado',
                               ps.Nombre                AS '@Seleccion',
                               t.Motivo                 AS '@Motivo'
                        FROM Incidencia.Tarjeta t
                        LEFT JOIN Formacion.Alineacion a     ON a.IdAlineacion = t.IdAlineacion
                        LEFT JOIN Torneo.Jugador j           ON j.IdJugador = a.IdJugador
                        LEFT JOIN Torneo.CuerpoTecnico ct    ON ct.IdCuerpoTecnico = t.IdCuerpoTecnico
                        LEFT JOIN Torneo.Seleccion s         ON s.IdSeleccion = ISNULL(j.IdSeleccion, ct.IdSeleccion)
                        LEFT JOIN Torneo.Pais ps             ON ps.IdPais = s.IdPais
                        WHERE t.IdPartido = p.IdPartido
                          AND d.RolArbitral = 'Principal'
                        ORDER BY Incidencia.fn_MomentoPartido(t.Periodo, t.Minuto, t.MinutoAdicional)
                        FOR XML PATH('Tarjeta'), TYPE)
                FROM Arbitraje.DesignacionArbitral d
                JOIN Torneo.Partido p         ON p.IdPartido = d.IdPartido
                LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
                LEFT JOIN Torneo.Pais pl      ON pl.IdPais = sl.IdPais
                LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
                LEFT JOIN Torneo.Pais pv      ON pv.IdPais = sv.IdPais
                WHERE d.IdArbitro = ar.IdArbitro
                ORDER BY p.FechaHoraUtc
                FOR XML PATH('Partido'), TYPE)
        FROM Arbitraje.Arbitro ar
        JOIN Torneo.Pais pa ON pa.IdPais = ar.IdPais
        WHERE (@IdArbitro IS NULL OR ar.IdArbitro = @IdArbitro)
          AND EXISTS (SELECT 1 FROM Arbitraje.DesignacionArbitral d WHERE d.IdArbitro = ar.IdArbitro)
        ORDER BY ar.Apellido, ar.Nombre
        FOR XML PATH('Arbitro'), ROOT('Designaciones'), TYPE
    ) AS Designaciones;
END
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarOcupacionPublicitaria
 Solo cuentan los espacios en estado Exhibida. Devuelve dos resultados:
   1. Por partido: el anunciante de cada uno de los 4 espacios (PIVOT con
      columnas fijas, los espacios son siempre 1 a 4) y el ingreso del partido.
   2. Por sede: partidos con publicidad, espacios exhibidos e ingresos.
 El ingreso de un espacio es el monto de la tarifa que se le asigno. Los
 espacios de un partido usan la misma tarifa (la vigente para su fase y
 fecha), asi que un partido tiene una sola moneda.
 Ejemplo: EXEC Reportes.usp_ReportarOcupacionPublicitaria @IdSede = NULL, @IdPartido = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarOcupacionPublicitaria
    @IdSede    INT = NULL,
    @IdPartido INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2000) = '';

    IF @IdSede IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Sede WHERE IdSede = @IdSede)
        SET @errores += 'La sede indicada no existe. ';

    IF @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdPartido = @IdPartido)
        SET @errores += 'El partido indicado no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    CREATE TABLE #exhibida (
        IdPartido     INT,
        IdSede        INT,
        NumeroEspacio INT,
        Anunciante    VARCHAR(120) COLLATE DATABASE_DEFAULT,
        Monto         DECIMAL(18, 2),
        Moneda        CHAR(3) COLLATE DATABASE_DEFAULT
    );

    INSERT INTO #exhibida (IdPartido, IdSede, NumeroEspacio, Anunciante, Monto, Moneda)
    SELECT pp.IdPartido, p.IdSede, pp.NumeroEspacio, an.Nombre, tf.Monto, tf.Moneda
    FROM Publicidad.PublicidadPartido pp
    JOIN Torneo.Partido p                  ON p.IdPartido = pp.IdPartido
    JOIN Publicidad.Pieza pz               ON pz.IdPieza = pp.IdPieza
    JOIN Publicidad.Campania c             ON c.IdCampania = pz.IdCampania
    JOIN Publicidad.Anunciante an          ON an.IdAnunciante = c.IdAnunciante
    JOIN Publicidad.TarifaPublicitaria tf  ON tf.IdTarifa = pp.IdTarifa
    WHERE pp.Estado = 'Exhibida'
      AND (@IdSede IS NULL OR p.IdSede = @IdSede)
      AND (@IdPartido IS NULL OR pp.IdPartido = @IdPartido);

    -- 1. Por partido.
    SELECT se.NombreEstadio AS Sede, se.Ciudad, p.NumeroPartido, p.Fase, p.FechaHoraUtc,
           ISNULL(pl.Nombre, 'A definir') + ' - ' + ISNULL(pv.Nombre, 'A definir') AS Partido,
           ISNULL(esp.[1], '(libre)') AS Espacio1,
           ISNULL(esp.[2], '(libre)') AS Espacio2,
           ISNULL(esp.[3], '(libre)') AS Espacio3,
           ISNULL(esp.[4], '(libre)') AS Espacio4,
           ing.Espacios, ing.Ingresos, ing.Moneda
    FROM (SELECT IdPartido, NumeroEspacio, Anunciante FROM #exhibida) datos
    PIVOT (MAX(Anunciante) FOR NumeroEspacio IN ([1], [2], [3], [4])) esp
    JOIN (SELECT IdPartido, COUNT(*) AS Espacios, SUM(Monto) AS Ingresos, MAX(Moneda) AS Moneda
          FROM #exhibida
          GROUP BY IdPartido) ing ON ing.IdPartido = esp.IdPartido
    JOIN Torneo.Partido p         ON p.IdPartido = esp.IdPartido
    JOIN Torneo.Sede se           ON se.IdSede = p.IdSede
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Pais pl      ON pl.IdPais = sl.IdPais
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN Torneo.Pais pv      ON pv.IdPais = sv.IdPais
    ORDER BY se.NombreEstadio, p.FechaHoraUtc;

    -- 2. Por sede.
    SELECT se.NombreEstadio AS Sede, se.Ciudad,
           COUNT(DISTINCT e.IdPartido) AS Partidos,
           COUNT(*)                    AS Espacios,
           SUM(e.Monto)                AS Ingresos,
           e.Moneda
    FROM #exhibida e
    JOIN Torneo.Sede se ON se.IdSede = e.IdSede
    GROUP BY se.NombreEstadio, se.Ciudad, e.Moneda
    ORDER BY Ingresos DESC, se.NombreEstadio;
END
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarMatrizPrimeTime
 Tabla cruzada: una fila por partido y una columna por mercado (pais cargado en
 Torneo.Pais, por su codigo ISO). Cada celda vale 1 si el horario del partido
 cae en prime time en ese mercado y 0 si no (Publicidad.fn_SimularPrimeTime).
 Por defecto el prime time es de 19 a 23 hora local.

 Usa SQL dinamico solo para el PIVOT: PIVOT necesita los nombres de las
 columnas escritos en la consulta y los mercados salen de la tabla, asi que la
 lista se arma en tiempo de ejecucion (como en el ejemplo de PIVOT de la
 catedra). Para evitar inyeccion, a la cadena solo entran codigos de pais de la
 tabla, encerrados con QUOTENAME; los parametros no se concatenan: los datos
 se calculan antes en #primeTime, que la consulta dinamica puede leer porque
 la crea este SP. Se ejecuta con EXEC sobre un VARCHAR(MAX).
 Ejemplo: EXEC Reportes.usp_ReportarMatrizPrimeTime @HoraDesde = 19, @HoraHasta = 23, @IdPartido = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarMatrizPrimeTime
    @HoraDesde INT = 19,
    @HoraHasta INT = 23,
    @IdPartido INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @columnas VARCHAR(MAX), @consulta VARCHAR(MAX);

    SET @HoraDesde = ISNULL(@HoraDesde, 19);
    SET @HoraHasta = ISNULL(@HoraHasta, 23);

    IF @HoraDesde NOT BETWEEN 0 AND 23
        SET @errores += 'La hora de inicio debe estar entre 0 y 23. ';

    IF @HoraHasta NOT BETWEEN 1 AND 24
        SET @errores += 'La hora de fin debe estar entre 1 y 24. ';

    IF @HoraDesde BETWEEN 0 AND 23 AND @HoraHasta BETWEEN 1 AND 24 AND @HoraDesde >= @HoraHasta
        SET @errores += 'La hora de inicio debe ser menor que la de fin. ';

    IF @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Partido WHERE IdPartido = @IdPartido)
        SET @errores += 'El partido indicado no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    -- Datos de la matriz, en vertical: una fila por partido y mercado.
    CREATE TABLE #primeTime (
        NumeroPartido INT,
        Fase          VARCHAR(20) COLLATE DATABASE_DEFAULT,
        FechaHoraUtc  DATETIME2,
        Partido       VARCHAR(200) COLLATE DATABASE_DEFAULT,
        CodigoIso3    CHAR(3) COLLATE DATABASE_DEFAULT,
        EsPrimeTime   INT
    );

    INSERT INTO #primeTime (NumeroPartido, Fase, FechaHoraUtc, Partido, CodigoIso3, EsPrimeTime)
    SELECT p.NumeroPartido, p.Fase, p.FechaHoraUtc,
           ISNULL(pl.Nombre, 'A definir') + ' - ' + ISNULL(pv.Nombre, 'A definir'),
           m.CodigoIso3,
           CAST(m.EsPrimeTime AS INT)       -- PIVOT necesita una funcion de agregado y MAX no acepta BIT
    FROM Torneo.Partido p
    CROSS APPLY Publicidad.fn_SimularPrimeTime(p.IdPartido, @HoraDesde, @HoraHasta) m
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Pais pl      ON pl.IdPais = sl.IdPais
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN Torneo.Pais pv      ON pv.IdPais = sv.IdPais
    WHERE @IdPartido IS NULL OR p.IdPartido = @IdPartido;

    -- Sin partidos no hay matriz. Si hay partidos hay paises (toda sede tiene pais).
    IF NOT EXISTS (SELECT 1 FROM #primeTime)
    BEGIN
        SELECT 'No hay partidos cargados.' AS Mensaje;
        RETURN;
    END;

    -- Lista de columnas: [ARG],[BRA],... en orden alfabetico.
    SELECT @columnas = STRING_AGG(CAST(QUOTENAME(CodigoIso3) AS VARCHAR(MAX)), ',')
                       WITHIN GROUP (ORDER BY CodigoIso3)
    FROM Torneo.Pais;

    SET @consulta =
        'SELECT NumeroPartido, Fase, FechaHoraUtc, Partido, ' + @columnas + '
         FROM (SELECT NumeroPartido, Fase, FechaHoraUtc, Partido, CodigoIso3, EsPrimeTime
               FROM #primeTime) datos
         PIVOT (MAX(EsPrimeTime) FOR CodigoIso3 IN (' + @columnas + ')) matriz
         ORDER BY FechaHoraUtc, NumeroPartido;';

    EXEC (@consulta);
END
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarPlantillas (devuelve XML)
 Un elemento Seleccion por seleccion con su vector anidado de convocados:
 nombre, apellido, posicion, club y dorsal. Solo los jugadores activos (sin
 fecha de baja). Las selecciones se ordenan por grupo y los jugadores por dorsal.
 Ejemplo: EXEC Reportes.usp_ReportarPlantillas @IdSeleccion = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarPlantillas
    @IdSeleccion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        THROW 50001, 'La seleccion indicada no existe. ', 1;

    SELECT (
        SELECT pa.Nombre        AS '@Pais',
               pa.CodigoIso3    AS '@Codigo',
               s.Grupo          AS '@Grupo',
               pa.Confederacion AS '@Confederacion',
               (SELECT COUNT(*) FROM Torneo.Jugador j
                WHERE j.IdSeleccion = s.IdSeleccion AND j.FechaBaja IS NULL) AS '@CantidadConvocados',
               (SELECT j.Dorsal           AS '@Dorsal',
                       j.Nombre           AS '@Nombre',
                       j.Apellido         AS '@Apellido',
                       j.PosicionHabitual AS '@Posicion',
                       j.ClubOrigen       AS '@Club'
                FROM Torneo.Jugador j
                WHERE j.IdSeleccion = s.IdSeleccion
                  AND j.FechaBaja IS NULL
                ORDER BY j.Dorsal
                FOR XML PATH('Jugador'), ROOT('Convocados'), TYPE)
        FROM Torneo.Seleccion s
        JOIN Torneo.Pais pa ON pa.IdPais = s.IdPais
        WHERE @IdSeleccion IS NULL OR s.IdSeleccion = @IdSeleccion
        ORDER BY s.Grupo, pa.Nombre
        FOR XML PATH('Seleccion'), ROOT('Selecciones'), TYPE
    ) AS Plantillas;
END
GO

/*------------------------------------------------------------------------------
 Reportes.usp_ReportarResultados
 Devuelve dos resultados:
   1. Tabla de posiciones de la fase de grupos, con los partidos de Grupos
      Finalizados: 3 puntos por partido ganado y 1 por empate. Orden dentro del
      grupo: puntos, diferencia de gol, goles a favor y nombre.
   2. Partidos con su resultado, los penales si los hubo, el ganador y los
      goleadores con el minuto ((p) de penal, (e.c.) en contra). Ordenados
      por fase y fecha.
 Filtros: @IdSeleccion deja su grupo en la tabla y sus partidos en la lista;
 @Fase filtra la lista de partidos.
 Ejemplo: EXEC Reportes.usp_ReportarResultados @IdSeleccion = NULL, @Fase = NULL;
------------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE Reportes.usp_ReportarResultados
    @IdSeleccion INT         = NULL,
    @Fase        VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @grupo CHAR(1);

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @errores += 'La seleccion indicada no existe. ';

    IF @Fase IS NOT NULL AND Incidencia.fn_OrdenFase(@Fase) IS NULL
        SET @errores += 'La fase debe ser Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto o Final. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    SELECT @grupo = Grupo FROM Torneo.Seleccion WHERE IdSeleccion = @IdSeleccion;

    -- 1. Tabla de posiciones.
    WITH Jugados AS (
        SELECT IdSeleccionLocal AS IdSeleccion, GolesLocal AS GF, GolesVisitante AS GC
        FROM Torneo.Partido
        WHERE Fase = 'Grupos' AND Estado = 'Finalizado'
        UNION ALL
        SELECT IdSeleccionVisitante, GolesVisitante, GolesLocal
        FROM Torneo.Partido
        WHERE Fase = 'Grupos' AND Estado = 'Finalizado'
    ),
    Tabla AS (
        SELECT s.Grupo, pa.Nombre AS Seleccion,
               COUNT(x.IdSeleccion)                         AS PJ,
               SUM(CASE WHEN x.GF > x.GC THEN 1 ELSE 0 END)  AS PG,
               SUM(CASE WHEN x.GF = x.GC THEN 1 ELSE 0 END)  AS PE,
               SUM(CASE WHEN x.GF < x.GC THEN 1 ELSE 0 END)  AS PP,
               ISNULL(SUM(x.GF), 0)                          AS GF,
               ISNULL(SUM(x.GC), 0)                          AS GC
        FROM Torneo.Seleccion s
        JOIN Torneo.Pais pa    ON pa.IdPais = s.IdPais
        LEFT JOIN Jugados x    ON x.IdSeleccion = s.IdSeleccion
        WHERE @grupo IS NULL OR s.Grupo = @grupo
        GROUP BY s.Grupo, pa.Nombre
    )
    SELECT Grupo,
           ROW_NUMBER() OVER (PARTITION BY Grupo ORDER BY PG * 3 + PE DESC, GF - GC DESC, GF DESC, Seleccion) AS Posicion,
           Seleccion, PJ, PG, PE, PP, GF, GC, GF - GC AS DG, PG * 3 + PE AS Pts
    FROM Tabla
    ORDER BY Grupo, Posicion;

    -- 2. Partidos.
    SELECT p.Fase, p.NumeroPartido, p.FechaHoraUtc, se.NombreEstadio AS Sede,
           ISNULL(pl.Nombre, 'A definir') AS Local,
           p.GolesLocal, p.GolesVisitante,
           ISNULL(pv.Nombre, 'A definir') AS Visitante,
           CASE WHEN p.PenalesLocal IS NOT NULL
                THEN CAST(p.PenalesLocal AS VARCHAR(3)) + ' - ' + CAST(p.PenalesVisitante AS VARCHAR(3))
           END AS Penales,
           p.Estado,
           CASE
               WHEN p.Estado <> 'Finalizado' THEN NULL
               WHEN p.GolesLocal > p.GolesVisitante
                    OR (p.GolesLocal = p.GolesVisitante AND p.PenalesLocal > p.PenalesVisitante) THEN pl.Nombre
               WHEN p.GolesLocal < p.GolesVisitante
                    OR (p.GolesLocal = p.GolesVisitante AND p.PenalesLocal < p.PenalesVisitante) THEN pv.Nombre
               ELSE 'Empate'
           END AS Ganador,
           gol.Goleadores
    FROM Torneo.Partido p
    JOIN Torneo.Sede se           ON se.IdSede = p.IdSede
    LEFT JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    LEFT JOIN Torneo.Pais pl      ON pl.IdPais = sl.IdPais
    LEFT JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    LEFT JOIN Torneo.Pais pv      ON pv.IdPais = sv.IdPais
    OUTER APPLY (SELECT STRING_AGG(j.Apellido + ' ' + CAST(g.Minuto AS VARCHAR(3))
                                   + CASE WHEN g.MinutoAdicional > 0 THEN '+' + CAST(g.MinutoAdicional AS VARCHAR(2)) ELSE '' END
                                   + ''''
                                   + CASE g.TipoGol WHEN 'Penal' THEN ' (p)' WHEN 'En contra' THEN ' (e.c.)' ELSE '' END, ', ')
                        WITHIN GROUP (ORDER BY Incidencia.fn_MomentoPartido(g.Periodo, g.Minuto, g.MinutoAdicional)) AS Goleadores
                 FROM Incidencia.Gol g
                 JOIN Formacion.Alineacion a ON a.IdAlineacion = g.IdAlineacionAutor
                 JOIN Torneo.Jugador j       ON j.IdJugador = a.IdJugador
                 WHERE a.IdPartido = p.IdPartido
                   AND g.Periodo <> 'Penales') gol
    WHERE (@IdSeleccion IS NULL OR @IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante))
      AND (@Fase IS NULL OR p.Fase = @Fase)
    ORDER BY Incidencia.fn_OrdenFase(p.Fase), p.FechaHoraUtc;
END
GO
