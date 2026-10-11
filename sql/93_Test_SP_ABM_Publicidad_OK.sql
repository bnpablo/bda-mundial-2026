/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 93_Test_SP_ABM_Publicidad_OK.sql
 Objetivo     : Testing exitoso de 92_SP_ABM_Publicidad.sql (relacion 1:1): alta,
                modificacion y baja de las 6 tablas de Publicidad. Deja cargados
                los datos que usan los tests 94, 96 y 97:
                  5 anunciantes, cada uno con la campania "Mundial 2026"
                  (01/06 al 31/07/2026) y sus piezas:
                    Bebidas del Sur     Spot Uruguay (URY) y Spot Colombia (COL)
                    Autos Europa        Spot Europa (ITA y NED)
                    Banco Andino        Spot Ecuador (ECU)
                    Telefonia Global    Spot Estados Unidos (USA)
                    Deportes del Norte  Spot Portugal (POR)
                  Tarifas: Grupos (junio, USD 55000) y Tercer puesto (julio, USD 80000).
 Requisito    : ejecutar despues de 92_SP_ABM_Publicidad.sql y de los tests 87 a 91
                (usa los paises y los partidos INC-P de esos tests). Una sola vez.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

DECLARE @PaisUry INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'URY');
DECLARE @PaisCol INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'COL');
DECLARE @PaisEcu INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ECU');
DECLARE @PaisIta INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'ITA');
DECLARE @PaisPor INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'POR');
DECLARE @PaisNed INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'NED');
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @IdP6 INT = (SELECT IdPartido FROM Torneo.Partido WHERE CodigoExterno = 'INC-P6');

DECLARE @AnBebidas INT, @AnAutos INT, @AnBanco INT, @AnTelefonia INT, @AnDeportes INT, @AnTemporal INT;
DECLARE @CaBebidas INT, @CaAutos INT, @CaBanco INT, @CaTelefonia INT, @CaDeportes INT, @CaTemporal INT;
DECLARE @PzUruguay INT, @PzColombia INT, @PzEuropa INT, @PzEcuador INT, @PzEstadosUnidos INT, @PzPortugal INT, @PzPrueba INT;
DECLARE @TaGrupos INT, @TaTercer INT, @TaFinal INT, @IdEspacio INT;

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes,
       (SELECT COUNT(*) FROM Publicidad.Pieza) AS Piezas;                    -- esperado: 0, 0

/*------------------------------------------------------------------------------
 ANUNCIANTE
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta, modificacion y baja de anunciantes ===';
-- Resultado esperado: se crean 6 anunciantes; "Deportes Norte" pasa a llamarse "Deportes del Norte" y
-- "Anunciante Temporal" se elimina. Quedan 5.
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Bebidas del Sur', @IdAnunciante = @AnBebidas OUTPUT;
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Autos Europa', @IdAnunciante = @AnAutos OUTPUT;
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Banco Andino', @IdAnunciante = @AnBanco OUTPUT;
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Telefonia Global', @IdAnunciante = @AnTelefonia OUTPUT;
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Deportes Norte', @IdAnunciante = @AnDeportes OUTPUT;
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Anunciante Temporal', @IdAnunciante = @AnTemporal OUTPUT;
SELECT 'Antes' AS Momento, IdAnunciante, Nombre FROM Publicidad.Anunciante ORDER BY IdAnunciante;
EXEC Publicidad.usp_Anunciante_Modificacion @IdAnunciante = @AnDeportes, @Nombre = 'Deportes del Norte';
EXEC Publicidad.usp_Anunciante_Baja @IdAnunciante = @AnTemporal;
SELECT 'Despues' AS Momento, IdAnunciante, Nombre FROM Publicidad.Anunciante ORDER BY IdAnunciante;

/*------------------------------------------------------------------------------
 CAMPANIA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 2: alta, modificacion y baja de campanias ===';
-- Resultado esperado: cada anunciante tiene la campania "Mundial 2026" (01/06 al 31/07/2026). La de Autos
-- Europa pasa a llamarse "Mundial 2026 Europa" y termina el 15/08. Una campania temporal de Bebidas del Sur
-- se crea y se elimina. Quedan 5 campanias.
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @AnBebidas, @Nombre = 'Mundial 2026', @FechaInicio = '2026-06-01',
     @FechaFin = '2026-07-31', @IdCampania = @CaBebidas OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @AnAutos, @Nombre = 'Mundial 2026', @FechaInicio = '2026-06-01',
     @FechaFin = '2026-07-31', @IdCampania = @CaAutos OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @AnBanco, @Nombre = 'Mundial 2026', @FechaInicio = '2026-06-01',
     @FechaFin = '2026-07-31', @IdCampania = @CaBanco OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @AnTelefonia, @Nombre = 'Mundial 2026', @FechaInicio = '2026-06-01',
     @FechaFin = '2026-07-31', @IdCampania = @CaTelefonia OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @AnDeportes, @Nombre = 'Mundial 2026', @FechaInicio = '2026-06-01',
     @FechaFin = '2026-07-31', @IdCampania = @CaDeportes OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @AnBebidas, @Nombre = 'Campania Temporal', @FechaInicio = '2026-06-01',
     @FechaFin = '2026-06-30', @IdCampania = @CaTemporal OUTPUT;
EXEC Publicidad.usp_Campania_Modificacion @IdCampania = @CaAutos, @Nombre = 'Mundial 2026 Europa',
     @FechaInicio = '2026-06-01', @FechaFin = '2026-08-15';
EXEC Publicidad.usp_Campania_Baja @IdCampania = @CaTemporal;
SELECT c.IdCampania, a.Nombre AS Anunciante, c.Nombre, c.FechaInicio, c.FechaFin
FROM Publicidad.Campania c JOIN Publicidad.Anunciante a ON a.IdAnunciante = c.IdAnunciante
ORDER BY c.IdCampania;

/*------------------------------------------------------------------------------
 PIEZA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 3: alta, modificacion y baja de piezas ===';
-- Resultado esperado: se crean 7 piezas. "Spot Europa" pasa de 20 a 25 segundos. "Spot Prueba" se elimina
-- (y con ella su pais de interes, por la clave foranea en cascada). Quedan 6 piezas.
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaBebidas, @Nombre = 'Spot Uruguay', @Idioma = 'es', @DuracionSegundos = 30,
     @IdPieza = @PzUruguay OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaBebidas, @Nombre = 'Spot Colombia', @Idioma = 'es', @DuracionSegundos = 30,
     @IdPieza = @PzColombia OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaAutos, @Nombre = 'Spot Europa', @Idioma = 'IT', @DuracionSegundos = 20,
     @IdPieza = @PzEuropa OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaBanco, @Nombre = 'Spot Ecuador', @Idioma = 'es', @DuracionSegundos = 30,
     @IdPieza = @PzEcuador OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaTelefonia, @Nombre = 'Spot Estados Unidos', @Idioma = 'en', @DuracionSegundos = 15,
     @IdPieza = @PzEstadosUnidos OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaDeportes, @Nombre = 'Spot Portugal', @Idioma = 'pt', @DuracionSegundos = 20,
     @IdPieza = @PzPortugal OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @CaTelefonia, @Nombre = 'Spot Prueba', @Idioma = 'en', @DuracionSegundos = 10,
     @IdPieza = @PzPrueba OUTPUT;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzPrueba, @IdPais = @PaisUsa;
EXEC Publicidad.usp_Pieza_Modificacion @IdPieza = @PzEuropa, @Nombre = 'Spot Europa', @Idioma = 'it', @DuracionSegundos = 25;
EXEC Publicidad.usp_Pieza_Baja @IdPieza = @PzPrueba;
SELECT IdPieza, IdCampania, Nombre, Idioma, DuracionSegundos FROM Publicidad.Pieza ORDER BY IdPieza;
SELECT COUNT(*) AS PaisesDeSpotPrueba FROM Publicidad.PiezaPais WHERE IdPieza = @PzPrueba;        -- esperado: 0

/*------------------------------------------------------------------------------
 PIEZA PAIS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 4: alta, modificacion y baja de paises de interes ===';
-- Resultado esperado: Spot Europa queda con ITA y NED (se le agrega USA y se le quita). Spot Portugal se carga
-- con ITA y se corrige a POR. Las demas piezas quedan con un pais cada una.
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzUruguay, @IdPais = @PaisUry;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzColombia, @IdPais = @PaisCol;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzEuropa, @IdPais = @PaisIta;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzEuropa, @IdPais = @PaisNed;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzEuropa, @IdPais = @PaisUsa;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzEcuador, @IdPais = @PaisEcu;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzEstadosUnidos, @IdPais = @PaisUsa;
EXEC Publicidad.usp_PiezaPais_Alta @IdPieza = @PzPortugal, @IdPais = @PaisIta;
EXEC Publicidad.usp_PiezaPais_Modificacion @IdPieza = @PzPortugal, @IdPais = @PaisIta, @IdPaisNuevo = @PaisPor;
EXEC Publicidad.usp_PiezaPais_Baja @IdPieza = @PzEuropa, @IdPais = @PaisUsa;
SELECT pz.Nombre AS Pieza, pa.CodigoIso3 AS Pais
FROM Publicidad.PiezaPais pp
JOIN Publicidad.Pieza pz ON pz.IdPieza = pp.IdPieza
JOIN Torneo.Pais pa ON pa.IdPais = pp.IdPais
ORDER BY pz.IdPieza, pa.CodigoIso3;

/*------------------------------------------------------------------------------
 TARIFA PUBLICITARIA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 5: alta, modificacion y baja de tarifas ===';
-- Resultado esperado: se crean las tarifas de Grupos (junio), Tercer puesto (julio) y Final (julio). La de
-- Grupos pasa de USD 50000 a 55000 (todavia no se uso) y la de Final se elimina. Quedan 2 tarifas.
EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = 'Grupos', @Moneda = 'usd', @Monto = 50000,
     @VigenteDesde = '2026-06-01', @VigenteHasta = '2026-06-30', @IdTarifa = @TaGrupos OUTPUT;
EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = 'Tercer puesto', @Moneda = 'USD', @Monto = 80000,
     @VigenteDesde = '2026-07-01', @VigenteHasta = '2026-07-31', @IdTarifa = @TaTercer OUTPUT;
EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = 'Final', @Moneda = 'USD', @Monto = 120000,
     @VigenteDesde = '2026-07-01', @VigenteHasta = '2026-07-31', @IdTarifa = @TaFinal OUTPUT;
EXEC Publicidad.usp_TarifaPublicitaria_Modificacion @IdTarifa = @TaGrupos, @Fase = 'Grupos', @Moneda = 'USD',
     @Monto = 55000, @VigenteDesde = '2026-06-01', @VigenteHasta = '2026-06-30';
EXEC Publicidad.usp_TarifaPublicitaria_Baja @IdTarifa = @TaFinal;
SELECT IdTarifa, Fase, Moneda, Monto, VigenteDesde, VigenteHasta FROM Publicidad.TarifaPublicitaria ORDER BY IdTarifa;

/*------------------------------------------------------------------------------
 PUBLICIDAD PARTIDO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 6: alta manual, modificacion y baja de un espacio ===';
-- Resultado esperado: en INC-P6 (Tercer puesto, 18/07) se vende el espacio 1 a Spot Estados Unidos: queda
-- Confirmada, criterio Manual y la tarifa de Tercer puesto. Despues se pasa al espacio 2 y se elimina.
EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @IdP6, @NumeroEspacio = 1, @IdPieza = @PzEstadosUnidos,
     @IdPublicidadPartido = @IdEspacio OUTPUT;
SELECT 'Alta' AS Paso, IdPublicidadPartido, NumeroEspacio, IdPieza, IdTarifa, Criterio, Estado
FROM Publicidad.PublicidadPartido WHERE IdPublicidadPartido = @IdEspacio;
EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @IdEspacio, @NumeroEspacio = 2, @Estado = 'Confirmada';
SELECT 'Modificacion' AS Paso, IdPublicidadPartido, NumeroEspacio, IdPieza, IdTarifa, Criterio, Estado
FROM Publicidad.PublicidadPartido WHERE IdPublicidadPartido = @IdEspacio;
EXEC Publicidad.usp_PublicidadPartido_Baja @IdPublicidadPartido = @IdEspacio;
SELECT COUNT(*) AS EspaciosEnP6 FROM Publicidad.PublicidadPartido WHERE IdPartido = @IdP6;          -- esperado: 0

SELECT (SELECT COUNT(*) FROM Publicidad.Anunciante) AS Anunciantes, (SELECT COUNT(*) FROM Publicidad.Campania) AS Campanias,
       (SELECT COUNT(*) FROM Publicidad.Pieza) AS Piezas, (SELECT COUNT(*) FROM Publicidad.TarifaPublicitaria) AS Tarifas;
-- esperado: 5, 5, 6, 2
GO
