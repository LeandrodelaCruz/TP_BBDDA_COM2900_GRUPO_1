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
        huso_horario VARCHAR(100) NOT NULL,
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
        huso_horario VARCHAR(100) NOT NULL,

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
        puesto VARCHAR(50) NOT NULL,
        idiomas NVARCHAR(200) NULL,

        CONSTRAINT PK_Arbitro
            PRIMARY KEY (id_arbitro)
    );
END;
GO
