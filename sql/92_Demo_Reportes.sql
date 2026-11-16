/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-15
 Script       : 92_Demo_Reportes.sql
 Objetivo     : Demostracion de los reportes de 89_SP_Reportes.sql sobre los datos
                cargados en la base:
                  Paso 0  los datos sobre los que salen los reportes
                  Paso 1  goleadores por seleccion, fase y torneo
                  Paso 2  tarjetas por seleccion y jugador, con suspensiones
                  Paso 3  designaciones arbitrales (XML)
                  Paso 4  ocupacion publicitaria por sede y partido
                  Paso 5  matriz de prime time (19 a 23 hora local)
                  Paso 6  matriz de prime time con otra franja (12 a 14)
                  Paso 7  selecciones y plantillas (XML)
                  Paso 8  resultados de los encuentros
                  Paso 9  resultados de una fase (la final)
                Cada paso es un lote aparte, con un EXEC y sin variables: se puede
                ejecutar el script entero o seleccionar un paso y ejecutarlo solo.
                Solo lee datos: no crea ni modifica nada, asi que se puede repetir.
                En la instalacion completa corre antes de 93 a 99 y muestra los
                datos que cargaron los tests. Para ver el torneo completo, ejecutarlo
                despues de 99_Datos_Aceptacion.sql. Los resultados esperados de
                cada paso son los de la base completa.
 Requisito    : ejecutar despues de 89_SP_Reportes.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;
GO

PRINT '=== Paso 0: los datos sobre los que salen los reportes ===';
-- Resultado esperado: Selecciones 25, Convocados 485, Partidos 47, Jugados 37, Goles 86, Tarjetas 38,
-- ArbitrosDesignados 22 y EspaciosExhibidos 134.
SELECT (SELECT COUNT(*) FROM Torneo.Seleccion)                                      AS Selecciones,
       (SELECT COUNT(*) FROM Torneo.Jugador WHERE FechaBaja IS NULL)                 AS Convocados,
       (SELECT COUNT(*) FROM Torneo.Partido)                                         AS Partidos,
       (SELECT COUNT(*) FROM Torneo.Partido WHERE Estado = 'Finalizado')             AS Jugados,
       (SELECT COUNT(*) FROM Incidencia.Gol)                                         AS Goles,
       (SELECT COUNT(*) FROM Incidencia.Tarjeta)                                     AS Tarjetas,
       (SELECT COUNT(DISTINCT IdArbitro) FROM Arbitraje.DesignacionArbitral)         AS ArbitrosDesignados,
       (SELECT COUNT(*) FROM Publicidad.PublicidadPartido WHERE Estado = 'Exhibida') AS EspaciosExhibidos;
GO

PRINT '=== Paso 1: goleadores por seleccion, fase y torneo ===';
-- Resultado esperado: 30 goleadores. En el puesto 1, con 6 goles, Alemania 07, Austria 07 y Suiza 07; despues Belgica 07
-- con 5. Cada fila tiene los goles de cada fase y el total.
EXEC Reportes.usp_ReportarGoleadores;
GO

PRINT '=== Paso 2: tarjetas por seleccion y jugador ===';
-- Resultado esperado: dos resultados. El primero, una fila por seleccion (25, tambien las que no tienen tarjetas), con
-- Uruguay arriba: 9 amarillas y 1 roja por doble amarilla. El segundo, los 19 jugadores con tarjetas y su situacion para el
-- proximo partido: 15 sin partidos pendientes y 4 habilitados.
EXEC Reportes.usp_ReportarTarjetas;
GO

PRINT '=== Paso 3: designaciones arbitrales (XML) ===';
-- Resultado esperado: un XML con 22 arbitros, sus 175 designaciones y las 29 tarjetas de los partidos donde fueron
-- Principal. En la grilla sale como un enlace: un clic lo abre en otra pestania.
EXEC Reportes.usp_ReportarDesignaciones;
GO

PRINT '=== Paso 4: ocupacion publicitaria por sede y partido ===';
-- Resultado esperado: dos resultados. El primero, los 34 partidos con publicidad exhibida, con el anunciante de cada
-- espacio y el ingreso del partido. En el 233, Argentina - Brasil, tres de los cuatro espacios son campanias importadas
-- de dossiermundial (Pax Assistance, Quilmes y DSports). El segundo, las 9 sedes, con Levis Stadium arriba: 4 partidos, 16 espacios y
-- 1460000.00 USD.
EXEC Reportes.usp_ReportarOcupacionPublicitaria;
GO

PRINT '=== Paso 5: matriz de prime time ===';
-- Resultado esperado: una fila por partido (47) y una columna por pais (31). Por ejemplo, el 203 (23:00 UTC) esta en
-- prime time en ARG, BRA, CAN, PRY, URY y USA.
EXEC Reportes.usp_ReportarMatrizPrimeTime;
GO

PRINT '=== Paso 6: matriz de prime time con otra franja ===';
-- Resultado esperado: los mismos 47 partidos, con otros valores: el 201 (17:00 UTC) pasa a estar en prime time en
-- CAN, COL, ECU, PAN y USA.
EXEC Reportes.usp_ReportarMatrizPrimeTime @HoraDesde = 12, @HoraHasta = 14;
GO

PRINT '=== Paso 7: selecciones y plantillas (XML) ===';
-- Resultado esperado: un XML con las 25 selecciones y sus 485 convocados, ordenados por grupo y por dorsal.
EXEC Reportes.usp_ReportarPlantillas;
GO

PRINT '=== Paso 8: resultados de los encuentros ===';
-- Resultado esperado: dos resultados. La tabla de posiciones de las 25 selecciones, por grupo, y la lista de los 47
-- partidos con resultado, penales, ganador y goleadores.
EXEC Reportes.usp_ReportarResultados;
GO

PRINT '=== Paso 9: resultados de una fase ===';
-- Resultado esperado: la misma tabla de posiciones y un solo partido en la lista: la final, Alemania 2 - 1 Austria.
EXEC Reportes.usp_ReportarResultados @Fase = 'Final';
GO
