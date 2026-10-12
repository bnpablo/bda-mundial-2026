/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 59_Funciones_Publicidad.sql
 Objetivo     : Funciones de publicidad:
                  Publicidad.fn_HoraLocalMercado   hora del partido en un mercado (pais).
                  Publicidad.fn_EsPrimeTime        si esa hora cae en prime time.
                  Publicidad.fn_SimularPrimeTime   simulacion de prime time de un partido.
                  Publicidad.fn_TarifaVigente      tarifa de una fase en una fecha.
                  Publicidad.fn_CandidatasPartido  piezas ordenadas para un partido.
                Los criterios (franja de prime time y maximo de piezas por
                anunciante) son parametros con un valor por defecto, sin tabla de
                configuracion.
 Prerrequisito: 06_Tablas_Publicidad.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Publicidad.fn_HoraLocalMercado
 Convierte la fecha y hora UTC del partido al huso horario de un pais. El huso
 es un nombre de zona horaria de Windows (el que valida Torneo.usp_Pais_Alta).
 El primer AT TIME ZONE indica que la fecha esta en UTC y el segundo la pasa al
 huso del mercado, teniendo en cuenta el horario de verano.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Publicidad.fn_HoraLocalMercado (@FechaHoraUtc DATETIME2, @HusoHorario VARCHAR(60))
RETURNS DATETIME2
AS
BEGIN
    RETURN CAST((@FechaHoraUtc AT TIME ZONE 'UTC') AT TIME ZONE @HusoHorario AS DATETIME2);
END
GO

/*------------------------------------------------------------------------------
 Publicidad.fn_EsPrimeTime
 Devuelve 1 si la hora local del mercado esta entre @HoraDesde (inclusive) y
 @HoraHasta (exclusive). Por defecto de 19 a 23: de 19:00 a 22:59.
 Ejemplo: Publicidad.fn_EsPrimeTime(@FechaHoraUtc, 'Argentina Standard Time', DEFAULT, DEFAULT)
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Publicidad.fn_EsPrimeTime (
    @FechaHoraUtc DATETIME2,
    @HusoHorario  VARCHAR(60),
    @HoraDesde    INT = 19,
    @HoraHasta    INT = 23
)
RETURNS BIT
AS
BEGIN
    DECLARE @hora INT = DATEPART(HOUR, Publicidad.fn_HoraLocalMercado(@FechaHoraUtc, @HusoHorario));

    IF @hora >= ISNULL(@HoraDesde, 19) AND @hora < ISNULL(@HoraHasta, 23)
        RETURN 1;

    RETURN 0;
END
GO

/*------------------------------------------------------------------------------
 Publicidad.fn_SimularPrimeTime
 Simulacion que pide la consigna: para un partido, la hora local en cada
 mercado (cada pais cargado) y si cae en prime time. Es tambien la base de la
 matriz de prime time de la Entrega 7.
 Ejemplo: SELECT * FROM Publicidad.fn_SimularPrimeTime(@IdPartido, DEFAULT, DEFAULT)
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Publicidad.fn_SimularPrimeTime (@IdPartido INT, @HoraDesde INT = 19, @HoraHasta INT = 23)
RETURNS TABLE
AS
RETURN
    SELECT p.IdPartido,
           pa.CodigoIso3,
           pa.Nombre AS Mercado,
           pa.HusoHorario,
           p.FechaHoraUtc,
           Publicidad.fn_HoraLocalMercado(p.FechaHoraUtc, pa.HusoHorario)                    AS HoraLocalMercado,
           Publicidad.fn_EsPrimeTime(p.FechaHoraUtc, pa.HusoHorario, @HoraDesde, @HoraHasta) AS EsPrimeTime
    FROM Torneo.Partido p
    CROSS JOIN Torneo.Pais pa
    WHERE p.IdPartido = @IdPartido;
GO

/*------------------------------------------------------------------------------
 Publicidad.fn_TarifaVigente
 Tarifa de una fase vigente en una fecha. Las vigencias de una misma fase no se
 superponen (lo valida el ABM), asi que hay como maximo una. NULL si no hay.
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Publicidad.fn_TarifaVigente (@Fase VARCHAR(20), @Fecha DATE)
RETURNS INT
AS
BEGIN
    RETURN (SELECT IdTarifa
            FROM Publicidad.TarifaPublicitaria
            WHERE Fase = @Fase
              AND @Fecha BETWEEN VigenteDesde AND VigenteHasta);
END
GO

/*------------------------------------------------------------------------------
 Publicidad.fn_CandidatasPartido
 Piezas que pueden ocupar los espacios de un partido, ordenadas por Posicion
 (las 4 primeras son las que se proponen). Compiten las piezas de campanias
 vigentes el dia del partido.

 Criterios de la consigna, con estos pesos (puntaje de 0 a 100):
   50 puntos  la pieza apunta a uno de los dos paises que juegan el partido.
   30 puntos  poder adquisitivo: el mayor PIB per capita entre sus paises de
              interes, en proporcion al mayor PIB de todas las candidatas.
   20 puntos  el partido cae en prime time en alguno de sus paises de interes.
 Cada anunciante ocupa como maximo @MaxPiezasPorAnunciante espacios (por
 defecto 1), para que un solo anunciante no se quede con los 4.

 Pasos:
   Criterios  un renglon por pieza con sus tres criterios.
   Puntajes   el puntaje de cada pieza.
   Ranking    el orden de cada pieza dentro de su anunciante.
 Ejemplo: SELECT * FROM Publicidad.fn_CandidatasPartido(@IdPartido, DEFAULT)
------------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION Publicidad.fn_CandidatasPartido (@IdPartido INT, @MaxPiezasPorAnunciante INT = 1)
RETURNS TABLE
AS
RETURN
    WITH Criterios AS (
        SELECT pz.IdPieza,
               c.IdAnunciante,
               MAX(CASE WHEN pp.IdPais IN (sl.IdPais, sv.IdPais) THEN 1 ELSE 0 END) AS EsPaisDelPartido,
               MAX(ISNULL(pa.PibPerCapitaUsd, 0))                                     AS PibMaximo,
               MAX(CAST(Publicidad.fn_EsPrimeTime(p.FechaHoraUtc, pa.HusoHorario, DEFAULT, DEFAULT) AS INT)) AS EnPrimeTime
        FROM Torneo.Partido p
        JOIN Torneo.Seleccion sl     ON sl.IdSeleccion = p.IdSeleccionLocal
        JOIN Torneo.Seleccion sv     ON sv.IdSeleccion = p.IdSeleccionVisitante
        JOIN Publicidad.Campania c   ON CAST(p.FechaHoraUtc AS DATE) BETWEEN c.FechaInicio AND c.FechaFin
        JOIN Publicidad.Pieza pz     ON pz.IdCampania = c.IdCampania
        JOIN Publicidad.PiezaPais pp ON pp.IdPieza = pz.IdPieza
        JOIN Torneo.Pais pa          ON pa.IdPais = pp.IdPais
        WHERE p.IdPartido = @IdPartido
        GROUP BY pz.IdPieza, c.IdAnunciante
    ),
    Puntajes AS (
        SELECT *,
               CAST(50 * EsPaisDelPartido
                    + ISNULL(30 * PibMaximo / NULLIF(MAX(PibMaximo) OVER (), 0), 0)
                    + 20 * EnPrimeTime AS DECIMAL(9, 2)) AS Puntaje
        FROM Criterios
    ),
    Ranking AS (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY IdAnunciante ORDER BY Puntaje DESC, IdPieza) AS OrdenEnAnunciante
        FROM Puntajes
    )
    SELECT IdPieza,
           IdAnunciante,
           EsPaisDelPartido,
           PibMaximo,
           EnPrimeTime,
           Puntaje,
           CASE WHEN EsPaisDelPartido = 1 THEN 'Pais del partido'
                WHEN EnPrimeTime = 1      THEN 'Prime time'
                ELSE 'Poder adquisitivo'
           END AS Criterio,
           ROW_NUMBER() OVER (ORDER BY Puntaje DESC, IdPieza) AS Posicion
    FROM Ranking
    WHERE OrdenEnAnunciante <= ISNULL(@MaxPiezasPorAnunciante, 1);
GO
