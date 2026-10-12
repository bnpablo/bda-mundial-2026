/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 51_Test_SP_ABM_Arbitraje_OK.sql
 Objetivo     : Testing exitoso de 50_SP_ABM_Arbitraje.sql (relacion 1:1).
                Primero prepara, solo con los SP de alta de Torneo, los datos que usan
                los tests de Arbitraje e Incidencia (51, 52, 77 y 78):
                  - Paises URY, COL, ECU (selecciones del grupo H), ITA, POR y NED
                    (arbitros) y USA (sede) si todavia no existe.
                  - Sede SEDE-TEST-INC (capacidad 72000).
                  - Selecciones URY, COL y ECU con 23 jugadores cada una (URY-01 a
                    URY-23, etc.) y director tecnico de URY y de COL.
                  - Partidos INC-P0 a INC-P6 (numeros 101 a 107):
                      INC-P0 Grupos         COL - ECU  (se juega y finaliza en este test)
                      INC-P1 Grupos         URY - COL
                      INC-P2 Grupos         ECU - URY
                      INC-P3 Dieciseisavos  URY - COL
                      INC-P4 Octavos        ECU - URY
                      INC-P5 Cuartos        URY - ECU
                      INC-P6 Tercer puesto  COL - ECU  (queda Programado)
 Requisito    : ejecutar despues de 50_SP_ABM_Arbitraje.sql y de 40_SP_Negocio_Partidos.sql
                (la prueba 6 inicia y finaliza INC-P0 con Torneo.usp_IniciarPartido y
                Torneo.usp_FinalizarPartido). Los datos de prueba usan codigos propios
                (INC-, SEDE-TEST-INC, URY-nn, COL-nn, ECU-nn), asi que no dependen de
                lo que carguen los tests de Torneo ni de Formacion. Una sola vez.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

/*------------------------------------------------------------------------------
 PREPARACION DE DATOS
------------------------------------------------------------------------------*/
DECLARE @PaisUry INT, @PaisCol INT, @PaisEcu INT, @PaisIta INT, @PaisPor INT, @PaisNed INT;
DECLARE @PaisUsa INT = (SELECT IdPais FROM Torneo.Pais WHERE CodigoIso3 = 'USA');
DECLARE @IdSede INT, @SelUry INT, @SelCol INT, @SelEcu INT, @IdDt INT;
DECLARE @IdP0 INT, @IdP1 INT, @IdP2 INT, @IdP3 INT, @IdP4 INT, @IdP5 INT, @IdP6 INT;

EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'URY', @Nombre = 'Uruguay', @Confederacion = 'CONMEBOL',
     @HusoHorario = 'Montevideo Standard Time', @IdPais = @PaisUry OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'COL', @Nombre = 'Colombia', @Confederacion = 'CONMEBOL',
     @HusoHorario = 'SA Pacific Standard Time', @IdPais = @PaisCol OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'ECU', @Nombre = 'Ecuador', @Confederacion = 'CONMEBOL',
     @HusoHorario = 'SA Pacific Standard Time', @IdPais = @PaisEcu OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'ITA', @Nombre = 'Italia', @Confederacion = 'UEFA',
     @HusoHorario = 'W. Europe Standard Time', @IdPais = @PaisIta OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'POR', @Nombre = 'Portugal', @Confederacion = 'UEFA',
     @HusoHorario = 'GMT Standard Time', @IdPais = @PaisPor OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'NED', @Nombre = 'Paises Bajos', @Confederacion = 'UEFA',
     @HusoHorario = 'W. Europe Standard Time', @IdPais = @PaisNed OUTPUT;

-- Estados Unidos lo crea 11_Test_SP_ABM_Torneo_OK.sql; si no se ejecuto, se crea aca.
IF @PaisUsa IS NULL
    EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'USA', @Nombre = 'Estados Unidos', @Confederacion = 'CONCACAF',
         @HusoHorario = 'Eastern Standard Time', @IdPais = @PaisUsa OUTPUT;

EXEC Torneo.usp_Sede_Alta @CodigoExterno = 'SEDE-TEST-INC', @NombreEstadio = 'Estadio de Prueba Incidencias',
     @Ciudad = 'Houston', @IdPais = @PaisUsa, @HusoHorario = 'Central Standard Time', @Capacidad = 72000,
     @IdSede = @IdSede OUTPUT;

EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = 'SEL-URY', @IdPais = @PaisUry, @Grupo = 'H', @IdSeleccion = @SelUry OUTPUT;
EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = 'SEL-COL', @IdPais = @PaisCol, @Grupo = 'H', @IdSeleccion = @SelCol OUTPUT;
EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = 'SEL-ECU', @IdPais = @PaisEcu, @Grupo = 'H', @IdSeleccion = @SelEcu OUTPUT;

-- 23 jugadores por seleccion (el minimo para iniciar un partido). Dorsal 1 arquero,
-- 2 a 8 defensores, 9 a 16 mediocampistas y 17 a 23 delanteros.
DECLARE @i INT = 1, @numero VARCHAR(2), @posicion VARCHAR(5);
DECLARE @codigo VARCHAR(30), @apellido VARCHAR(80);

WHILE @i <= 23
BEGIN
    SET @numero = RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    SET @posicion = CASE WHEN @i = 1 THEN 'POR' WHEN @i <= 8 THEN 'DEF' WHEN @i <= 16 THEN 'MED' ELSE 'DEL' END;

    SET @codigo = 'URY-' + @numero;
    SET @apellido = 'Uruguay ' + @numero;
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @codigo, @Nombre = 'Jugador', @Apellido = @apellido,
         @IdPais = @PaisUry, @IdSeleccion = @SelUry, @Dorsal = @i, @PosicionHabitual = @posicion,
         @ClubOrigen = 'Club de Prueba', @FechaAlta = '2026-06-01';

    SET @codigo = 'COL-' + @numero;
    SET @apellido = 'Colombia ' + @numero;
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @codigo, @Nombre = 'Jugador', @Apellido = @apellido,
         @IdPais = @PaisCol, @IdSeleccion = @SelCol, @Dorsal = @i, @PosicionHabitual = @posicion,
         @ClubOrigen = 'Club de Prueba', @FechaAlta = '2026-06-01';

    SET @codigo = 'ECU-' + @numero;
    SET @apellido = 'Ecuador ' + @numero;
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @codigo, @Nombre = 'Jugador', @Apellido = @apellido,
         @IdPais = @PaisEcu, @IdSeleccion = @SelEcu, @Dorsal = @i, @PosicionHabitual = @posicion,
         @ClubOrigen = 'Club de Prueba', @FechaAlta = '2026-06-01';

    SET @i += 1;
END;

EXEC Torneo.usp_CuerpoTecnico_Alta @IdSeleccion = @SelUry, @Nombre = 'Tecnico', @Apellido = 'Uruguay',
     @Rol = 'Director tecnico', @IdCuerpoTecnico = @IdDt OUTPUT;
EXEC Torneo.usp_CuerpoTecnico_Alta @IdSeleccion = @SelCol, @Nombre = 'Tecnico', @Apellido = 'Colombia',
     @Rol = 'Director tecnico', @IdCuerpoTecnico = @IdDt OUTPUT;

EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P0', @NumeroPartido = 101, @Fase = 'Grupos', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-06-11 18:00', @IdSeleccionLocal = @SelCol, @IdSeleccionVisitante = @SelEcu, @IdPartido = @IdP0 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P1', @NumeroPartido = 102, @Fase = 'Grupos', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-06-14 18:00', @IdSeleccionLocal = @SelUry, @IdSeleccionVisitante = @SelCol, @IdPartido = @IdP1 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P2', @NumeroPartido = 103, @Fase = 'Grupos', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-06-19 18:00', @IdSeleccionLocal = @SelEcu, @IdSeleccionVisitante = @SelUry, @IdPartido = @IdP2 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P3', @NumeroPartido = 104, @Fase = 'Dieciseisavos', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-06-29 18:00', @IdSeleccionLocal = @SelUry, @IdSeleccionVisitante = @SelCol, @IdPartido = @IdP3 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P4', @NumeroPartido = 105, @Fase = 'Octavos', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-07-04 18:00', @IdSeleccionLocal = @SelEcu, @IdSeleccionVisitante = @SelUry, @IdPartido = @IdP4 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P5', @NumeroPartido = 106, @Fase = 'Cuartos', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-07-10 18:00', @IdSeleccionLocal = @SelUry, @IdSeleccionVisitante = @SelEcu, @IdPartido = @IdP5 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'INC-P6', @NumeroPartido = 107, @Fase = 'Tercer puesto', @IdSede = @IdSede,
     @FechaHoraUtc = '2026-07-18 18:00', @IdSeleccionLocal = @SelCol, @IdSeleccionVisitante = @SelEcu, @IdPartido = @IdP6 OUTPUT;

-- Resultado esperado: 23 jugadores por seleccion y 7 partidos Programados.
SELECT s.CodigoExterno AS Seleccion, COUNT(j.IdJugador) AS Jugadores
FROM Torneo.Seleccion s LEFT JOIN Torneo.Jugador j ON j.IdSeleccion = s.IdSeleccion
WHERE s.CodigoExterno IN ('SEL-URY', 'SEL-COL', 'SEL-ECU')
GROUP BY s.CodigoExterno;
SELECT CodigoExterno, NumeroPartido, Fase, FechaHoraUtc, FechaHoraLocal, Estado
FROM Torneo.Partido WHERE CodigoExterno LIKE 'INC-P%' ORDER BY NumeroPartido;

DECLARE @ArbIta INT, @ArbPor INT, @ArbUry INT, @ArbNed INT;
DECLARE @DesigItaP1 INT, @DesigPorP1 INT, @DesigNedP1 INT, @DesigPorP0 INT, @DesigItaP0 INT;

/*------------------------------------------------------------------------------
 ARBITRO
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: alta de arbitros ===';
-- Resultado esperado: se crean 4 arbitros: Rossi (Italia, FIFA), Silva (Portugal, FIFA), Cunha (Uruguay,
-- Confederacion) y Kuipers (Paises Bajos, FIFA). Cunha se usa en los tests de conflicto de nacionalidad.
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-ITA', @Nombre = 'Marco', @Apellido = 'Rossi', @IdPais = @PaisIta,
     @Categoria = 'FIFA', @FechaNacimiento = '1985-03-10', @IdArbitro = @ArbIta OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-POR', @Nombre = 'Joao', @Apellido = 'Silva', @IdPais = @PaisPor,
     @Categoria = 'FIFA', @IdArbitro = @ArbPor OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-URY', @Nombre = 'Andres', @Apellido = 'Cunha', @IdPais = @PaisUry,
     @Categoria = 'Confederacion', @FechaNacimiento = '1976-09-08', @IdArbitro = @ArbUry OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-NED', @Nombre = 'Danny', @Apellido = 'Kuipers', @IdPais = @PaisNed,
     @Categoria = 'FIFA', @IdArbitro = @ArbNed OUTPUT;
SELECT a.IdArbitro, a.CodigoExterno, a.Nombre, a.Apellido, a.FechaNacimiento, p.CodigoIso3 AS Pais, a.Categoria
FROM Arbitraje.Arbitro a JOIN Torneo.Pais p ON p.IdPais = a.IdPais
WHERE a.CodigoExterno LIKE 'ARB-%';

PRINT '=== Prueba 2: modificacion completa de un arbitro ===';
-- Resultado esperado: Silva pasa a categoria Confederacion y queda cargada su fecha de nacimiento. Como la
-- modificacion es completa, se envian todos los datos (los que no cambian, con el mismo valor).
SELECT 'Antes' AS Momento, IdArbitro, CodigoExterno, Nombre, Apellido, FechaNacimiento, Categoria
FROM Arbitraje.Arbitro WHERE IdArbitro = @ArbPor;
EXEC Arbitraje.usp_Arbitro_Modificacion @IdArbitro = @ArbPor, @CodigoExterno = 'ARB-POR', @Nombre = 'Joao',
     @Apellido = 'Silva', @IdPais = @PaisPor, @Categoria = 'Confederacion', @FechaNacimiento = '1988-11-02';
SELECT 'Despues' AS Momento, IdArbitro, CodigoExterno, Nombre, Apellido, FechaNacimiento, Categoria
FROM Arbitraje.Arbitro WHERE IdArbitro = @ArbPor;

/*------------------------------------------------------------------------------
 ARBITRO IDIOMA
------------------------------------------------------------------------------*/
PRINT '=== Prueba 3: alta de idiomas ===';
-- Resultado esperado: Rossi habla it y en; Silva pt y es; Kuipers nl.
EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @ArbIta, @Idioma = 'it';
EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @ArbIta, @Idioma = 'en';
EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @ArbPor, @Idioma = 'pt';
EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @ArbPor, @Idioma = 'es';
EXEC Arbitraje.usp_ArbitroIdioma_Alta @IdArbitro = @ArbNed, @Idioma = 'nl';
SELECT a.Apellido, i.Idioma
FROM Arbitraje.ArbitroIdioma i JOIN Arbitraje.Arbitro a ON a.IdArbitro = i.IdArbitro
ORDER BY a.Apellido, i.Idioma;

PRINT '=== Prueba 4: modificacion y baja de idiomas ===';
-- Resultado esperado: Silva cambia es por en (queda con en y pt) y Rossi pierde it (queda solo con en).
EXEC Arbitraje.usp_ArbitroIdioma_Modificacion @IdArbitro = @ArbPor, @Idioma = 'es', @IdiomaNuevo = 'en';
EXEC Arbitraje.usp_ArbitroIdioma_Baja @IdArbitro = @ArbIta, @Idioma = 'it';
SELECT a.Apellido, i.Idioma
FROM Arbitraje.ArbitroIdioma i JOIN Arbitraje.Arbitro a ON a.IdArbitro = i.IdArbitro
WHERE a.IdArbitro IN (@ArbIta, @ArbPor)
ORDER BY a.Apellido, i.Idioma;

/*------------------------------------------------------------------------------
 DESIGNACION ARBITRAL
------------------------------------------------------------------------------*/
PRINT '=== Prueba 5: designaciones en un partido Programado ===';
-- Resultado esperado: en INC-P1 (Uruguay - Colombia) quedan Rossi como Principal, Silva como Asistente 1 y
-- Kuipers como Asistente 2. Ninguno es uruguayo ni colombiano.
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP1, @IdArbitro = @ArbIta, @RolArbitral = 'Principal',
     @IdDesignacion = @DesigItaP1 OUTPUT;
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP1, @IdArbitro = @ArbPor, @RolArbitral = 'Asistente 1',
     @IdDesignacion = @DesigPorP1 OUTPUT;
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP1, @IdArbitro = @ArbNed, @RolArbitral = 'Asistente 2',
     @IdDesignacion = @DesigNedP1 OUTPUT;
SELECT d.IdDesignacion, a.Apellido, d.RolArbitral, d.InformePostPartido, d.Sancion
FROM Arbitraje.DesignacionArbitral d JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdP1;

PRINT '=== Prueba 6: informe post-partido y sancion con el partido Finalizado ===';
-- Resultado esperado: se designa a Silva (Principal) y Rossi (VAR) en INC-P0 (Colombia - Ecuador). El partido se
-- juega y se finaliza con usp_IniciarPartido y usp_FinalizarPartido (0 a 0, asistencia 65000). Despues se carga el informe y la sancion
-- de Silva: el arbitro y el rol se envian iguales (con el partido Finalizado no se pueden cambiar).
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP0, @IdArbitro = @ArbPor, @RolArbitral = 'Principal',
     @IdDesignacion = @DesigPorP0 OUTPUT;
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @IdP0, @IdArbitro = @ArbIta, @RolArbitral = 'VAR',
     @IdDesignacion = @DesigItaP0 OUTPUT;
EXEC Torneo.usp_IniciarPartido @IdPartido = @IdP0;
EXEC Torneo.usp_FinalizarPartido @IdPartido = @IdP0, @Asistencia = 65000;
SELECT IdPartido, Estado, GolesLocal, GolesVisitante, Asistencia FROM Torneo.Partido WHERE IdPartido = @IdP0;
EXEC Arbitraje.usp_DesignacionArbitral_Modificacion @IdDesignacion = @DesigPorP0, @IdArbitro = @ArbPor,
     @RolArbitral = 'Principal', @InformePostPartido = 'Partido sin incidentes graves. Buen comportamiento de ambos equipos.',
     @Sancion = 'Sin sancion';
SELECT d.IdDesignacion, a.Apellido, d.RolArbitral, d.InformePostPartido, d.Sancion
FROM Arbitraje.DesignacionArbitral d JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdP0;

PRINT '=== Prueba 7: modificacion completa de una designacion antes del partido ===';
-- Resultado esperado: en INC-P1 Silva pasa de Asistente 1 a Cuarto arbitro (el informe y la sancion van en NULL
-- porque el partido todavia no se jugo).
EXEC Arbitraje.usp_DesignacionArbitral_Modificacion @IdDesignacion = @DesigPorP1, @IdArbitro = @ArbPor,
     @RolArbitral = 'Cuarto';
SELECT d.IdDesignacion, a.Apellido, d.RolArbitral
FROM Arbitraje.DesignacionArbitral d JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdP1;

PRINT '=== Prueba 8: baja de una designacion ===';
-- Resultado esperado: Kuipers deja de estar designado en INC-P1. Quedan Rossi (Principal) y Silva (Cuarto).
EXEC Arbitraje.usp_DesignacionArbitral_Baja @IdDesignacion = @DesigNedP1;
SELECT d.IdDesignacion, a.Apellido, d.RolArbitral
FROM Arbitraje.DesignacionArbitral d JOIN Arbitraje.Arbitro a ON a.IdArbitro = d.IdArbitro
WHERE d.IdPartido = @IdP1;

PRINT '=== Prueba 9: baja de un arbitro sin designaciones ===';
-- Resultado esperado: se elimina Kuipers y, por la clave foranea en cascada, tambien su idioma: 0 y 0.
EXEC Arbitraje.usp_Arbitro_Baja @IdArbitro = @ArbNed;
SELECT (SELECT COUNT(*) FROM Arbitraje.Arbitro WHERE IdArbitro = @ArbNed) AS Arbitros,
       (SELECT COUNT(*) FROM Arbitraje.ArbitroIdioma WHERE IdArbitro = @ArbNed) AS Idiomas;

PRINT '=== Prueba 10: historial de un arbitro ===';
-- Resultado esperado: 2 partidos de Silva, en orden cronologico: INC-P0 (101, Colombia contra Ecuador,
-- Finalizado) como Principal, con su informe, e INC-P1 (102, Uruguay contra Colombia, Programado) como Cuarto
-- arbitro, sin informe ni sancion.
SELECT h.NumeroPartido, h.Fase, h.Estado, h.Local, h.Visitante, h.RolArbitral, h.InformePostPartido, h.Sancion
FROM Arbitraje.fn_HistorialArbitro(@ArbPor) h
ORDER BY h.FechaHoraUtc;
GO
