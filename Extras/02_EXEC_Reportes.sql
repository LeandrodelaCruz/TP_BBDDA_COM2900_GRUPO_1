USE MUNDIALDEFUTBOL;
EXEC reportes.Reporte_Ocupacion_Publicitaria;
EXEC reportes.Reporte_Matriz_Prime_Time;
EXEC reportes.Reporte_Designaciones_Arbitrales_XML;
EXEC reportes.Reporte_Selecciones_Plantillas_XML;
EXEC reportes.Goleadores_Por_Seleccion;
EXEC reportes.Goleadores_Por_Fase;
EXEC reportes.Goleadores_Por_Torneo;
EXEC reportes.Tarjetas_Por_Seleccion;
EXEC reportes.Tarjetas_Por_Jugador;
EXEC reportes.Reporte_Resultados;
EXEC reportes.Reporte_Fixture;
EXEC reportes.Reporte_Historial_Titularidad 55;


EXEC reportes.Reporte_Equipo_En_Cancha 1,1,'PRIMER TIEMPO',5;
EXEC reportes.Reporte_Equipo_En_Cancha 1,1,'PRIMER TIEMPO',25;
EXEC reportes.Reporte_Equipo_En_Cancha 1,1,'SEGUNDO TIEMPO',75;

SELECT * FROM reportes.v_Goles_Por_Seleccion;
SELECT * FROM reportes.v_Tarjetas_Por_Seleccion;