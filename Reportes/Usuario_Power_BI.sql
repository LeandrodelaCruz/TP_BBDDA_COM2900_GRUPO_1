USE master;
GO
IF SUSER_ID(N'pbi_mundial') IS NULL
    CREATE LOGIN [pbi_mundial]
        WITH PASSWORD = 'Contraseña_Segura_10%',
             CHECK_POLICY = ON;
GO

USE MUNDIALDEFUTBOL;
GO
IF USER_ID(N'pbi_mundial') IS NULL
    CREATE USER [pbi_mundial] FOR LOGIN [pbi_mundial];
GO

GRANT SELECT ON OBJECT::reportes.v_Goles_Por_Fase TO [pbi_mundial];
GRANT SELECT ON OBJECT::reportes.v_Goles_Por_Fase_Jugador TO [pbi_mundial];
GRANT SELECT ON OBJECT::reportes.v_Goles_Por_Jugador TO [pbi_mundial];
GRANT SELECT ON OBJECT::reportes.v_Goles_Por_Seleccion TO [pbi_mundial];
GRANT SELECT ON OBJECT::reportes.v_Tarjetas_Por_Jugador TO [pbi_mundial];
GRANT SELECT ON OBJECT::reportes.v_Tarjetas_Por_Seleccion TO [pbi_mundial];
GRANT SELECT ON OBJECT::dbo.Sede TO [pbi_mundial];

-- Solo si esta cuenta también tiene que ejecutar los SP de reportes.
-- ALTER ROLE [rol_consulta] ADD MEMBER [pbi_mundial];