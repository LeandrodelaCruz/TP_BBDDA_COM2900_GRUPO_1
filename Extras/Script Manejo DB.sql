	/*
	Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodríguez, Elías Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026
	*/


-- Primero, cambiar a otra base de datos
USE master;
GO

-- Luego forzar el drop terminando conexiones activas
ALTER DATABASE MUNDIALDEFUTBOL SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE MUNDIALDEFUTBOL SET MULTI_USER;
GO

--Verificar el estado de la base de datos
SELECT name, state_desc, user_access_desc 
FROM sys.databases 
WHERE name = 'MUNDIALDEFUTBOL';

-- Finalmente eliminar
DROP DATABASE MUNDIALDEFUTBOL;
GO

-- Para crear de nuevo 
CREATE DATABASE MUNDIALDEFUTBOL;
GO

