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

