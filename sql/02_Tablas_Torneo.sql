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
DROP TABLE IF EXISTS Torneo.CuerpoTecnico;

DROP TABLE IF EXISTS Torneo.Jugador;

DROP TABLE IF EXISTS Torneo.Partido;

DROP TABLE IF EXISTS Torneo.Seleccion;

DROP TABLE IF EXISTS Torneo.Sede;

DROP TABLE IF EXISTS Torneo.Pais;


GO
CREATE TABLE Torneo.Pais (
    IdPais          INT             IDENTITY (1, 1) NOT NULL,
    CodigoIso3      CHAR (3)        NOT NULL,
    Nombre          VARCHAR (80)    NOT NULL,
    Confederacion   VARCHAR (10)    NOT NULL,
    HusoHorario     VARCHAR (60)    NOT NULL,
    PibPerCapitaUsd DECIMAL (18, 2) NULL,
    AnioPib         INT             NULL,
    CONSTRAINT PK_Pais PRIMARY KEY (IdPais),
    CONSTRAINT UQ_Pais_CodigoIso3 UNIQUE (CodigoIso3),
    CONSTRAINT UQ_Pais_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Pais_Confederacion CHECK (Confederacion IN (
        'UEFA',
        'CONMEBOL',
        'CONCACAF',
        'CAF',
        'AFC',
        'OFC'
    ))
);


GO
CREATE TABLE Torneo.Sede (
    IdSede        INT           IDENTITY (1, 1) NOT NULL,
    CodigoExterno VARCHAR (30)  NULL,
    NombreEstadio VARCHAR (120) NOT NULL,
    Ciudad        VARCHAR (80)  NOT NULL,
    IdPais        INT           NOT NULL,
    HusoHorario   VARCHAR (60)  NOT NULL,
    Capacidad     INT           NOT NULL,
    CONSTRAINT PK_Sede PRIMARY KEY (IdSede),
    CONSTRAINT UQ_Sede_CodigoExterno UNIQUE (CodigoExterno),
    CONSTRAINT UQ_Sede_NombreEstadio UNIQUE (NombreEstadio),
    CONSTRAINT FK_Sede_Pais FOREIGN KEY (IdPais) REFERENCES Torneo.Pais (IdPais),
    CONSTRAINT CK_Sede_CapacidadPositiva CHECK (Capacidad > 0)
);


GO
CREATE TABLE Torneo.Seleccion (
    IdSeleccion   INT          IDENTITY (1, 1) NOT NULL,
    CodigoExterno VARCHAR (30) NULL,
    IdPais        INT          NOT NULL,
    Grupo         CHAR (1)     NOT NULL,
    CONSTRAINT PK_Seleccion PRIMARY KEY (IdSeleccion),
    CONSTRAINT UQ_Seleccion_CodigoExterno UNIQUE (CodigoExterno),
    CONSTRAINT UQ_Seleccion_IdPais UNIQUE (IdPais),
    CONSTRAINT FK_Seleccion_Pais FOREIGN KEY (IdPais) REFERENCES Torneo.Pais (IdPais),
    CONSTRAINT CK_Seleccion_Grupo CHECK (Grupo IN (
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L'
    ))
);


GO
CREATE TABLE Torneo.Partido (
    IdPartido               INT          IDENTITY (1, 1) NOT NULL,
    CodigoExterno           VARCHAR (30) NULL,
    NumeroPartido           INT          NOT NULL,
    Fase                    VARCHAR (20) NOT NULL,
    IdSede                  INT          NOT NULL,
    IdSeleccionLocal        INT          NULL,
    IdSeleccionVisitante    INT          NULL,
    EsquemaTacticoLocal     VARCHAR (20) NULL,
    EsquemaTacticoVisitante VARCHAR (20) NULL,
    FechaHoraUtc            DATETIME2    NOT NULL,
    FechaHoraLocal          DATETIME2    NOT NULL,
    Estado                  VARCHAR (20) NOT NULL,
    GolesLocal              INT          NULL,
    GolesVisitante          INT          NULL,
    PenalesLocal            INT          NULL,
    PenalesVisitante        INT          NULL,
    Asistencia              INT          NULL,
    CONSTRAINT PK_Partido PRIMARY KEY (IdPartido),
    CONSTRAINT UQ_Partido_CodigoExterno UNIQUE (CodigoExterno),
    CONSTRAINT UQ_Partido_NumeroPartido UNIQUE (NumeroPartido),
    CONSTRAINT FK_Partido_Sede FOREIGN KEY (IdSede) REFERENCES Torneo.Sede (IdSede),
    CONSTRAINT FK_Partido_Seleccion_Local FOREIGN KEY (IdSeleccionLocal) REFERENCES Torneo.Seleccion (IdSeleccion),
    CONSTRAINT FK_Partido_Seleccion_Visitante FOREIGN KEY (IdSeleccionVisitante) REFERENCES Torneo.Seleccion (IdSeleccion),
    CONSTRAINT CK_Partido_Fase CHECK (Fase IN (
        'Grupos',
        'Dieciseisavos',
        'Octavos',
        'Cuartos',
        'Semifinal',
        'Tercer puesto',
        'Final'
    )),
    CONSTRAINT CK_Partido_Estado CHECK (Estado IN (
        'Programado',
        'En juego',
        'Finalizado',
        'Suspendido'
    )),
    CONSTRAINT CK_Partido_SeleccionesDistintas CHECK (IdSeleccionLocal <> IdSeleccionVisitante),
    CONSTRAINT CK_Partido_GolesNoNegativos CHECK (GolesLocal >= 0
                                                  AND GolesVisitante >= 0),
    CONSTRAINT CK_Partido_PenalesNoNegativos CHECK (PenalesLocal >= 0
                                                    AND PenalesVisitante >= 0),
    CONSTRAINT CK_Partido_AsistenciaNoNegativa CHECK (Asistencia >= 0)
);


GO
CREATE TABLE Torneo.Jugador (
    IdJugador          INT           IDENTITY (1, 1) NOT NULL,
    CodigoExterno      VARCHAR (30)  NULL,
    Nombre             VARCHAR (80)  NOT NULL,
    Apellido           VARCHAR (80)  NOT NULL,
    FechaNacimiento    DATE          NULL,
    IdPais             INT           NOT NULL,
    IdSeleccion        INT           NOT NULL,
    Dorsal             TINYINT       NOT NULL,
    PosicionHabitual   VARCHAR (5)   NOT NULL,
    ClubOrigen         VARCHAR (120) NOT NULL,
    FechaAlta          DATE          NOT NULL,
    FechaBaja          DATE          NULL,
    MotivoBaja         VARCHAR (100) NULL,
    IdJugadorReemplazo INT           NULL,
    CONSTRAINT PK_Jugador PRIMARY KEY (IdJugador),
    CONSTRAINT UQ_Jugador_CodigoExterno UNIQUE (CodigoExterno),
    CONSTRAINT UQ_Jugador_Seleccion_Dorsal UNIQUE (IdSeleccion, Dorsal),
    CONSTRAINT FK_Jugador_Pais FOREIGN KEY (IdPais) REFERENCES Torneo.Pais (IdPais),
    CONSTRAINT FK_Jugador_Seleccion FOREIGN KEY (IdSeleccion) REFERENCES Torneo.Seleccion (IdSeleccion),
    CONSTRAINT FK_Jugador_JugadorReemplazo FOREIGN KEY (IdJugadorReemplazo) REFERENCES Torneo.Jugador (IdJugador),
    CONSTRAINT CK_Jugador_PosicionHabitual CHECK (PosicionHabitual IN (
        'POR',
        'DEF',
        'MED',
        'DEL'
    ))
);


GO
CREATE TABLE Torneo.CuerpoTecnico (
    IdCuerpoTecnico INT          IDENTITY (1, 1) NOT NULL,
    IdSeleccion     INT          NOT NULL,
    Nombre          VARCHAR (80) NOT NULL,
    Apellido        VARCHAR (80) NOT NULL,
    Rol             VARCHAR (30) NOT NULL,
    CONSTRAINT PK_CuerpoTecnico PRIMARY KEY (IdCuerpoTecnico),
    CONSTRAINT FK_CuerpoTecnico_Seleccion FOREIGN KEY (IdSeleccion) REFERENCES Torneo.Seleccion (IdSeleccion),
    CONSTRAINT CK_CuerpoTecnico_Rol CHECK (Rol IN (
        'Director tecnico',
        'Ayudante'
    ))
);


GO