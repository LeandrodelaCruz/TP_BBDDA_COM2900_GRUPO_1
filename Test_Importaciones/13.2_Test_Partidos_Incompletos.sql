/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 08/11/2026. Importacion parcial: rechazar participantes faltantes y continuar.
 Resultado esperado: 0 filas del archivo incompleto y 2 filas validas del segundo archivo.
*/
USE MUNDIALDEFUTBOL;
GO
-- Ejecutar en MUNDIALDEFUTBOL: conserva su escenario para inspeccion.
CREATE OR ALTER PROCEDURE test.Partidos_Incompletos_JSON
    @archivo_incompleto NVARCHAR(1000),@archivo_mixto NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM dbo.Sede WHERE nombre_estadio=N'TPP_Estadio')
        THROW 59990,N'El escenario TPP ya existe.',1;
    INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario)
        VALUES(N'TPP_Estadio',N'TPP_Ciudad',N'TPP_Pais',5000,'UTC');
    DECLARE @sede INT=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TPP_A','UEFA','A'),(N'TPP_B','UEFA','B');
    EXEC importacion.Importar_Partido_JSON @archivo_incompleto;
    IF EXISTS(SELECT 1 FROM dbo.Partido WHERE id_sede=@sede)
        THROW 59999,N'Se acepto un partido sin participantes.',1;
    EXEC importacion.Importar_Partido_JSON @archivo_mixto;
    IF @@TRANCOUNT<>0 THROW 59999,N'Una fila invalida dejo una transaccion abierta.',1;
    IF (SELECT COUNT(*) FROM dbo.Partido WHERE id_sede=@sede)<>2
        THROW 59999,N'No se conservaron exclusivamente las dos filas validas.',1;
    EXEC importacion.Importar_Partido_JSON @archivo_mixto;
    IF (SELECT COUNT(*) FROM dbo.Partido WHERE id_sede=@sede)<>2
        THROW 59999,N'La repeticion duplico partidos.',1;
    PRINT N'OK: participantes faltantes rechazados, errores parciales y repeticion sin duplicados.';
END;
GO
