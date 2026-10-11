/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 06_Tablas_Publicidad.sql
 Objetivo     : Crea las tablas del esquema Publicidad (Anunciante, Campania, Pieza,
                PiezaPais, TarifaPublicitaria y PublicidadPartido) con sus
                restricciones, con las columnas del DER v5.
                Se puede ejecutar mas de una vez: borra y recrea las tablas.
 Prerrequisito: 02_Tablas_Torneo.sql.
==============================================================================*/
USE MundialDB;


GO
DROP TABLE IF EXISTS Publicidad.PublicidadPartido;

DROP TABLE IF EXISTS Publicidad.TarifaPublicitaria;

DROP TABLE IF EXISTS Publicidad.PiezaPais;

DROP TABLE IF EXISTS Publicidad.Pieza;

DROP TABLE IF EXISTS Publicidad.Campania;

DROP TABLE IF EXISTS Publicidad.Anunciante;


GO
CREATE TABLE Publicidad.Anunciante (
    IdAnunciante INT           IDENTITY (1, 1) NOT NULL,
    Nombre       VARCHAR (120) NOT NULL,
    CONSTRAINT PK_Anunciante PRIMARY KEY (IdAnunciante),
    CONSTRAINT UQ_Anunciante_Nombre UNIQUE (Nombre)
);


GO
CREATE TABLE Publicidad.Campania (
    IdCampania   INT           IDENTITY (1, 1) NOT NULL,
    IdAnunciante INT           NOT NULL,
    Nombre       VARCHAR (120) NOT NULL,
    FechaInicio  DATE          NOT NULL,
    FechaFin     DATE          NOT NULL,
    CONSTRAINT PK_Campania PRIMARY KEY (IdCampania),
    CONSTRAINT UQ_Campania_Anunciante_Nombre UNIQUE (IdAnunciante, Nombre),
    CONSTRAINT FK_Campania_Anunciante FOREIGN KEY (IdAnunciante) REFERENCES Publicidad.Anunciante (IdAnunciante),
    CONSTRAINT CK_Campania_Fechas CHECK (FechaFin >= FechaInicio)
);


GO
CREATE TABLE Publicidad.Pieza (
    IdPieza          INT           IDENTITY (1, 1) NOT NULL,
    IdCampania       INT           NOT NULL,
    Idioma           VARCHAR (10)  NOT NULL,
    Nombre           VARCHAR (120) NOT NULL,
    DuracionSegundos INT           NOT NULL,
    CONSTRAINT PK_Pieza PRIMARY KEY (IdPieza),
    CONSTRAINT FK_Pieza_Campania FOREIGN KEY (IdCampania) REFERENCES Publicidad.Campania (IdCampania),
    CONSTRAINT CK_Pieza_Duracion CHECK (DuracionSegundos BETWEEN 1 AND 300)
);


GO
-- Paises de interes (mercados) de cada pieza. Al eliminar una pieza se eliminan sus paises.
CREATE TABLE Publicidad.PiezaPais (
    IdPieza INT NOT NULL,
    IdPais  INT NOT NULL,
    CONSTRAINT PK_PiezaPais PRIMARY KEY (IdPieza, IdPais),
    CONSTRAINT FK_PiezaPais_Pieza FOREIGN KEY (IdPieza) REFERENCES Publicidad.Pieza (IdPieza) ON DELETE CASCADE,
    CONSTRAINT FK_PiezaPais_Pais FOREIGN KEY (IdPais) REFERENCES Torneo.Pais (IdPais)
);


GO
-- Precio de un espacio publicitario segun la fase, con su periodo de vigencia.
CREATE TABLE Publicidad.TarifaPublicitaria (
    IdTarifa     INT             IDENTITY (1, 1) NOT NULL,
    Fase         VARCHAR (20)    NOT NULL,
    Moneda       CHAR (3)        NOT NULL,
    Monto        DECIMAL (18, 2) NOT NULL,
    VigenteDesde DATE            NOT NULL,
    VigenteHasta DATE            NOT NULL,
    CONSTRAINT PK_TarifaPublicitaria PRIMARY KEY (IdTarifa),
    CONSTRAINT CK_TarifaPublicitaria_Fase CHECK (Fase IN (
        'Grupos',
        'Dieciseisavos',
        'Octavos',
        'Cuartos',
        'Semifinal',
        'Tercer puesto',
        'Final'
    )),
    CONSTRAINT CK_TarifaPublicitaria_MontoPositivo CHECK (Monto > 0),
    CONSTRAINT CK_TarifaPublicitaria_Vigencia CHECK (VigenteHasta >= VigenteDesde)
);


GO
-- Pieza que ocupa cada uno de los 4 espacios de un partido. Estados:
--   Propuesta  la eligio el sistema (usp_AsignarPiezasPartido).
--   Confirmada se vendio el espacio.
--   Exhibida   salio al aire (registro historico para facturar).
--   Descartada no se uso.
CREATE TABLE Publicidad.PublicidadPartido (
    IdPublicidadPartido INT            IDENTITY (1, 1) NOT NULL,
    IdPartido           INT            NOT NULL,
    NumeroEspacio       INT            NOT NULL,
    IdPieza             INT            NOT NULL,
    IdTarifa            INT            NOT NULL,
    Criterio            VARCHAR (30)   NULL,
    Puntaje             DECIMAL (9, 2) NULL,
    Estado              VARCHAR (15)   NOT NULL,
    CONSTRAINT PK_PublicidadPartido PRIMARY KEY (IdPublicidadPartido),
    CONSTRAINT FK_PublicidadPartido_Partido FOREIGN KEY (IdPartido) REFERENCES Torneo.Partido (IdPartido),
    CONSTRAINT FK_PublicidadPartido_Pieza FOREIGN KEY (IdPieza) REFERENCES Publicidad.Pieza (IdPieza),
    CONSTRAINT FK_PublicidadPartido_TarifaPublicitaria FOREIGN KEY (IdTarifa) REFERENCES Publicidad.TarifaPublicitaria (IdTarifa),
    CONSTRAINT CK_PublicidadPartido_NumeroEspacio CHECK (NumeroEspacio BETWEEN 1 AND 4),
    CONSTRAINT CK_PublicidadPartido_Estado CHECK (Estado IN (
        'Propuesta',
        'Confirmada',
        'Exhibida',
        'Descartada'
    ))
);


GO
