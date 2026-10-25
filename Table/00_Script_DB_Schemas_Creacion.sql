/*

    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01: 
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel

    Descripción:
    Script de creación de tablas y restricciones
    del Sistema de Registro y Gestión del Mundial.
*/

USE master;
GO

-- 1. Crear la Base de Datos si no existe
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'MUNDIALDEFUTBOL')
BEGIN
    CREATE DATABASE MUNDIALDEFUTBOL;
END
GO

-- 2. Usar la base de datos creada
USE MUNDIALDEFUTBOL;
GO

-- 3. Crear el esquema 'abm' si no existe
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'abm')
BEGIN
    EXEC('CREATE SCHEMA abm;');
END
GO

-- 4. Crear el esquema 'test' si no existe
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'test')
BEGIN
    EXEC('CREATE SCHEMA test;');
END
GO
