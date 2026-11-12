-- Cantidad de intentos por fecha y estado (todos los intentos, todas las fechas cargadas).
-- Sin filtro de fechas: la misma consulta sirve para la etapa inicial (días 1-2) y la final (días 1-3).
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM final_entregas.entregas
GROUP BY fecha, estado
ORDER BY fecha ASC, estado ASC;
