/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 96_Test_SP_Negocio_Publicidad_OK.sql
 Objetivo     : Testing exitoso de 95_SP_Negocio_Publicidad.sql (relacion 1:1) y de las
                funciones de 07_Funciones_Publicidad.sql. Recorre el ciclo completo
                en INC-P2 (Ecuador - Uruguay, grupos, 19/06/2026 18:00 UTC):
                simulacion de prime time, propuesta de las 4 piezas, venta de dos
                espacios, fin del partido y registro de la exhibicion.
 Requisito    : ejecutar despues de 94_Test_SP_ABM_Publicidad_Validaciones.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

/*------------------------------------------------------------------------------
 PREPARACION DE DATOS
 Se carga el PIB per capita de los mercados con el SP de Pablo (modificacion
 completa: se reenvian los demas datos del pais como estan). Colombia y
 Ecuador quedan sin PIB.
------------------------------------------------------------------------------*/
DECLARE @IdPais INT, @Codigo CHAR(3), @Nombre VARCHAR(80), @Confederacion VARCHAR(10), @Huso VARCHAR(60);

SELECT @IdPais = IdPais, @Codigo = CodigoIso3, @Nombre = Nombre, @Confederacion = Confederacion, @Huso = HusoHorario
FROM Torneo.Pais WHERE CodigoIso3 = 'URY';
EXEC Torneo.usp_Pais_Modificacion @IdPais = @IdPais, @CodigoIso3 = @Codigo, @Nombre = @Nombre, @Confederacion = @Confederacion,
     @HusoHorario = @Huso, @PibPerCapitaUsd = 23000, @AnioPib = 2024;

SELECT @IdPais = IdPais, @Codigo = CodigoIso3, @Nombre = Nombre, @Confederacion = Confederacion, @Huso = HusoHorario
FROM Torneo.Pais WHERE CodigoIso3 = 'ITA';
EXEC Torneo.usp_Pais_Modificacion @IdPais = @IdPais, @CodigoIso3 = @Codigo, @Nombre = @Nombre, @Confederacion = @Confederacion,
     @HusoHorario = @Huso, @PibPerCapitaUsd = 39000, @AnioPib = 2024;

SELECT @IdPais = IdPais, @Codigo = CodigoIso3, @Nombre = Nombre, @Confederacion = Confederacion, @Huso = HusoHorario
FROM Torneo.Pais WHERE CodigoIso3 = 'POR';
EXEC Torneo.usp_Pais_Modificacion @IdPais = @IdPais, @CodigoIso3 = @Codigo, @Nombre = @Nombre, @Confederacion = @Confederacion,
     @HusoHorario = @Huso, @PibPerCapitaUsd = 28000, @AnioPib = 2024;

SELECT @IdPais = IdPais, @Codigo = CodigoIso3, @Nombre = Nombre, @Confederacion = Confederacion, @Huso = HusoHorario
FROM Torneo.Pais WHERE CodigoIso3 = 'NED';
EXEC Torneo.usp_Pais_Modificacion @IdPais = @IdPais, @CodigoIso3 = @Codigo, @Nombre = @Nombre, @Confederacion = @Confederacion,
     @HusoHorario = @Huso, @PibPerCapitaUsd = 64000, @AnioPib = 2024;

SELECT @IdPais = IdPais, @Codigo = CodigoIso3, @Nombre = Nombre, @Confederacion = Confederacion, @Huso = HusoHorario
FROM Torneo.Pais WHERE CodigoIso3 = 'USA';
EXEC Torneo.usp_Pais_Modificacion @IdPais = @IdPais, @CodigoIso3 = @Codigo, @Nombre = @Nombre, @Confederacion = @Confederacion,
     @HusoHorario = @Huso, @PibPerCapitaUsd = 85000, @AnioPib = 2024;

SELECT CodigoIso3, HusoHorario, PibPerCapitaUsd FROM Torneo.Pais
WHERE CodigoIso3 IN ('URY', 'COL', 'ECU', 'ITA', 'POR', 'NED', 'USA') ORDER BY CodigoIso3;

DECLARE @IdP2 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P2');
DECLARE @Asignados INT, @Exhibidas INT, @Descartadas INT;
DECLARE @Espacio1 INT, @Espacio2 INT;

/*------------------------------------------------------------------------------
 FUNCIONES
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: simulacion de prime time del partido ===';
-- Resultado esperado: una fila por pais con la hora local del partido (19/06, 18:00 UTC). Entre otros:
-- Italia y Paises Bajos 20:00 y Portugal 19:00 estan en prime time (1); Uruguay 15:00, Colombia y Ecuador
-- 13:00 no (0).
SELECT * FROM Publicidad.fn_SimularPrimeTime(@IdP2, DEFAULT, DEFAULT) ORDER BY EsPrimeTime DESC, CodigoIso3;

PRINT '=== Prueba 2: piezas candidatas y su puntaje ===';
-- Resultado esperado (5 filas, una por anunciante; el PIB maximo entre las candidatas es 85000):
--   1 Spot Uruguay         58.12  Pais del partido   (50 + 30 * 23000 / 85000)
--   2 Spot Ecuador         50.00  Pais del partido   (50, Ecuador sin PIB)
--   3 Spot Europa          42.59  Prime time         (30 * 64000 / 85000 + 20)
--   4 Spot Estados Unidos  30.00  Poder adquisitivo  (30 * 85000 / 85000)
--   5 Spot Portugal        29.88  Prime time         (30 * 28000 / 85000 + 20)
-- Spot Colombia no aparece: es la segunda pieza de Bebidas del Sur (maximo 1 por anunciante).
SELECT c.Posicion, pz.Nombre AS Pieza, a.Nombre AS Anunciante, c.EsPaisDelPartido, c.PibMaximo, c.EnPrimeTime,
       c.Puntaje, c.Criterio
FROM Publicidad.fn_CandidatasPartido(@IdP2, DEFAULT) c
JOIN Publicidad.Pieza pz ON pz.IdPieza = c.IdPieza
JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
ORDER BY c.Posicion;

PRINT '=== Prueba 3: con 2 piezas por anunciante ===';
-- Resultado esperado: aparece tambien Spot Colombia, en la posicion 6 con puntaje 0.00.
SELECT c.Posicion, pz.Nombre AS Pieza, c.Puntaje
FROM Publicidad.fn_CandidatasPartido(@IdP2, 2) c
JOIN Publicidad.Pieza pz ON pz.IdPieza = c.IdPieza
ORDER BY c.Posicion;

/*------------------------------------------------------------------------------
 ASIGNACION DE LAS 4 PIEZAS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 4: propuesta automatica de las 4 piezas ===';
-- Resultado esperado: EspaciosAsignados = 4. Los espacios 1 a 4 quedan en Propuesta con Spot Uruguay, Spot
-- Ecuador, Spot Europa y Spot Estados Unidos, la tarifa de Grupos, su criterio y su puntaje.
EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = @IdP2, @EspaciosAsignados = @Asignados OUTPUT;
SELECT @Asignados AS EspaciosAsignados;
SELECT pp.NumeroEspacio, pz.Nombre AS Pieza, t.Fase, t.Monto, pp.Criterio, pp.Puntaje, pp.Estado
FROM Publicidad.PublicidadPartido pp
JOIN Publicidad.Pieza pz ON pz.IdPieza = pp.IdPieza
JOIN Publicidad.TarifaPublicitaria t ON t.IdTarifa = pp.IdTarifa
WHERE pp.IdPartido = @IdP2
ORDER BY pp.NumeroEspacio;

PRINT '=== Prueba 5: recalcular la propuesta ===';
-- Resultado esperado: la propuesta anterior se reemplaza; siguen siendo 4 filas en Propuesta (no 8).
EXEC Publicidad.usp_AsignarPiezasPartido @IdPartido = @IdP2, @EspaciosAsignados = @Asignados OUTPUT;
SELECT @Asignados AS EspaciosAsignados, COUNT(*) AS FilasDelPartido
FROM Publicidad.PublicidadPartido WHERE IdPartido = @IdP2;

/*------------------------------------------------------------------------------
 VENTA, FIN DEL PARTIDO Y EXHIBICION
------------------------------------------------------------------------------*/
PRINT '=== Prueba 6: registro de la exhibicion ===';
-- Resultado esperado: se venden los espacios 1 y 2 (Propuesta -> Confirmada, con el ABM). El partido se
-- finaliza con el SP de Pablo. Al registrar la exhibicion: Exhibidas = 2 (espacios 1 y 2) y Descartadas = 2
-- (espacios 3 y 4, que no se vendieron). Ingresos del partido: 2 x 55000 = USD 110000.
SET @Espacio1 = (SELECT IdPublicidadPartido FROM Publicidad.PublicidadPartido WHERE IdPartido = @IdP2 AND NumeroEspacio = 1);
SET @Espacio2 = (SELECT IdPublicidadPartido FROM Publicidad.PublicidadPartido WHERE IdPartido = @IdP2 AND NumeroEspacio = 2);
EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @Espacio1, @NumeroEspacio = 1, @Estado = 'Confirmada';
EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @Espacio2, @NumeroEspacio = 2, @Estado = 'Confirmada';
EXEC Torneo.usp_FinalizarPartido @IdPartido = @IdP2, @Asistencia = 60000;
EXEC Publicidad.usp_RegistrarExhibicion @IdPartido = @IdP2, @Exhibidas = @Exhibidas OUTPUT, @Descartadas = @Descartadas OUTPUT;
SELECT @Exhibidas AS Exhibidas, @Descartadas AS Descartadas;
SELECT pp.NumeroEspacio, pz.Nombre AS Pieza, pp.Estado
FROM Publicidad.PublicidadPartido pp JOIN Publicidad.Pieza pz ON pz.IdPieza = pp.IdPieza
WHERE pp.IdPartido = @IdP2
ORDER BY pp.NumeroEspacio;
SELECT t.Moneda, SUM(t.Monto) AS Ingresos
FROM Publicidad.PublicidadPartido pp JOIN Publicidad.TarifaPublicitaria t ON t.IdTarifa = pp.IdTarifa
WHERE pp.IdPartido = @IdP2 AND pp.Estado = 'Exhibida'
GROUP BY t.Moneda;
GO
