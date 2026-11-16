/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-11-15
 Script       : 90_Test_SP_Reportes_OK.sql
 Objetivo     : Testing exitoso de 89_SP_Reportes.sql (relacion 1:1).
                Para que los resultados esperados sean exactos, el test arma sus
                propios datos con los SP de ABM y de negocio y filtra cada reporte
                por esos datos:
                  - 3 paises: Reporte Alfa (huso de Argentina), Reporte Beta (huso
                    del este de EE.UU.) y Reporte Gamma (huso de Japon).
                  - 2 selecciones (Alfa y Beta) con 23 convocados cada una.
                  - 3 partidos de Grupos en 2031 en el Estadio Reporte:
                      P1 Alfa 2 - 1 Beta (Finalizado)
                      P2 Beta 1 - 1 Alfa (Finalizado)
                      P3 Alfa - Beta     (Programado)
                  - 2 arbitros: Uno (Principal en P1 y P2) y Dos (asistente en
                    P1, VAR en P2 y Principal en P3).
                  - 2 anunciantes con una tarifa de Grupos de 150000 USD:
                    3 espacios exhibidos (2 en P1 y 1 en P2).
                Todo se hace dentro de una transaccion que se deshace al final:
                el test no deja datos en la base.
 Requisito    : ejecutar despues de 89_SP_Reportes.sql.
==============================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

BEGIN TRANSACTION;

/*------------------------------------------------------------------------------
 PREPARACION DE DATOS
------------------------------------------------------------------------------*/
DECLARE @PaisA INT, @PaisB INT, @PaisC INT, @IdSede INT, @SelA INT, @SelB INT;
DECLARE @P1 INT, @P2 INT, @P3 INT, @Arb1 INT, @Arb2 INT;
DECLARE @Anun1 INT, @Anun2 INT, @Camp1 INT, @Camp2 INT, @Pieza1 INT, @Pieza2 INT;
DECLARE @i INT, @codigo VARCHAR(30), @apellido VARCHAR(80), @posicion VARCHAR(5);
DECLARE @A01 INT, @A09 INT, @A17 INT, @B01 INT, @B09 INT, @B17 INT;
DECLARE @alA01 INT, @alA09 INT, @alA17 INT, @alB01 INT, @alB09 INT, @alB17 INT;

-- Grupo con menos selecciones (pueden quedar selecciones de otros scripts).
DECLARE @grupo CHAR(1) = (SELECT TOP (1) g.Letra
                          FROM (VALUES ('A'), ('B'), ('C'), ('D'), ('E'), ('F'),
                                       ('G'), ('H'), ('I'), ('J'), ('K'), ('L')) g (Letra)
                          ORDER BY (SELECT COUNT(*) FROM Torneo.Seleccion s WHERE s.Grupo = g.Letra), g.Letra);

EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'QRA', @Nombre = 'Reporte Alfa', @Confederacion = 'CONMEBOL',
     @HusoHorario = 'Argentina Standard Time', @IdPais = @PaisA OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'QRB', @Nombre = 'Reporte Beta', @Confederacion = 'CONCACAF',
     @HusoHorario = 'Eastern Standard Time', @IdPais = @PaisB OUTPUT;
EXEC Torneo.usp_Pais_Alta @CodigoIso3 = 'QRC', @Nombre = 'Reporte Gamma', @Confederacion = 'AFC',
     @HusoHorario = 'Tokyo Standard Time', @IdPais = @PaisC OUTPUT;

EXEC Torneo.usp_Sede_Alta @CodigoExterno = 'SEDE-RPT', @NombreEstadio = 'Estadio Reporte', @Ciudad = 'Ciudad Reporte',
     @IdPais = @PaisA, @HusoHorario = 'Argentina Standard Time', @Capacidad = 60000, @IdSede = @IdSede OUTPUT;

EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = 'SEL-QRA', @IdPais = @PaisA, @Grupo = @grupo, @IdSeleccion = @SelA OUTPUT;
EXEC Torneo.usp_Seleccion_Alta @CodigoExterno = 'SEL-QRB', @IdPais = @PaisB, @Grupo = @grupo, @IdSeleccion = @SelB OUTPUT;

-- 23 convocados por seleccion (el minimo para iniciar un partido). Apellido = seleccion + dorsal.
-- Dorsal 1 arquero, 2 a 8 defensores, 9 a 16 mediocampistas, 17 a 23 delanteros.
SET @i = 1;
WHILE @i <= 23
BEGIN
    SET @posicion = CASE WHEN @i = 1 THEN 'POR' WHEN @i <= 8 THEN 'DEF' WHEN @i <= 16 THEN 'MED' ELSE 'DEL' END;

    SET @codigo = 'QRA-' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    SET @apellido = 'Alfa' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @codigo, @Nombre = 'Jugador', @Apellido = @apellido,
         @IdPais = @PaisA, @IdSeleccion = @SelA, @Dorsal = @i, @PosicionHabitual = @posicion,
         @ClubOrigen = 'Club Alfa', @FechaAlta = '2031-01-10';

    SET @codigo = 'QRB-' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    SET @apellido = 'Beta' + RIGHT('0' + CAST(@i AS VARCHAR(2)), 2);
    EXEC Torneo.usp_Jugador_Alta @CodigoExterno = @codigo, @Nombre = 'Jugador', @Apellido = @apellido,
         @IdPais = @PaisB, @IdSeleccion = @SelB, @Dorsal = @i, @PosicionHabitual = @posicion,
         @ClubOrigen = 'Club Beta', @FechaAlta = '2031-01-10';

    SET @i += 1;
END;

-- Beta tiene un convocado mas (24): sirve para probar que una baja no aparece en la plantilla.
EXEC Torneo.usp_Jugador_Alta @CodigoExterno = 'QRB-24', @Nombre = 'Jugador', @Apellido = 'Beta24',
     @IdPais = @PaisB, @IdSeleccion = @SelB, @Dorsal = 24, @PosicionHabitual = 'DEL',
     @ClubOrigen = 'Club Beta', @FechaAlta = '2031-01-10';

SELECT @A01 = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRA-01';
SELECT @A09 = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRA-09';
SELECT @A17 = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRA-17';
SELECT @B01 = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRB-01';
SELECT @B09 = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRB-09';
SELECT @B17 = IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRB-17';

-- Partidos. P1 a las 23 UTC: 20 h en Alfa, 19 h en Beta y 8 h en Gamma.
-- P2 a las 16 UTC: 13 h en Alfa, 12 h en Beta y 1 h en Gamma. P3 a las 10 UTC: 7, 6 y 19 h.
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'RPT-P1', @NumeroPartido = 9701, @Fase = 'Grupos', @IdSede = @IdSede,
     @FechaHoraUtc = '2031-06-20 23:00', @IdSeleccionLocal = @SelA, @IdSeleccionVisitante = @SelB, @IdPartido = @P1 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'RPT-P2', @NumeroPartido = 9702, @Fase = 'Grupos', @IdSede = @IdSede,
     @FechaHoraUtc = '2031-06-25 16:00', @IdSeleccionLocal = @SelB, @IdSeleccionVisitante = @SelA, @IdPartido = @P2 OUTPUT;
EXEC Torneo.usp_Partido_Alta @CodigoExterno = 'RPT-P3', @NumeroPartido = 9703, @Fase = 'Grupos', @IdSede = @IdSede,
     @FechaHoraUtc = '2031-06-30 10:00', @IdSeleccionLocal = @SelA, @IdSeleccionVisitante = @SelB, @IdPartido = @P3 OUTPUT;

-- Arbitros y designaciones (antes de finalizar los partidos).
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-RPT-1', @Nombre = 'Arbitro', @Apellido = 'Uno',
     @IdPais = @PaisC, @Categoria = 'FIFA', @IdArbitro = @Arb1 OUTPUT;
EXEC Arbitraje.usp_Arbitro_Alta @CodigoExterno = 'ARB-RPT-2', @Nombre = 'Arbitro', @Apellido = 'Dos',
     @IdPais = @PaisC, @Categoria = 'FIFA', @IdArbitro = @Arb2 OUTPUT;
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @P1, @IdArbitro = @Arb1, @RolArbitral = 'Principal';
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @P1, @IdArbitro = @Arb2, @RolArbitral = 'Asistente 1';
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @P2, @IdArbitro = @Arb1, @RolArbitral = 'Principal';
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @P2, @IdArbitro = @Arb2, @RolArbitral = 'VAR';
EXEC Arbitraje.usp_DesignacionArbitral_Alta @IdPartido = @P3, @IdArbitro = @Arb2, @RolArbitral = 'Principal';

-- Publicidad (antes de finalizar): tarifa de Grupos, 2 anunciantes y sus espacios.
EXEC Publicidad.usp_TarifaPublicitaria_Alta @Fase = 'Grupos', @Moneda = 'USD', @Monto = 150000,
     @VigenteDesde = '2031-06-01', @VigenteHasta = '2031-07-31';
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Anunciante Reporte Uno', @IdAnunciante = @Anun1 OUTPUT;
EXEC Publicidad.usp_Anunciante_Alta @Nombre = 'Anunciante Reporte Dos', @IdAnunciante = @Anun2 OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @Anun1, @Nombre = 'Campania Reporte Uno',
     @FechaInicio = '2031-06-01', @FechaFin = '2031-07-31', @IdCampania = @Camp1 OUTPUT;
EXEC Publicidad.usp_Campania_Alta @IdAnunciante = @Anun2, @Nombre = 'Campania Reporte Dos',
     @FechaInicio = '2031-06-01', @FechaFin = '2031-07-31', @IdCampania = @Camp2 OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @Camp1, @Nombre = 'Pieza Reporte Uno', @Idioma = 'es',
     @DuracionSegundos = 30, @IdPieza = @Pieza1 OUTPUT;
EXEC Publicidad.usp_Pieza_Alta @IdCampania = @Camp2, @Nombre = 'Pieza Reporte Dos', @Idioma = 'es',
     @DuracionSegundos = 30, @IdPieza = @Pieza2 OUTPUT;
DECLARE @Pub1 INT, @Pub2 INT, @Pub3 INT;
EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @P1, @NumeroEspacio = 1, @IdPieza = @Pieza1, @IdPublicidadPartido = @Pub1 OUTPUT;
EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @P1, @NumeroEspacio = 2, @IdPieza = @Pieza2, @IdPublicidadPartido = @Pub2 OUTPUT;
EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @P2, @NumeroEspacio = 1, @IdPieza = @Pieza2, @IdPublicidadPartido = @Pub3 OUTPUT;
EXEC Publicidad.usp_PublicidadPartido_Alta @IdPartido = @P3, @NumeroEspacio = 1, @IdPieza = @Pieza1;    -- queda Confirmada

-- P1: Alfa 2 - 1 Beta. Alfa17 hace 2 goles (uno de penal), Beta17 hace 1 y despues ve la roja directa.
-- Alfa09 recibe amarilla.
EXEC Torneo.usp_IniciarPartido @IdPartido = @P1;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P1, @IdJugador = @A01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @alA01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P1, @IdJugador = @A09, @EsTitular = 1, @PosicionCancha = 'MED', @IdAlineacion = @alA09 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P1, @IdJugador = @A17, @EsTitular = 1, @PosicionCancha = 'DEL', @IdAlineacion = @alA17 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P1, @IdJugador = @B01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @alB01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P1, @IdJugador = @B17, @EsTitular = 1, @PosicionCancha = 'DEL', @IdAlineacion = @alB17 OUTPUT;
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alA17, @TipoGol = 'Jugada', @Periodo = 'Primer tiempo', @Minuto = 10;
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alA17, @TipoGol = 'Penal', @Periodo = 'Primer tiempo', @Minuto = 30;
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alB17, @TipoGol = 'Cabezazo', @Periodo = 'Segundo tiempo', @Minuto = 50;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @P1, @IdAlineacion = @alA09, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Primer tiempo', @Minuto = 40, @Motivo = 'Falta';
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @P1, @IdAlineacion = @alB17, @TipoTarjeta = 'Roja directa',
     @Periodo = 'Segundo tiempo', @Minuto = 80, @Motivo = 'Juego brusco grave';
EXEC Torneo.usp_FinalizarPartido @IdPartido = @P1, @Asistencia = 50000;
-- La exhibicion se registra con la modificacion del ABM (usp_RegistrarExhibicion esta en el 96, que corre despues).
EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @Pub1, @NumeroEspacio = 1, @Estado = 'Exhibida';
EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @Pub2, @NumeroEspacio = 2, @Estado = 'Exhibida';

-- P2: Beta 1 - 1 Alfa. Beta17 no juega (cumple la suspension por la roja). Alfa09 recibe su segunda amarilla.
EXEC Torneo.usp_IniciarPartido @IdPartido = @P2;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P2, @IdJugador = @A01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @alA01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P2, @IdJugador = @A09, @EsTitular = 1, @PosicionCancha = 'MED', @IdAlineacion = @alA09 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P2, @IdJugador = @A17, @EsTitular = 1, @PosicionCancha = 'DEL', @IdAlineacion = @alA17 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P2, @IdJugador = @B01, @EsTitular = 1, @PosicionCancha = 'POR', @IdAlineacion = @alB01 OUTPUT;
EXEC Formacion.usp_Alineacion_Alta @IdPartido = @P2, @IdJugador = @B09, @EsTitular = 1, @PosicionCancha = 'MED', @IdAlineacion = @alB09 OUTPUT;
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alA17, @TipoGol = 'Jugada', @Periodo = 'Primer tiempo', @Minuto = 15;
EXEC Incidencia.usp_RegistrarGol @IdAlineacionAutor = @alB09, @TipoGol = 'Tiro libre', @Periodo = 'Segundo tiempo', @Minuto = 60;
EXEC Incidencia.usp_RegistrarTarjeta @IdPartido = @P2, @IdAlineacion = @alA09, @TipoTarjeta = 'Amarilla',
     @Periodo = 'Segundo tiempo', @Minuto = 70, @Motivo = 'Protesta';
EXEC Torneo.usp_FinalizarPartido @IdPartido = @P2, @Asistencia = 45000;
EXEC Publicidad.usp_PublicidadPartido_Modificacion @IdPublicidadPartido = @Pub3, @NumeroEspacio = 1, @Estado = 'Exhibida';

SELECT NumeroPartido, Estado, GolesLocal, GolesVisitante FROM Torneo.Partido
WHERE IdPartido IN (@P1, @P2, @P3) ORDER BY NumeroPartido;
-- esperado: 9701 Finalizado 2-1, 9702 Finalizado 1-1, 9703 Programado

/*------------------------------------------------------------------------------
 PRUEBAS
------------------------------------------------------------------------------*/
PRINT '=== Prueba 1: goleadores de una seleccion ===';
-- Resultado esperado: una fila. Puesto 1, Reporte Alfa, Alfa17: Grupos 3, Total 3, DePenal 1.
EXEC Reportes.usp_ReportarGoleadores @IdSeleccion = @SelA;

PRINT '=== Prueba 2: goleadores empatados comparten puesto ===';
-- Resultado esperado: Beta09 y Beta17, los dos en el puesto 1 con 1 gol (Grupos 1, Total 1, DePenal 0).
EXEC Reportes.usp_ReportarGoleadores @IdSeleccion = @SelB;

PRINT '=== Prueba 3: goleadores del torneo ===';
-- Resultado esperado: tabla de todos los jugadores con goles. Alfa17 aparece con 3 goles y su puesto
-- depende de los goles cargados por otros scripts.
EXEC Reportes.usp_ReportarGoleadores;

PRINT '=== Prueba 4: tarjetas y suspension activa por acumulacion ===';
-- Resultado esperado:
--   1. Reporte Alfa: Amarillas 2, RojasDirectas 0, RojasPorDobleAmarilla 0.
--   2. Alfa09: Amarillas 2, ProximoPartido 9703, Suspendido (completo 2 amarillas en el partido anterior).
EXEC Reportes.usp_ReportarTarjetas @IdSeleccion = @SelA;

PRINT '=== Prueba 5: suspension por roja ya cumplida ===';
-- Resultado esperado:
--   1. Reporte Beta: Amarillas 0, RojasDirectas 1.
--   2. Beta17: RojasDirectas 1, ProximoPartido 9703, Habilitado (la roja de 9701 la cumplio en 9702).
EXEC Reportes.usp_ReportarTarjetas @IdSeleccion = @SelB;

PRINT '=== Prueba 6: designaciones del arbitro Principal (XML) ===';
-- Resultado esperado: un elemento Arbitro (Uno) con Partidos="2", Amonestaciones="2" y Expulsiones="1".
-- Partido 9701 (Rol Principal) con 2 tarjetas: amarilla de Alfa09 al 40' y roja directa de Beta17 al 80'.
-- Partido 9702 (Rol Principal) con 1 tarjeta: amarilla de Alfa09 al 70'.
EXEC Reportes.usp_ReportarDesignaciones @IdArbitro = @Arb1;

PRINT '=== Prueba 7: designaciones de un arbitro que no fue Principal en esos partidos (XML) ===';
-- Resultado esperado: Arbitro Dos con Partidos="3", Amonestaciones="0" y Expulsiones="0".
-- 9701 como Asistente 1 y 9702 como VAR, sin tarjetas; 9703 como Principal, sin tarjetas (no se jugo).
EXEC Reportes.usp_ReportarDesignaciones @IdArbitro = @Arb2;

PRINT '=== Prueba 8: ocupacion publicitaria e ingresos de una sede ===';
-- Resultado esperado:
--   1. Partido 9701: Espacio1 Anunciante Reporte Uno, Espacio2 Anunciante Reporte Dos, Espacio3 y 4 (libre),
--      Espacios 2, Ingresos 300000.00 USD. Partido 9702: Espacio1 Anunciante Reporte Dos, Espacios 1,
--      Ingresos 150000.00 USD. El 9703 no aparece: su espacio esta Confirmado, todavia no se exhibio.
--   2. Estadio Reporte: Partidos 2, Espacios 3, Ingresos 450000.00 USD.
EXEC Reportes.usp_ReportarOcupacionPublicitaria @IdSede = @IdSede;

PRINT '=== Prueba 9: ocupacion publicitaria de un partido ===';
-- Resultado esperado: solo el partido 9702 (1 espacio, 150000.00 USD) y la sede con esos mismos valores.
EXEC Reportes.usp_ReportarOcupacionPublicitaria @IdPartido = @P2;

PRINT '=== Prueba 10: matriz de prime time de un partido ===';
-- Resultado esperado: una fila (9701) con una columna por pais cargado. QRA = 1 (20 h), QRB = 1 (19 h)
-- y QRC = 0 (8 h).
EXEC Reportes.usp_ReportarMatrizPrimeTime @IdPartido = @P1;

PRINT '=== Prueba 11: matriz de prime time de un partido a la manana en America ===';
-- Resultado esperado: una fila (9703). QRA = 0 (7 h), QRB = 0 (6 h) y QRC = 1 (19 h).
EXEC Reportes.usp_ReportarMatrizPrimeTime @IdPartido = @P3;

PRINT '=== Prueba 12: matriz con otra franja de prime time ===';
-- Resultado esperado: franja de 12 a 14 para el partido 9702. QRA = 1 (13 h), QRB = 1 (12 h) y QRC = 0 (1 h).
EXEC Reportes.usp_ReportarMatrizPrimeTime @HoraDesde = 12, @HoraHasta = 14, @IdPartido = @P2;

PRINT '=== Prueba 13: matriz de todos los partidos ===';
-- Resultado esperado: una fila por partido cargado (entre ellos 9701, 9702 y 9703) y una columna por pais.
EXEC Reportes.usp_ReportarMatrizPrimeTime;

PRINT '=== Prueba 14: plantilla de una seleccion (XML) ===';
-- Resultado esperado: un elemento Seleccion (Reporte Alfa, codigo QRA) con CantidadConvocados="23" y, dentro
-- de Convocados, 23 jugadores ordenados por dorsal con nombre, apellido, posicion y club (Club Alfa).
EXEC Reportes.usp_ReportarPlantillas @IdSeleccion = @SelA;

PRINT '=== Prueba 15: un convocado dado de baja no aparece en la plantilla (XML) ===';
-- Resultado esperado: Beta tenia 24 convocados. Se da de baja a Beta24 (usp_RegistrarBajaJugador) y
-- Reporte Beta queda con CantidadConvocados="23" y sin el dorsal 24.
DECLARE @B24 INT = (SELECT IdJugador FROM Torneo.Jugador WHERE CodigoExterno = 'QRB-24');
EXEC Torneo.usp_RegistrarBajaJugador @IdJugador = @B24, @MotivoBaja = 'Lesion', @FechaBaja = '2031-06-26';
EXEC Reportes.usp_ReportarPlantillas @IdSeleccion = @SelB;

PRINT '=== Prueba 16: resultados de una seleccion ===';
-- Resultado esperado:
--   1. Tabla del grupo de Alfa y Beta: Reporte Alfa PJ 2, PG 1, PE 1, PP 0, GF 3, GC 2, DG 1, Pts 4;
--      Reporte Beta PJ 2, PG 0, PE 1, PP 1, GF 2, GC 3, DG -1, Pts 1. Alfa queda por encima de Beta
--      (si el grupo tiene selecciones de otros scripts, tambien aparecen).
--   2. Partidos: 9701 Alfa 2-1 Beta, Ganador Reporte Alfa, Goleadores "Alfa17 10', Alfa17 30' (p), Beta17 50'";
--      9702 Beta 1-1 Alfa, Ganador Empate, Goleadores "Alfa17 15', Beta09 60'"; 9703 Programado sin goles.
EXEC Reportes.usp_ReportarResultados @IdSeleccion = @SelA;

PRINT '=== Prueba 17: resultados filtrados por fase ===';
-- Resultado esperado: la misma tabla de posiciones y en la lista solo partidos de Grupos de Alfa.
-- Con Final no hay partidos de Alfa: la lista sale vacia.
EXEC Reportes.usp_ReportarResultados @IdSeleccion = @SelA, @Fase = 'Grupos';
EXEC Reportes.usp_ReportarResultados @IdSeleccion = @SelA, @Fase = 'Final';

/*------------------------------------------------------------------------------
 LIMPIEZA
 Se deshace todo lo que cargo el test.
------------------------------------------------------------------------------*/
ROLLBACK TRANSACTION;

SELECT COUNT(*) AS PaisesDePrueba FROM Torneo.Pais WHERE CodigoIso3 IN ('QRA', 'QRB', 'QRC');
-- esperado: 0
GO
