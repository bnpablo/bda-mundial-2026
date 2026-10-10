/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-09
 Script       : 02_Tablas_Torneo.sql
 Objetivo     : Crea las tablas del esquema Torneo (Pais, Sede, Seleccion,
                Partido, Jugador y CuerpoTecnico) con sus restricciones.
                Se puede ejecutar mas de una vez: borra y recrea las tablas.
==============================================================================*/

USE MundialDB;
GO

-- El esquema Formacion lo crea 01_Base_Esquemas.sql.
-- Se borra primero Sustitucion porque referencia a Alineacion.
DROP TABLE IF EXISTS Formacion.Sustitucion;
DROP TABLE IF EXISTS Formacion.Alineacion;
GO

CREATE TABLE Formacion.Alineacion (
    IdAlineacion    int IDENTITY(1,1),
    IdPartido       int NOT NULL,
    IdJugador       int NOT NULL,
    EsTitular       bit NOT NULL,
    PosicionCancha  varchar(10) NOT NULL,
    CONSTRAINT PK_Alineacion PRIMARY KEY CLUSTERED (IdAlineacion),
    CONSTRAINT FK_Alineacion_Partido FOREIGN KEY (IdPartido) REFERENCES Torneo.Partido(IdPartido),
    CONSTRAINT FK_Alineacion_Jugador FOREIGN KEY (IdJugador) REFERENCES Torneo.Jugador(IdJugador),
    -- Un jugador puede estar en muchos partidos, pero una sola vez en cada uno
    CONSTRAINT UQ_Alineacion_Partido_Jugador UNIQUE (IdPartido, IdJugador),
    -- Mismos valores que Torneo.Jugador.PosicionHabitual (02_Tablas_Torneo.sql)
    CONSTRAINT CK_Alineacion_PosicionCancha CHECK (PosicionCancha IN (
        'POR',
        'DEF',
        'MED',
        'DEL'
    ))
);
GO

-- Indice de cobertura: consultar por partido (titulares/suplentes) sin ir a la tabla
CREATE NONCLUSTERED INDEX IX_Alineacion_IdPartido_EsTitular
    ON Formacion.Alineacion (IdPartido, EsTitular)
    INCLUDE (IdJugador, PosicionCancha);

-- Busqueda por jugador (historial de partidos)
CREATE NONCLUSTERED INDEX IX_Alineacion_IdJugador
    ON Formacion.Alineacion (IdJugador);
GO

CREATE TABLE Formacion.Sustitucion (
    IdSustitucion       int IDENTITY(1,1),
    IdAlineacionSale    int NOT NULL,
    IdAlineacionEntra   int NOT NULL,
    Periodo             varchar(30) NOT NULL,
    Minuto              int NOT NULL,
    MinutoAdicional     int NOT NULL,
    NumeroVentana       int NULL,
    Motivo              varchar(20) NOT NULL,
    CONSTRAINT PK_Sustitucion PRIMARY KEY CLUSTERED (IdSustitucion),
    CONSTRAINT FK_Sustitucion_Alineacion_Sale  FOREIGN KEY (IdAlineacionSale)  REFERENCES Formacion.Alineacion(IdAlineacion),
    CONSTRAINT FK_Sustitucion_Alineacion_Entra FOREIGN KEY (IdAlineacionEntra) REFERENCES Formacion.Alineacion(IdAlineacion),
    -- Hasta 120 por la prorroga; la validacion segun el periodo la hace la funcion de minuto valido (75)
    CONSTRAINT CK_Sustitucion_MinutoRango CHECK (Minuto BETWEEN 0 AND 120),
    CONSTRAINT CK_Sustitucion_MinutoAdicionalNoNegativo CHECK (MinutoAdicional >= 0),
    CONSTRAINT CK_Sustitucion_SaleDistintoEntra CHECK (IdAlineacionSale <> IdAlineacionEntra)
);
GO