-- Verificación de la nueva fecha (2026-10-03) sin registrar particiones.
-- Cada sentencia se ejecuta por separado en Athena (scripts/athena.sh <etapa> <sql> <resultado> <n>).

-- 1) Los seis registros del tercer día -> resultados/final/verificacion_tercer_dia.csv
SELECT
    fecha,
    id_envio,
    ciudad,
    transportadora,
    estado,
    duracion_minutos
FROM final_entregas.entregas
WHERE fecha = '2026-10-03'
ORDER BY id_envio ASC;

-- 2) Conteos por estado del tercer día -> resultados/final/conteos_estado_tercer_dia.csv
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM final_entregas.entregas
WHERE fecha = '2026-10-03'
GROUP BY fecha, estado
ORDER BY estado ASC;

-- 3) Total de la tabla y registros por fecha -> resultados/final/total_registros_tabla.csv
SELECT
    COUNT(*)                                            AS total_registros,
    COUNT(DISTINCT fecha)                               AS fechas_con_datos,
    SUM(CASE WHEN fecha = '2026-10-01' THEN 1 ELSE 0 END) AS registros_2026_10_01,
    SUM(CASE WHEN fecha = '2026-10-02' THEN 1 ELSE 0 END) AS registros_2026_10_02,
    SUM(CASE WHEN fecha = '2026-10-03' THEN 1 ELSE 0 END) AS registros_2026_10_03
FROM final_entregas.entregas;
