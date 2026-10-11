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

Orden de creacion por dependencias FK:
Tarifa Publicitaria -> Anunciante -> Campaña -> Pieza -> PiezaPais -> PublicidadPartido

Lo de arriba probablemente las ultimas 2 tablas no funcionen por que faltan tablas.

Objetivo del Script:
- Creación de Tablas del Módulo de Publicidad (Anunciante, Campania, Pieza, 
  PiezaPais, TarifaPublicitaria, PublicidadPartido).
================================================================================
*/

-- =============================================================================
-- 1. CREACIÓN DE TABLAS
-- =============================================================================

USE MundialDB;
GO

CREATE TABLE Publicidad.Anunciante (
    IdAnunciante int identity PRIMARY KEY NOT NULL,
    Nombre varchar(120) NOT NULL,
);

CREATE TABLE Publicidad.Campania (
    IdCampania INT IDENTITY(1,1) NOT NULL,
    IdAnunciante INT NOT NULL,
    Nombre VARCHAR(120) NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,
    CONSTRAINT PK_Campania PRIMARY KEY (IdCampania),
    CONSTRAINT FK_Campania_Anunciante FOREIGN KEY (IdAnunciante) 
        REFERENCES Publicidad.Anunciante(IdAnunciante),
    CONSTRAINT CK_Campania_Fechas CHECK (FechaFin >= FechaInicio)
);

CREATE TABLE Publicidad.Pieza (
    IdPieza INT IDENTITY(1,1) NOT NULL,
    IdCampania INT NOT NULL,
    Idioma VARCHAR(10) NOT NULL,
    Nombre VARCHAR(120) NOT NULL,
    DuracionSegundos INT NOT NULL,
    CONSTRAINT PK_Pieza PRIMARY KEY (IdPieza),
    CONSTRAINT FK_Pieza_Campania FOREIGN KEY (IdCampania) 
        REFERENCES Publicidad.Campania(IdCampania),
    CONSTRAINT CK_Pieza_Duracion CHECK (DuracionSegundos > 0)
);

CREATE TABLE Publicidad.PiezaPais (
    IdPieza INT NOT NULL,
    IdPais INT NOT NULL,
    CONSTRAINT PK_PiezaPais PRIMARY KEY (IdPieza, IdPais),
    CONSTRAINT FK_PiezaPais_Pieza FOREIGN KEY (IdPieza) 
        REFERENCES Publicidad.Pieza(IdPieza),
    CONSTRAINT FK_PiezaPais_Pais FOREIGN KEY (IdPais) 
        REFERENCES Torneo.Pais(IdPais)
);

CREATE TABLE Publicidad.TarifaPublicitaria (
    IdTarifa INT IDENTITY(1,1) NOT NULL,
    Fase VARCHAR(20) NOT NULL,
    Moneda CHAR(3) NOT NULL,
    Monto DECIMAL(10,2) NOT NULL,
    VigenteDesde DATE NOT NULL,
    VigenteHasta DATE NOT NULL,
	CONSTRAINT PK_TarifaPublicitaria PRIMARY KEY (IdTarifa),
    CONSTRAINT CK_Tarifa_Monto CHECK (Monto > 0),
    CONSTRAINT CK_Tarifa_Fechas CHECK (VigenteHasta >= VigenteDesde)
);

CREATE TABLE Publicidad.PublicidadPartido (
    IdPublicidadPartido INT IDENTITY(1,1) NOT NULL,
    IdPartido INT NOT NULL,
    NumeroEspacio INT NOT NULL,
    IdPieza INT NOT NULL,
    IdTarifa INT NOT NULL,
    Criterio VARCHAR(30) NULL,
    Puntaje DECIMAL(9,2) NULL,
    Estado VARCHAR(15) NOT NULL DEFAULT 'ASIGNADO',
    CONSTRAINT PK_PublicidadPartido PRIMARY KEY (IdPublicidadPartido, IdPartido),
    CONSTRAINT FK_PublicidadPartido_Partido FOREIGN KEY (IdPartido) 
        REFERENCES Partido(IdPartido),
    CONSTRAINT FK_Publicidad_Pieza FOREIGN KEY (IdPieza) 
        REFERENCES Publicidad.Pieza(IdPieza),
    CONSTRAINT FK_PublicidadPartido_Tarifa FOREIGN KEY (IdTarifa) 
        REFERENCES Publicidad.TarifaPublicitaria(IdTarifa),
    CONSTRAINT CK_Publicidad_Espacio CHECK (NumeroEspacio BETWEEN 1 AND 4)
);
GO
