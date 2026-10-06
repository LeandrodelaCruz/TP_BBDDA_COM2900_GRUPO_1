USE MUNDIALDEFUTBOL;
GO

delete dbo.Reemplazo
delete dbo.Partido_Seleccion
delete dbo.Partido
delete dbo.Formacion
delete dbo.Formacion_Jugador 

SELECT TOP (4) [id_reemplazo]
      ,[id_jugador_baja]
      ,[id_jugador_alta]
      ,[fecha_cambio]
      ,[motivo]
  FROM [MUNDIALDEFUTBOL].[dbo].[Reemplazo]

SELECT TOP (4) [id_partido]
      ,[id_seleccion]
  FROM [MUNDIALDEFUTBOL].[dbo].[Partido_Seleccion]

SELECT TOP (4) [id_partido]
      ,[id_sede]
      ,[fecha]
      ,[horario_local]
      ,[horario_UTC]
      ,[fase]
      ,[resultado_final]
      ,[asistencia_publico]
  FROM [MUNDIALDEFUTBOL].[dbo].[Partido]
  
SELECT TOP (4) [id_formacion]
      ,[id_partido]
      ,[id_seleccion]
      ,[esquema_tactico]
  FROM [MUNDIALDEFUTBOL].[dbo].[Formacion]

SELECT TOP (4) [id_formacion]
      ,[id_jugador]
      ,[posicion_en_cancha]
      ,[dorsal_en_cancha]
      ,[es_titular]
  FROM [MUNDIALDEFUTBOL].[dbo].[Formacion_Jugador]