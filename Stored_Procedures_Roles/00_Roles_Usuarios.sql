/*
    Universidad Nacional de La Matanza - UNLaM.
    Materia: Bases de Datos Aplicada - 2C-2026. Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
    de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 10/11/2026. Entrega 8: usuarios, roles y permisos.
    Objetivo: Crear los SP de configuracion de roles y usuarios, sin ejecutar la configuracion.
*/
USE MUNDIALDEFUTBOL;
GO
SET NOCOUNT ON;
GO
-- Ejecutar como dbo o un DBA con permisos de creacion de procedimientos.
-- No se usa EXECUTE AS OWNER: estos SP no elevan los permisos del llamador.
-- No se otorga EXECUTE sobre estos SP a ninguno de los tres roles.
CREATE OR ALTER PROCEDURE dbo.Configurar_Roles_Entrega8
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0
        THROW 58000, N'Ejecute la configuracion sin una transaccion abierta.', 1;
    IF USER_NAME() <> N'dbo' AND IS_MEMBER(N'db_owner') <> 1
        THROW 58001, N'La configuracion de seguridad requiere un DBA.', 1;
    IF SCHEMA_ID(N'abm') IS NULL OR SCHEMA_ID(N'negocio') IS NULL
       OR SCHEMA_ID(N'importacion') IS NULL OR SCHEMA_ID(N'carga') IS NULL
       OR SCHEMA_ID(N'reportes') IS NULL
        THROW 58002, N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
    -- Los GRANT por objeto requieren que los SP ya esten instalados.
    IF OBJECT_ID(N'abm.Anunciante_Alta', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Anunciante_Alta.', 1;
    IF OBJECT_ID(N'abm.Anunciante_Modificar', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Anunciante_Modificar.', 1;
    IF OBJECT_ID(N'abm.Anunciante_Baja', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Anunciante_Baja.', 1;
    IF OBJECT_ID(N'abm.Anunciante_ConsultarPorId', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Anunciante_ConsultarPorId.', 1;
    IF OBJECT_ID(N'abm.Anunciante_Listar', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Anunciante_Listar.', 1;
    IF OBJECT_ID(N'abm.Region_Alta', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Region_Alta.', 1;
    IF OBJECT_ID(N'abm.Region_Modificar', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Region_Modificar.', 1;
    IF OBJECT_ID(N'abm.Region_Baja', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Region_Baja.', 1;
    IF OBJECT_ID(N'abm.Region_ConsultarPorId', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Region_ConsultarPorId.', 1;
    IF OBJECT_ID(N'abm.Region_Listar', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Region_Listar.', 1;
    IF OBJECT_ID(N'abm.Campania_Alta', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Campania_Alta.', 1;
    IF OBJECT_ID(N'abm.Campania_Modificar', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Campania_Modificar.', 1;
    IF OBJECT_ID(N'abm.Campania_Baja', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Campania_Baja.', 1;
    IF OBJECT_ID(N'abm.Pieza_Publicitaria_Alta', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Pieza_Publicitaria_Alta.', 1;
    IF OBJECT_ID(N'abm.Pieza_Publicitaria_Modificar', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Pieza_Publicitaria_Modificar.', 1;
    IF OBJECT_ID(N'abm.Pieza_Publicitaria_Baja', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Pieza_Publicitaria_Baja.', 1;
    IF OBJECT_ID(N'abm.Pieza_Para_Region_Alta', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Pieza_Para_Region_Alta.', 1;
    IF OBJECT_ID(N'abm.Pieza_Para_Region_Baja', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Pieza_Para_Region_Baja.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_Alta', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_Alta.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_GetById', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_GetById.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_GetByPartido', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_GetByPartido.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_GetByAnunciante', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_GetByAnunciante.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_TotalesPorAnunciante', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_TotalesPorAnunciante.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_Modificacion', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_Modificacion.', 1;
    IF OBJECT_ID(N'abm.Asignacion_Publicitaria_Baja', N'P') IS NULL
        THROW 58003, N'Falta instalar abm.Asignacion_Publicitaria_Baja.', 1;
    IF OBJECT_ID(N'negocio.Generar_Asignacion_Publicitaria', N'P') IS NULL
        THROW 58003, N'Falta instalar negocio.Generar_Asignacion_Publicitaria.', 1;
    IF OBJECT_ID(N'reportes.Reporte_Ocupacion_Publicitaria', N'P') IS NULL
        THROW 58003, N'Falta instalar reportes.Reporte_Ocupacion_Publicitaria.', 1;
    IF OBJECT_ID(N'reportes.Reporte_Matriz_Prime_Time', N'P') IS NULL
        THROW 58003, N'Falta instalar reportes.Reporte_Matriz_Prime_Time.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF DATABASE_PRINCIPAL_ID(N'rol_admin_funcional') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'rol_admin_funcional' AND type='R' AND is_fixed_role=0)
            THROW 58004, N'Nombre de rol ocupado por otro tipo de principal: rol_admin_funcional.', 1;
        IF DATABASE_PRINCIPAL_ID(N'rol_admin_funcional') IS NULL
            CREATE ROLE rol_admin_funcional AUTHORIZATION dbo;
        IF DATABASE_PRINCIPAL_ID(N'rol_gestor_publicidad') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'rol_gestor_publicidad' AND type='R' AND is_fixed_role=0)
            THROW 58004, N'Nombre de rol ocupado por otro tipo de principal: rol_gestor_publicidad.', 1;
        IF DATABASE_PRINCIPAL_ID(N'rol_gestor_publicidad') IS NULL
            CREATE ROLE rol_gestor_publicidad AUTHORIZATION dbo;
        IF DATABASE_PRINCIPAL_ID(N'rol_consulta') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'rol_consulta' AND type='R' AND is_fixed_role=0)
            THROW 58004, N'Nombre de rol ocupado por otro tipo de principal: rol_consulta.', 1;
        IF DATABASE_PRINCIPAL_ID(N'rol_consulta') IS NULL
            CREATE ROLE rol_consulta AUTHORIZATION dbo;
            --ADMIN FUNCIONAL
        GRANT EXECUTE ON SCHEMA::abm TO rol_admin_funcional;
        GRANT EXECUTE ON SCHEMA::negocio TO rol_admin_funcional;
        GRANT EXECUTE ON SCHEMA::importacion TO rol_admin_funcional;
        GRANT EXECUTE ON SCHEMA::carga TO rol_admin_funcional;
        GRANT EXECUTE ON SCHEMA::reportes TO rol_admin_funcional;
        --GESTOR PUBLICIDAD
        GRANT EXECUTE ON OBJECT::abm.Anunciante_Alta TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Anunciante_Modificar TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Anunciante_Baja TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Anunciante_ConsultarPorId TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Anunciante_Listar TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Region_Alta TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Region_Modificar TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Region_Baja TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Region_ConsultarPorId TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Region_Listar TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Campania_Alta TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Campania_Modificar TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Campania_Baja TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Pieza_Publicitaria_Alta TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Pieza_Publicitaria_Modificar TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Pieza_Publicitaria_Baja TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Pieza_Para_Region_Alta TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Pieza_Para_Region_Baja TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_Alta TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_GetById TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_GetByPartido TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_GetByAnunciante TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_TotalesPorAnunciante TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_Modificacion TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::abm.Asignacion_Publicitaria_Baja TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::negocio.Generar_Asignacion_Publicitaria TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::reportes.Reporte_Ocupacion_Publicitaria TO rol_gestor_publicidad;
        GRANT EXECUTE ON OBJECT::reportes.Reporte_Matriz_Prime_Time TO rol_gestor_publicidad;
        --CONSULTA
        GRANT EXECUTE ON SCHEMA::reportes TO rol_consulta;
        -- El acceso a las tablas se realiza dentro de SP con el mismo propietario.
        DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_admin_funcional;
        DENY EXECUTE ON OBJECT::dbo.Configurar_Roles_Entrega8 TO rol_admin_funcional;
        DENY ALTER ANY ROLE, ALTER ANY USER, CREATE TABLE, CREATE PROCEDURE TO rol_admin_funcional;
        -- El acceso a las tablas se realiza dentro de SP con el mismo propietario.
        DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_gestor_publicidad;
        DENY EXECUTE ON OBJECT::dbo.Configurar_Roles_Entrega8 TO rol_gestor_publicidad;
        DENY ALTER ANY ROLE, ALTER ANY USER, CREATE TABLE, CREATE PROCEDURE TO rol_gestor_publicidad;
        -- El acceso a las tablas se realiza dentro de SP con el mismo propietario.
        DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_consulta;
        DENY EXECUTE ON OBJECT::dbo.Configurar_Roles_Entrega8 TO rol_consulta;
        DENY ALTER ANY ROLE, ALTER ANY USER, CREATE TABLE, CREATE PROCEDURE TO rol_consulta;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Crear_Usuarios_Prueba_Entrega8
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 58010, N'Ejecute la creacion de usuarios sin transaccion abierta.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1
            FROM sys.database_principals
            WHERE name IN (N'usr_prueba_admin', N'usr_prueba_publicidad', N'usr_prueba_consulta')
              AND (type <> 'S' OR authentication_type <> 0)
        )
            THROW 58013, N'Un nombre reservado para las pruebas ya existe y no corresponde a un usuario WITHOUT LOGIN.', 1;

        IF USER_ID(N'usr_prueba_admin') IS NULL
            CREATE USER usr_prueba_admin WITHOUT LOGIN WITH DEFAULT_SCHEMA = dbo;
        IF NOT EXISTS (
            SELECT 1 FROM sys.database_role_members
            WHERE role_principal_id = DATABASE_PRINCIPAL_ID(N'rol_admin_funcional')
              AND member_principal_id = USER_ID(N'usr_prueba_admin')
        )
            ALTER ROLE rol_admin_funcional ADD MEMBER usr_prueba_admin;

        IF USER_ID(N'usr_prueba_publicidad') IS NULL
            CREATE USER usr_prueba_publicidad WITHOUT LOGIN WITH DEFAULT_SCHEMA = dbo;
        IF NOT EXISTS (
            SELECT 1 FROM sys.database_role_members
            WHERE role_principal_id = DATABASE_PRINCIPAL_ID(N'rol_gestor_publicidad')
              AND member_principal_id = USER_ID(N'usr_prueba_publicidad')
        )
            ALTER ROLE rol_gestor_publicidad ADD MEMBER usr_prueba_publicidad;

        IF USER_ID(N'usr_prueba_consulta') IS NULL
            CREATE USER usr_prueba_consulta WITHOUT LOGIN WITH DEFAULT_SCHEMA = dbo;
        IF NOT EXISTS (
            SELECT 1 FROM sys.database_role_members
            WHERE role_principal_id = DATABASE_PRINCIPAL_ID(N'rol_consulta')
              AND member_principal_id = USER_ID(N'usr_prueba_consulta')
        )
            ALTER ROLE rol_consulta ADD MEMBER usr_prueba_consulta;

        DENY EXECUTE ON OBJECT::dbo.Crear_Usuarios_Prueba_Entrega8 TO rol_admin_funcional;
        DENY EXECUTE ON OBJECT::dbo.Crear_Usuarios_Prueba_Entrega8 TO rol_gestor_publicidad;
        DENY EXECUTE ON OBJECT::dbo.Crear_Usuarios_Prueba_Entrega8 TO rol_consulta;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
