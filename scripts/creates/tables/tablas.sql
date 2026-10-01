/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripción:
    Script de creación de tablas y restricciones
    del Sistema de Registro y Gestión del Mundial.
*/

USE MundialDB;
GO


/* =========================================================
   1. TABLAS INDEPENDIENTES
   ========================================================= */

IF OBJECT_ID('dbo.Anunciante', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Anunciante
    (
        id_anunciante INT IDENTITY(1,1) NOT NULL,
        nombre NVARCHAR(120) NOT NULL,

        CONSTRAINT PK_Anunciante
            PRIMARY KEY (id_anunciante),

        CONSTRAINT UQ_Anunciante_Nombre
            UNIQUE (nombre)
    );
END;
GO


IF OBJECT_ID('dbo.Region', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Region
    (
        id_region INT IDENTITY(1,1) NOT NULL,
        nombre NVARCHAR(80) NOT NULL,
        idioma NVARCHAR(50) NULL,
        huso_horario NVARCHAR(100) NOT NULL,
        hora_prime_inicio TIME(0) NOT NULL,
        hora_prime_fin TIME(0) NOT NULL,

        CONSTRAINT PK_Region
            PRIMARY KEY (id_region),

        CONSTRAINT CK_Region_PrimeTime
            CHECK (hora_prime_inicio < hora_prime_fin),

        CONSTRAINT CK_Hora_Prime_Inicio_Mayor_Cero
            CHECK (hora_prime_inicio > 0),

        CONSTRAINT CK_Hora_Prime_Fin_Mayor_Cero
            CHECK (hora_prime_fin > 0)
    );
END;
GO


IF OBJECT_ID('dbo.Sede', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sede
    (
        id_sede INT IDENTITY(1,1) NOT NULL,
        nombre_estadio NVARCHAR(120) NOT NULL,
        ciudad NVARCHAR(80) NOT NULL,
        pais NVARCHAR(80) NOT NULL,
        capacidad INT NOT NULL,
        huso_horario NVARCHAR(100) NOT NULL,

        CONSTRAINT PK_Sede
            PRIMARY KEY (id_sede),

        CONSTRAINT CK_Sede_Capacidad
            CHECK (capacidad > 0)
    );
END;
GO


IF OBJECT_ID('dbo.Seleccion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Seleccion
    (
        id_seleccion INT IDENTITY(1,1) NOT NULL,
        pais NVARCHAR(80) NOT NULL,
        confederacion NVARCHAR(50) NOT NULL, --Conmebol / Uefa...
        grupo_asignado VARCHAR(5) NOT NULL,

        CONSTRAINT PK_Seleccion
            PRIMARY KEY (id_seleccion),

        CONSTRAINT UQ_Seleccion_Pais
            UNIQUE (pais)
    );
END;
GO


IF OBJECT_ID('dbo.Arbitro', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Arbitro
    (
        id_arbitro INT IDENTITY(1,1) NOT NULL,
        nombre NVARCHAR(60) NOT NULL,
        apellido NVARCHAR(60) NOT NULL,
        fecha_nacimiento DATE NOT NULL,
        pais NVARCHAR(80) NOT NULL,
        categoria NVARCHAR(50) NOT NULL,
        idiomas NVARCHAR(200) NULL,

        CONSTRAINT PK_Arbitro
            PRIMARY KEY (id_arbitro)
    );
END;
GO



/* =========================================================
   2. TABLAS QUE DEPENDEN DE LAS ANTERIORES
   ========================================================= */

IF OBJECT_ID('dbo.Campania', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Campania
    (
        id_campania INT IDENTITY(1,1) NOT NULL,
        id_anunciante INT NOT NULL,
        descripcion NVARCHAR(250) NOT NULL,

        CONSTRAINT PK_Campania
            PRIMARY KEY (id_campania),

        CONSTRAINT FK_Campania_Anunciante
            FOREIGN KEY (id_anunciante)
            REFERENCES dbo.Anunciante(id_anunciante)
    );
END;
GO


IF OBJECT_ID('dbo.Pieza_Publicitaria', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Pieza_Publicitaria
    (
        id_pieza INT IDENTITY(1,1) NOT NULL,
        id_campania INT NOT NULL,
        nombre NVARCHAR(120) NOT NULL,
        contenido NVARCHAR(500) NULL,
        idioma NVARCHAR(50) NOT NULL,

        CONSTRAINT PK_Pieza_Publicitaria
            PRIMARY KEY (id_pieza),

        CONSTRAINT FK_Pieza_Campania
            FOREIGN KEY (id_campania)
            REFERENCES dbo.Campania(id_campania)
    );
END;
GO


/* Relación N:N entre Pieza y Región */

IF OBJECT_ID('dbo.Pieza_Region', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Pieza_Region
    (
        id_pieza INT NOT NULL,
        id_region INT NOT NULL,

        CONSTRAINT PK_Pieza_Region
            PRIMARY KEY (id_pieza, id_region),

        CONSTRAINT FK_PiezaRegion_Pieza
            FOREIGN KEY (id_pieza)
            REFERENCES dbo.Pieza_Publicitaria(id_pieza),

        CONSTRAINT FK_PiezaRegion_Region
            FOREIGN KEY (id_region)
            REFERENCES dbo.Region(id_region)
    );
END;
GO



/* =========================================================
   3. SELECCIONES, CUERPO TÉCNICO Y JUGADORES
   ========================================================= */

IF OBJECT_ID('dbo.Personal_Tecnico', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Personal_Tecnico
    (
        id_personal INT IDENTITY(1,1) NOT NULL,
        id_seleccion INT NOT NULL,
        id_ayudante INT NULL,
        nombre NVARCHAR(60) NOT NULL,
        apellido NVARCHAR(60) NOT NULL,
        rol NVARCHAR(50) NOT NULL,

        CONSTRAINT PK_Personal_Tecnico
            PRIMARY KEY (id_personal),

        CONSTRAINT FK_Personal_Seleccion
            FOREIGN KEY (id_seleccion)
            REFERENCES dbo.Seleccion(id_seleccion),

        CONSTRAINT FK_Personal_Ayudante
            FOREIGN KEY (id_ayudante)
            REFERENCES dbo.Personal_Tecnico(id_personal)
    );
END;
GO


IF OBJECT_ID('dbo.Jugador', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Jugador
    (
        id_jugador INT IDENTITY(1,1) NOT NULL,
        id_seleccion INT NOT NULL,
        nombre NVARCHAR(60) NOT NULL,
        apellido NVARCHAR(60) NOT NULL,
        fecha_nacimiento DATE NOT NULL,
        club_origen NVARCHAR(100) NOT NULL,
        posicion NVARCHAR(40) NOT NULL,
        dorsal TINYINT NOT NULL,

        CONSTRAINT PK_Jugador
            PRIMARY KEY (id_jugador),

        CONSTRAINT FK_Jugador_Seleccion
            FOREIGN KEY (id_seleccion)
            REFERENCES dbo.Seleccion(id_seleccion),

        CONSTRAINT CK_Jugador_Dorsal
            CHECK (dorsal BETWEEN 1 AND 99)
    );
END;
GO


IF OBJECT_ID('dbo.Reemplazo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Reemplazo
    (
        id_reemplazo INT IDENTITY(1,1) NOT NULL,
        id_jugador_baja INT NOT NULL,
        id_jugador_alta INT NULL,
        fecha_cambio DATE NOT NULL,
        motivo NVARCHAR(200) NOT NULL,

        CONSTRAINT PK_Reemplazo
            PRIMARY KEY (id_reemplazo),

        CONSTRAINT FK_Reemplazo_JugadorBaja
            FOREIGN KEY (id_jugador_baja)
            REFERENCES dbo.Jugador(id_jugador),

        CONSTRAINT FK_Reemplazo_JugadorAlta
            FOREIGN KEY (id_jugador_alta)
            REFERENCES dbo.Jugador(id_jugador),

        CONSTRAINT CK_Reemplazo_JugadoresDistintos
            CHECK (
                id_jugador_alta IS NULL
                OR id_jugador_alta <> id_jugador_baja
            )
    );
END;
GO



/* =========================================================
   4. PARTIDOS
   ========================================================= */

IF OBJECT_ID('dbo.Partido', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Partido
    (
        id_partido INT IDENTITY(1,1) NOT NULL,
        id_sede INT NOT NULL,
        fecha DATE NOT NULL,
        horario_local DATETIME2(0) NOT NULL,
        horario_UTC DATETIME2(0) NOT NULL,
        fase NVARCHAR(30) NOT NULL,
        resultado_final NVARCHAR(20) NULL,
        asistencia_publico INT NULL,

        CONSTRAINT PK_Partido
            PRIMARY KEY (id_partido),

        CONSTRAINT FK_Partido_Sede
            FOREIGN KEY (id_sede)
            REFERENCES dbo.Sede(id_sede),

        CONSTRAINT CK_Partido_Asistencia
            CHECK (
                asistencia_publico IS NULL
                OR asistencia_publico >= 0
            )
    );
END;
GO


/* Relación N:N Partido - Selección */

IF OBJECT_ID('dbo.Partido_Seleccion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Partido_Seleccion
    (
        id_partido INT NOT NULL,
        id_seleccion INT NOT NULL,

        CONSTRAINT PK_Partido_Seleccion
            PRIMARY KEY (id_partido, id_seleccion),

        CONSTRAINT FK_PartidoSeleccion_Partido
            FOREIGN KEY (id_partido)
            REFERENCES dbo.Partido(id_partido),

        CONSTRAINT FK_PartidoSeleccion_Seleccion
            FOREIGN KEY (id_seleccion)
            REFERENCES dbo.Seleccion(id_seleccion)
    );
END;
GO



/* =========================================================
   5. FORMACIONES
   ========================================================= */

IF OBJECT_ID('dbo.Formacion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Formacion
    (
        id_formacion INT IDENTITY(1,1) NOT NULL,
        id_partido INT NOT NULL,
        id_seleccion INT NOT NULL,
        esquema_tactico VARCHAR(10) NOT NULL,

        CONSTRAINT PK_Formacion
            PRIMARY KEY (id_formacion),

        CONSTRAINT FK_Formacion_Partido
            FOREIGN KEY (id_partido)
            REFERENCES dbo.Partido(id_partido),

        CONSTRAINT FK_Formacion_Seleccion
            FOREIGN KEY (id_seleccion)
            REFERENCES dbo.Seleccion(id_seleccion),

        CONSTRAINT UQ_Formacion_PartidoSeleccion
            UNIQUE (id_partido, id_seleccion)
    );
END;
GO


/* Relación CONFORMA */

IF OBJECT_ID('dbo.Formacion_Jugador', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Formacion_Jugador
    (
        id_formacion INT NOT NULL,
        id_jugador INT NOT NULL,
        posicion_en_cancha NVARCHAR(40) NULL,
        dorsal_en_cancha TINYINT NOT NULL,
        es_titular BIT NOT NULL,

        CONSTRAINT PK_Formacion_Jugador
            PRIMARY KEY (id_formacion, id_jugador),

        CONSTRAINT FK_FormacionJugador_Formacion
            FOREIGN KEY (id_formacion)
            REFERENCES dbo.Formacion(id_formacion),

        CONSTRAINT FK_FormacionJugador_Jugador
            FOREIGN KEY (id_jugador)
            REFERENCES dbo.Jugador(id_jugador)
    );
END;
GO



/* =========================================================
   6. SUSTITUCIONES
   ========================================================= */

IF OBJECT_ID('dbo.Sustitucion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sustitucion
    (
        id_sustitucion INT IDENTITY(1,1) NOT NULL,
        id_partido INT NOT NULL,
        id_jugador_sale INT NOT NULL,
        id_jugador_entra INT NOT NULL,
        minuto SMALLINT NOT NULL,
        periodo NVARCHAR(30) NOT NULL,
        motivo NVARCHAR(100) NULL,
        numero_ventana TINYINT NULL,

        CONSTRAINT PK_Sustitucion
            PRIMARY KEY (id_sustitucion),

        CONSTRAINT FK_Sustitucion_Partido
            FOREIGN KEY (id_partido)
            REFERENCES dbo.Partido(id_partido),

        CONSTRAINT FK_Sustitucion_JugadorSale
            FOREIGN KEY (id_jugador_sale)
            REFERENCES dbo.Jugador(id_jugador),

        CONSTRAINT FK_Sustitucion_JugadorEntra
            FOREIGN KEY (id_jugador_entra)
            REFERENCES dbo.Jugador(id_jugador),

        CONSTRAINT CK_Sustitucion_JugadoresDistintos
            CHECK (id_jugador_sale <> id_jugador_entra),

        CONSTRAINT CK_Sustitucion_Minuto
            CHECK (minuto >= 0)
    );
END;
GO



/* =========================================================
   7. ÁRBITROS
   ========================================================= */

/* La relación PARTICIPA EN se convierte en tabla */

IF OBJECT_ID('dbo.Designacion_Arbitral', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Designacion_Arbitral
    (
        id_partido INT NOT NULL,
        id_arbitro INT NOT NULL,
        rol_arbitro NVARCHAR(30) NOT NULL,

        CONSTRAINT PK_Designacion_Arbitral
            PRIMARY KEY (id_partido, id_arbitro),

        CONSTRAINT FK_Designacion_Partido
            FOREIGN KEY (id_partido)
            REFERENCES dbo.Partido(id_partido),

        CONSTRAINT FK_Designacion_Arbitro
            FOREIGN KEY (id_arbitro)
            REFERENCES dbo.Arbitro(id_arbitro),

        CONSTRAINT CK_Designacion_Rol
            CHECK (
                rol_arbitro IN (
                    'PRINCIPAL',
                    'ASISTENTE',
                    'CUARTO ARBITRO',
                    'VAR'
                )
            )
    );
END;
GO


IF OBJECT_ID('dbo.Sancion_Arbitral', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sancion_Arbitral
    (
        id_sancion INT IDENTITY(1,1) NOT NULL,
        id_arbitro INT NOT NULL,
        id_partido INT NULL,
        fecha DATE NOT NULL,
        motivo NVARCHAR(300) NOT NULL,
        tipo_sancion NVARCHAR(50) NOT NULL,

        CONSTRAINT PK_Sancion_Arbitral
            PRIMARY KEY (id_sancion),

        CONSTRAINT FK_Sancion_Arbitro
            FOREIGN KEY (id_arbitro)
            REFERENCES dbo.Arbitro(id_arbitro),

        CONSTRAINT FK_Sancion_Partido
            FOREIGN KEY (id_partido)
            REFERENCES dbo.Partido(id_partido)
    );
END;
GO



/* =========================================================
   8. PUBLICIDAD
   ========================================================= */

IF OBJECT_ID('dbo.Espacio_Publicitario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Espacio_Publicitario
    (
        id_espacio_publicitario INT IDENTITY(1,1) NOT NULL,
        id_sede INT NOT NULL,
        numero_espacio TINYINT NOT NULL,

        CONSTRAINT PK_Espacio_Publicitario
            PRIMARY KEY (id_espacio_publicitario),

        CONSTRAINT FK_Espacio_Sede
            FOREIGN KEY (id_sede)
            REFERENCES dbo.Sede(id_sede),

        CONSTRAINT CK_Espacio_Numero
            CHECK (numero_espacio BETWEEN 1 AND 4),

        CONSTRAINT UQ_Espacio_SedeNumero
            UNIQUE (id_sede, numero_espacio)
    );
END;
GO


IF OBJECT_ID('dbo.Asignacion_Publicitaria', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Asignacion_Publicitaria
    (
        id_asignacion INT IDENTITY(1,1) NOT NULL,
        id_partido INT NOT NULL,
        id_espacio_publicitario INT NOT NULL,
        id_pieza INT NOT NULL,
        costo_aplicado DECIMAL(14,2) NOT NULL,

        CONSTRAINT PK_Asignacion_Publicitaria
            PRIMARY KEY (id_asignacion),

        CONSTRAINT FK_Asignacion_Partido
            FOREIGN KEY (id_partido)
            REFERENCES dbo.Partido(id_partido),

        CONSTRAINT FK_Asignacion_Espacio
            FOREIGN KEY (id_espacio_publicitario)
            REFERENCES dbo.Espacio_Publicitario(id_espacio_publicitario),

        CONSTRAINT FK_Asignacion_Pieza
            FOREIGN KEY (id_pieza)
            REFERENCES dbo.Pieza_Publicitaria(id_pieza),

        CONSTRAINT CK_Asignacion_Costo
            CHECK (costo_aplicado >= 0),

        /* Un espacio no puede tener dos piezas distintas
           asignadas para el mismo partido */
        CONSTRAINT UQ_Asignacion_PartidoEspacio
            UNIQUE (id_partido, id_espacio_publicitario)
    );
END;
GO