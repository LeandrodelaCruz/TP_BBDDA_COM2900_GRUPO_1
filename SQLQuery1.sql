EXEC importacion.SP_Importar_Arbitro_PDF_CSV
    @archivo = N'C:\Users\elias\Downloads\TP BDA\TP_BBDDA_COM2900_GRUPO_1\Archivos_Importacion\arbitros_fifa_pdf.csv';

    select * from dbo.Arbitro 
    go

    EXEC importacion.SP_Importar_Arbitro_PDF_CSV_SetBased
    @archivo = N'C:\Users\elias\Downloads\TP BDA\TP_BBDDA_COM2900_GRUPO_1\Archivos_Importacion\arbitros_fifa_pdf.csv';