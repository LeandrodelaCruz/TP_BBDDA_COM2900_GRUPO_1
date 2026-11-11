/*
    Universidad Nacional de La Matanza - UNLaM.
    Materia: Bases de Datos Aplicada - 2C-2026. Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
    de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 10/11/2026. Entrega 8: usuarios, roles y permisos.
    Objetivo: Configurar los tres roles y asociar un usuario de prueba a cada uno.
*/
USE MUNDIALDEFUTBOL;
GO
SET NOCOUNT ON;
GO
-- Requisitos: tablas y todos los SP del proyecto instalados; ejecutar como DBA.
-- Puede repetirse. No elimina usuarios, roles ni permisos preexistentes.
EXEC dbo.Configurar_Roles_Entrega8;
EXEC dbo.Crear_Usuarios_Prueba_Entrega8;
GO
