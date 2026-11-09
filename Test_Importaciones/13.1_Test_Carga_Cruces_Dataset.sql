/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Prueba sobre el fixture local importado. No genera resultados ni ganadores.
-- Esperado: 32 relaciones tanto en la primera llamada como en la segunda.
EXEC carga.Cargar_Cruces_Dataset;
DECLARE @antes INT=(SELECT COUNT(*) FROM dbo.Cruce_Partido);
EXEC carga.Cargar_Cruces_Dataset;
IF @antes<>32 OR (SELECT COUNT(*) FROM dbo.Cruce_Partido)<>32
    THROW 59999,N'El mapa no coincide con las 32 relaciones del fixture local.',1;
SELECT * FROM dbo.Cruce_Partido ORDER BY id_partido_destino,posicion_destino;
GO
