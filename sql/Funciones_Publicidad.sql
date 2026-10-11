/*
================================================================================
UNIVERSIDAD NACIONAL DE LA MATANZA
Departamento de Ingeniería e Investigaciones Tecnológicas
Asignatura: 3641 - Bases de Datos Aplicadas
Comisión: 5600

Integrantes:
- LEOPALDI PINAZZI, AGUSTIN EMANUEL
- AVILA, ALEX AGUSTIN
- SOSA, JESÚS SANTIAGO
- BLANCO, PABLO NICOLAS

Objetivo del Script:
- Implementación de Funciones de Cálculo de Huso Horario y Determinación de Prime Time.
================================================================================
*/
USE MundialDB;
GO

/*
   Publicidad.fn_HoraLocal
   AT TIME ZONE solo acepta los nombres de zona de Windows (sys.time_zone_info),
   por ejemplo 'Argentina Standard Time'. El primer AT TIME ZONE indica que la
   fecha está en UTC; el segundo la convierte al huso del mercado, teniendo en
   cuenta el horario de verano. Devuelve NULL si el huso no es válido.
*/

CREATE OR ALTER FUNCTION Publicidad.fn_HoraLocal (@FechaHoraUtc DATETIME2, @HusoHorario VARCHAR(60))
RETURNS DATETIME2
AS
BEGIN
    IF @FechaHoraUtc IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @HusoHorario)
    BEGIN
        RETURN NULL;
    END;

    RETURN CAST((@FechaHoraUtc AT TIME ZONE 'UTC') AT TIME ZONE @HusoHorario AS DATETIME2);
END;
GO

/*
   Publicidad.fn_EsPrimeTime
   1 si la hora local está entre PRIME_TIME_DESDE (inclusive) y PRIME_TIME_HASTA
   (exclusive): con 19 y 23, de 19:00 a 22:59. Si la franja cruzara la
   medianoche (por ejemplo, de 22 a 2), se toman los dos tramos.
   NULL si no se puede calcular (huso inválido o parámetros sin cargar).
*/
CREATE OR ALTER FUNCTION Publicidad.fn_EsPrimeTime (@FechaHoraUtc DATETIME2, @HusoHorario VARCHAR(60))
RETURNS BIT
AS
BEGIN
    DECLARE @HoraLocal DATETIME2 = Publicidad.fn_HoraLocal(@FechaHoraUtc, @HusoHorario);
    DECLARE @Desde INT = CAST(Config.fn_ParametroNumerico('PRIME_TIME_DESDE') AS INT);
    DECLARE @Hasta INT = CAST(Config.fn_ParametroNumerico('PRIME_TIME_HASTA') AS INT);
    DECLARE @Hora INT;

    IF @HoraLocal IS NULL OR @Desde IS NULL OR @Hasta IS NULL
    BEGIN
        RETURN NULL;
    END;

    -- Desde = Hasta sería una franja vacía (no "todo el día").
    IF @Desde = @Hasta
    BEGIN
        RETURN 0;
    END;

    SET @Hora = DATEPART(HOUR, @HoraLocal);

    IF @Desde < @Hasta
    BEGIN
        RETURN CASE WHEN @Hora >= @Desde AND @Hora < @Hasta THEN 1 ELSE 0 END;
    END;

    RETURN CASE WHEN @Hora >= @Desde OR @Hora < @Hasta THEN 1 ELSE 0 END;
END;
GO

/*
   Publicidad.fn_SimularPrimeTime
   Simulación que pide la consigna: para un partido, la hora local en cada
   mercado (país con huso horario cargado) y si cae en prime time.
   Es también la base de la matriz de prime time de la Entrega 7.
*/
CREATE OR ALTER FUNCTION Publicidad.fn_SimularPrimeTime (@IdPartido INT)
RETURNS TABLE
AS
RETURN
    SELECT p.IdPartido,
           pa.IdPais,
           pa.CodigoIso3,
           pa.Nombre AS Mercado,
           pa.HusoHorario,
           p.FechaHoraUtc,
           Publicidad.fn_HoraLocal(p.FechaHoraUtc, pa.HusoHorario)   AS FechaHoraLocalMercado,
           Publicidad.fn_EsPrimeTime(p.FechaHoraUtc, pa.HusoHorario) AS EsPrimeTime
    FROM Torneo.Partido p
    CROSS JOIN Torneo.Pais pa
    WHERE p.IdPartido = @IdPartido
      AND pa.HusoHorario IS NOT NULL;
GO

/*
   Publicidad.fn_TarifaVigente
   Las vigencias de una misma fase no se superponen (lo valida el ABM),
   así que hay como máximo una. NULL si no hay tarifa vigente.
*/
CREATE OR ALTER FUNCTION Publicidad.fn_TarifaVigente (@Fase VARCHAR(20), @Fecha DATE)
RETURNS INT
AS
BEGIN
    RETURN (SELECT TOP (1) IdTarifa
            FROM Publicidad.TarifaPublicitaria
            WHERE Fase = @Fase
              AND VigenteDesde <= @Fecha
              AND (VigenteHasta IS NULL OR VigenteHasta >= @Fecha)
            ORDER BY VigenteDesde DESC);
END;
GO

/*
   Publicidad.fn_CandidatasPartido
   Todas las piezas de campañas vigentes en la fecha del partido, con los
   tres criterios, el puntaje y la posición final. Las que quedan con
   Posicion 1 a 4 son las que se proponen; el resto queda como evidencia de
   por qué no entró (sirve para el test y para defender el criterio).

   Pasos:
     DatosPartido   fecha UTC del partido y países de las dos selecciones.
     MercadosPieza  un renglón por pieza vigente y país de interés, con los 3 criterios.
     Criterios      un renglón por pieza (MAX y SUM sobre sus mercados).
     Puntajes       puntaje de 0 a 100; el PIB se normaliza con MAX() OVER ().
     Ranking        orden de cada pieza dentro de su anunciante.
     Habilitadas    marca las que respetan el máximo de piezas por anunciante.
*/
CREATE OR ALTER FUNCTION Publicidad.fn_CandidatasPartido (@IdPartido INT)
RETURNS TABLE
AS
RETURN
WITH DatosPartido AS (
    SELECT p.FechaHoraUtc,
           CAST(p.FechaHoraUtc AS DATE) AS FechaPartido,
           sl.IdPais AS IdPaisLocal,
           sv.IdPais AS IdPaisVisitante
    FROM Torneo.Partido p
    JOIN Torneo.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    JOIN Torneo.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    WHERE p.IdPartido = @IdPartido
),
MercadosPieza AS (
    SELECT pz.IdPieza,
           c.IdAnunciante,
           CASE WHEN pp.IdPais IN (dp.IdPaisLocal, dp.IdPaisVisitante) THEN 1 ELSE 0 END AS EsPaisDelPartido,
           ISNULL(pa.PibPerCapitaUsd, 0) AS Pib,
           ISNULL(CAST(Publicidad.fn_EsPrimeTime(dp.FechaHoraUtc, pa.HusoHorario) AS INT), 0) AS EsPrimeTime
    FROM DatosPartido dp
    JOIN Publicidad.Campania c   ON dp.FechaPartido BETWEEN c.FechaInicio AND c.FechaFin
    JOIN Publicidad.Pieza pz     ON pz.IdCampania = c.IdCampania
    JOIN Publicidad.PiezaPais pp ON pp.IdPieza = pz.IdPieza
    JOIN Torneo.Pais pa          ON pa.IdPais = pp.IdPais
),
Criterios AS (
    SELECT IdPieza,
           IdAnunciante,
           MAX(EsPaisDelPartido) AS EsPaisDelPartido,
           MAX(Pib)              AS PibMaximo,
           SUM(EsPrimeTime)      AS MercadosEnPrimeTime
    FROM MercadosPieza
    GROUP BY IdPieza, IdAnunciante
),
Puntajes AS (
    SELECT IdPieza,
           IdAnunciante,
           EsPaisDelPartido,
           PibMaximo,
           MercadosEnPrimeTime,
           CAST(50.0 * EsPaisDelPartido
                + ISNULL(30.0 * PibMaximo / NULLIF(MAX(PibMaximo) OVER (), 0), 0)
                + CASE WHEN MercadosEnPrimeTime > 0 THEN 20.0 ELSE 0 END
                AS DECIMAL(9,2)) AS Puntaje
    FROM Criterios
),
Ranking AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY IdAnunciante
                              ORDER BY Puntaje DESC, MercadosEnPrimeTime DESC, IdPieza) AS OrdenEnAnunciante
    FROM Puntajes
),
Habilitadas AS (
    SELECT *,
           CASE WHEN OrdenEnAnunciante <= ISNULL(CAST(Config.fn_ParametroNumerico('MAX_PIEZAS_POR_ANUNCIANTE') AS INT), 4)
                THEN 1 ELSE 0 END AS Habilitada
    FROM Ranking
)
SELECT IdPieza,
       IdAnunciante,
       EsPaisDelPartido,
       PibMaximo,
       MercadosEnPrimeTime,
       Puntaje,
       CASE WHEN EsPaisDelPartido = 1     THEN 'Pais del partido'
            WHEN MercadosEnPrimeTime > 0  THEN 'Prime time'
            ELSE 'Poder adquisitivo' END AS Criterio,
       OrdenEnAnunciante,
       Habilitada,
       CASE WHEN Habilitada = 1
            THEN ROW_NUMBER() OVER (PARTITION BY Habilitada
                                    ORDER BY Puntaje DESC, MercadosEnPrimeTime DESC, IdPieza)
       END AS Posicion
FROM Habilitadas;
GO

/* ------------------------------------------------------------------
   Parámetro propio del módulo (se carga con el SP, no con INSERT directo)
   ------------------------------------------------------------------ */
EXEC Config.Parametro_Guardar 'MAX_PIEZAS_POR_ANUNCIANTE', 'Máximo de espacios que un anunciante puede ocupar en un mismo partido', 1, NULL;
GO

PRINT 'Funciones de publicidad creadas.';
GO
