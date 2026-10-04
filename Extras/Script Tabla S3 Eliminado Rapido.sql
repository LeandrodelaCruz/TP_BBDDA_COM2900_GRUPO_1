USE MundialDB;
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
  FROM [MundialDB].[dbo].[Reemplazo]

SELECT TOP (4) [id_partido]
      ,[id_seleccion]
  FROM [MundialDB].[dbo].[Partido_Seleccion]

SELECT TOP (4) [id_partido]
      ,[id_sede]
      ,[fecha]
      ,[horario_local]
      ,[horario_UTC]
      ,[fase]
      ,[resultado_final]
      ,[asistencia_publico]
  FROM [MundialDB].[dbo].[Partido]
  
SELECT TOP (4) [id_formacion]
      ,[id_partido]
      ,[id_seleccion]
      ,[esquema_tactico]
  FROM [MundialDB].[dbo].[Formacion]

SELECT TOP (4) [id_formacion]
      ,[id_jugador]
      ,[posicion_en_cancha]
      ,[dorsal_en_cancha]
      ,[es_titular]
  FROM [MundialDB].[dbo].[Formacion_Jugador]