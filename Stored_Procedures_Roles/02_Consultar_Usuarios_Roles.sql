/*
    Universidad Nacional de La Matanza - UNLaM.
    Materia: Bases de Datos Aplicada - 2C-2026. Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
    de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 10/11/2026. Entrega 8: usuarios, roles y permisos.
    Objetivo: Mostrar usuarios, membresias directas y permisos declarados de los roles.
*/
USE MUNDIALDEFUTBOL;
GO
SET NOCOUNT ON;
GO
-- Consulta de catalogo desde una conexion DBA para ver todos los usuarios.
-- NULL muestra los tres usuarios; indicar uno para filtrar.
DECLARE @usuario SYSNAME = NULL;

SELECT u.name AS Usuario, u.authentication_type_desc AS Autenticacion,
       r.name AS Rol, u.default_schema_name AS Esquema_Predeterminado
FROM sys.database_principals u
LEFT JOIN sys.database_role_members m ON m.member_principal_id=u.principal_id
LEFT JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
WHERE u.name IN (N'usr_prueba_admin',N'usr_prueba_publicidad',N'usr_prueba_consulta')
  AND (@usuario IS NULL OR u.name=@usuario)
ORDER BY u.name,r.name;

-- Permisos declarados en cada rol: no confundir con permisos efectivos.
SELECT r.name AS Rol, p.state_desc AS Estado, p.permission_name AS Permiso,
       p.class_desc AS Ambito,
       CASE p.class WHEN 0 THEN DB_NAME()
                    WHEN 3 THEN SCHEMA_NAME(p.major_id)
                    WHEN 1 THEN OBJECT_SCHEMA_NAME(p.major_id)+N'.'+OBJECT_NAME(p.major_id)
       END AS Recurso
FROM sys.database_permissions p
JOIN sys.database_principals r ON r.principal_id=p.grantee_principal_id
WHERE r.name IN (N'rol_admin_funcional',N'rol_gestor_publicidad',N'rol_consulta')
ORDER BY r.name,p.class,p.major_id,p.permission_name;
-- Todos los usuarios tambien pertenecen implicitamente a public.
GO
