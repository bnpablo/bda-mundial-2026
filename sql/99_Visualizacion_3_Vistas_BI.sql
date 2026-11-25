/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-25
 Script       : 99_Visualizacion_3_Vistas_BI.sql
 Objetivo     : Entrega 9. Vistas del esquema Reportes que consume la plataforma de BI.
                Una plataforma de BI lee tablas o vistas, no procedimientos que
                devuelven varios resultados, asi que cada vista expone los mismos
                datos que un reporte de la Entrega 7 en una sola tabla:
                  Reportes.vw_Goleadores              goleadores del torneo
                  Reportes.vw_TarjetasPorSeleccion    tarjetas de cada seleccion
                  Reportes.vw_IngresosPorSede         ingresos publicitarios por sede
                  Reportes.vw_Sedes                   sedes con su ubicacion (mapa)
                Las vistas se apoyan en las funciones de la Entrega 5 o repiten el
                criterio del reporte correspondiente. Se pueden ejecutar mas de
                una vez.
 Requisito    : ejecutar despues de 99_Visualizacion_1_Geolocalizacion_Sedes.sql.
==============================================================================*/
USE MundialDB;
GO

/*------------------------------------------------------------------------------
 Reportes.vw_Goleadores
 Una fila por jugador con goles. Mismo criterio que Incidencia.fn_TablaGoleadores
 y Reportes.usp_ReportarGoleadores: no cuentan los goles en contra ni los de la
 definicion por penales.
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW Reportes.vw_Goleadores
AS
    SELECT Apellido + ', ' + Nombre AS Jugador, Pais AS Seleccion, Goles, GolesDePenal
    FROM Incidencia.fn_TablaGoleadores(NULL);
GO

/*------------------------------------------------------------------------------
 Reportes.vw_TarjetasPorSeleccion
 Amarillas y rojas de cada seleccion (jugadores y cuerpo tecnico), en 0 si no
 tiene. Es el primer resultado de Reportes.usp_ReportarTarjetas.
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW Reportes.vw_TarjetasPorSeleccion
AS
    SELECT Pais AS Seleccion, Amarillas, RojasDirectas, RojasPorDobleAmarilla
    FROM Incidencia.fn_TarjetasPorSeleccion();
GO

/*------------------------------------------------------------------------------
 Reportes.vw_IngresosPorSede
 Solo cuentan los espacios en estado Exhibida. Es el segundo resultado de
 Reportes.usp_ReportarOcupacionPublicitaria: partidos con publicidad, espacios
 exhibidos e ingresos de cada sede.
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW Reportes.vw_IngresosPorSede
AS
    SELECT se.NombreEstadio AS Sede, se.Ciudad,
           COUNT(DISTINCT pp.IdPartido) AS Partidos,
           COUNT(*)                     AS Espacios,
           SUM(tf.Monto)                AS Ingresos,
           tf.Moneda
    FROM Publicidad.PublicidadPartido pp
    JOIN Torneo.Partido p                 ON p.IdPartido = pp.IdPartido
    JOIN Torneo.Sede se                   ON se.IdSede = p.IdSede
    JOIN Publicidad.TarifaPublicitaria tf ON tf.IdTarifa = pp.IdTarifa
    WHERE pp.Estado = 'Exhibida'
    GROUP BY se.NombreEstadio, se.Ciudad, tf.Moneda;
GO

/*------------------------------------------------------------------------------
 Reportes.vw_Sedes
 Una fila por sede con su ubicacion, la capacidad y la cantidad de partidos, para
 mostrarlas en un mapa. Las sedes sin coordenadas tienen Latitud y Longitud NULL.
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW Reportes.vw_Sedes
AS
    SELECT se.NombreEstadio AS Sede, se.Ciudad, pa.Nombre AS Pais, se.Capacidad,
           se.Latitud, se.Longitud,
           (SELECT COUNT(*) FROM Torneo.Partido p WHERE p.IdSede = se.IdSede) AS Partidos
    FROM Torneo.Sede se
    JOIN Torneo.Pais pa ON pa.IdPais = se.IdPais;
GO
