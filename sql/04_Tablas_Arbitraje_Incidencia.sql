/*==============================================================================
 Universidad Nacional de La Matanza
 Materia      : Bases de Datos Aplicada (3641)
 Comision     : 02-5600 | Grupo N° 4
 Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
 Fecha        : 2026-10-11
 Script       : 04_Tablas_Arbitraje_Incidencia.sql
 Objetivo     : Crea las tablas del esquema Arbitraje (Arbitro, ArbitroIdioma y
                DesignacionArbitral) y del esquema Incidencia (Gol y Tarjeta) con
                sus restricciones, con las columnas del DER v5.
                Se puede ejecutar mas de una vez: borra y recrea las tablas.
 Prerrequisito: 02_Tablas_Torneo.sql y 03_Tablas_Formacion.sql.
==============================================================================*/
USE MundialDB;


GO
DROP TABLE IF EXISTS Incidencia.Tarjeta;

DROP TABLE IF EXISTS Incidencia.Gol;

DROP TABLE IF EXISTS Arbitraje.DesignacionArbitral;

DROP TABLE IF EXISTS Arbitraje.ArbitroIdioma;

DROP TABLE IF EXISTS Arbitraje.Arbitro;


GO
CREATE TABLE Arbitraje.Arbitro (
    IdArbitro       INT          IDENTITY (1, 1) NOT NULL,
    CodigoExterno   VARCHAR (30) NULL,
    Nombre          VARCHAR (80) NOT NULL,
    Apellido        VARCHAR (80) NOT NULL,
    FechaNacimiento DATE         NULL,
    IdPais          INT          NOT NULL,
    Categoria       VARCHAR (20) NOT NULL,
    CONSTRAINT PK_Arbitro PRIMARY KEY (IdArbitro),
    CONSTRAINT UQ_Arbitro_CodigoExterno UNIQUE (CodigoExterno),
    CONSTRAINT FK_Arbitro_Pais FOREIGN KEY (IdPais) REFERENCES Torneo.Pais (IdPais),
    CONSTRAINT CK_Arbitro_Categoria CHECK (Categoria IN (
        'FIFA',
        'Confederacion'
    ))
);


GO
-- Al eliminar un arbitro se eliminan sus idiomas.
CREATE TABLE Arbitraje.ArbitroIdioma (
    IdArbitro INT          NOT NULL,
    Idioma    VARCHAR (10) NOT NULL,
    CONSTRAINT PK_ArbitroIdioma PRIMARY KEY (IdArbitro, Idioma),
    CONSTRAINT FK_ArbitroIdioma_Arbitro FOREIGN KEY (IdArbitro) REFERENCES Arbitraje.Arbitro (IdArbitro) ON DELETE CASCADE
);


GO
-- Cada rol se cubre una sola vez por partido y un arbitro cumple un solo rol por partido.
CREATE TABLE Arbitraje.DesignacionArbitral (
    IdDesignacion      INT           IDENTITY (1, 1) NOT NULL,
    IdPartido          INT           NOT NULL,
    IdArbitro          INT           NOT NULL,
    RolArbitral        VARCHAR (20)  NOT NULL,
    InformePostPartido VARCHAR (500) NULL,
    Sancion            VARCHAR (200) NULL,
    CONSTRAINT PK_DesignacionArbitral PRIMARY KEY (IdDesignacion),
    CONSTRAINT UQ_DesignacionArbitral_Partido_Rol UNIQUE (IdPartido, RolArbitral),
    CONSTRAINT UQ_DesignacionArbitral_Partido_Arbitro UNIQUE (IdPartido, IdArbitro),
    CONSTRAINT FK_DesignacionArbitral_Partido FOREIGN KEY (IdPartido) REFERENCES Torneo.Partido (IdPartido),
    CONSTRAINT FK_DesignacionArbitral_Arbitro FOREIGN KEY (IdArbitro) REFERENCES Arbitraje.Arbitro (IdArbitro),
    CONSTRAINT CK_DesignacionArbitral_Rol CHECK (RolArbitral IN (
        'Principal',
        'Asistente 1',
        'Asistente 2',
        'Cuarto',
        'VAR'
    ))
);


GO
CREATE TABLE Incidencia.Gol (
    IdGol                 INT          IDENTITY (1, 1) NOT NULL,
    IdAlineacionAutor     INT          NOT NULL,
    IdAlineacionAsistente INT          NULL,
    TipoGol               VARCHAR (20) NOT NULL,
    Periodo               VARCHAR (30) NOT NULL,
    Minuto                INT          NOT NULL,
    MinutoAdicional       INT          NOT NULL CONSTRAINT DF_Gol_MinutoAdicional DEFAULT (0),
    CONSTRAINT PK_Gol PRIMARY KEY (IdGol),
    CONSTRAINT FK_Gol_Alineacion_Autor FOREIGN KEY (IdAlineacionAutor) REFERENCES Formacion.Alineacion (IdAlineacion),
    CONSTRAINT FK_Gol_Alineacion_Asistente FOREIGN KEY (IdAlineacionAsistente) REFERENCES Formacion.Alineacion (IdAlineacion),
    CONSTRAINT CK_Gol_Tipo CHECK (TipoGol IN (
        'Jugada',
        'Penal',
        'Tiro libre',
        'Cabezazo',
        'En contra'
    )),
    CONSTRAINT CK_Gol_Periodo CHECK (Periodo IN (
        'Primer tiempo',
        'Segundo tiempo',
        'Alargue 1',
        'Alargue 2',
        'Penales'
    )),
    CONSTRAINT CK_Gol_Minuto CHECK (Minuto BETWEEN 1 AND 120),
    CONSTRAINT CK_Gol_MinutoAdicional CHECK (MinutoAdicional BETWEEN 0 AND 30),
    CONSTRAINT CK_Gol_AutorDistintoAsistente CHECK (IdAlineacionAsistente <> IdAlineacionAutor)
);


GO
-- La tarjeta es para un jugador (IdAlineacion) o para un integrante del cuerpo
-- tecnico (IdCuerpoTecnico), nunca para los dos.
CREATE TABLE Incidencia.Tarjeta (
    IdTarjeta       INT           IDENTITY (1, 1) NOT NULL,
    IdPartido       INT           NOT NULL,
    IdCuerpoTecnico INT           NULL,
    IdAlineacion    INT           NULL,
    TipoTarjeta     VARCHAR (30)  NOT NULL,
    Periodo         VARCHAR (30)  NOT NULL,
    Minuto          INT           NOT NULL,
    MinutoAdicional INT           NOT NULL CONSTRAINT DF_Tarjeta_MinutoAdicional DEFAULT (0),
    Motivo          VARCHAR (100) NULL,
    CONSTRAINT PK_Tarjeta PRIMARY KEY (IdTarjeta),
    CONSTRAINT FK_Tarjeta_Partido FOREIGN KEY (IdPartido) REFERENCES Torneo.Partido (IdPartido),
    CONSTRAINT FK_Tarjeta_CuerpoTecnico FOREIGN KEY (IdCuerpoTecnico) REFERENCES Torneo.CuerpoTecnico (IdCuerpoTecnico),
    CONSTRAINT FK_Tarjeta_Alineacion FOREIGN KEY (IdAlineacion) REFERENCES Formacion.Alineacion (IdAlineacion),
    CONSTRAINT CK_Tarjeta_Tipo CHECK (TipoTarjeta IN (
        'Amarilla',
        'Roja directa',
        'Roja por doble amarilla'
    )),
    CONSTRAINT CK_Tarjeta_Periodo CHECK (Periodo IN (
        'Primer tiempo',
        'Segundo tiempo',
        'Alargue 1',
        'Alargue 2',
        'Penales'
    )),
    CONSTRAINT CK_Tarjeta_Minuto CHECK (Minuto BETWEEN 1 AND 120),
    CONSTRAINT CK_Tarjeta_MinutoAdicional CHECK (MinutoAdicional BETWEEN 0 AND 30),
    CONSTRAINT CK_Tarjeta_Destinatario CHECK ((IdAlineacion IS NOT NULL
                                               AND IdCuerpoTecnico IS NULL)
                                              OR (IdAlineacion IS NULL
                                                  AND IdCuerpoTecnico IS NOT NULL))
);


GO
