-- Porcentaje de entregas exitosas por fecha y ciudad: 100 * entregados / total de intentos del grupo.
-- El denominador incluye los tres estados. Se convierte a DOUBLE para evitar la división entera
-- y se presenta como DECIMAL(5,2) para conservar siempre dos decimales.
SELECT
    fecha,
    ciudad,
    CAST(
        ROUND(100 * CAST(SUM(CASE WHEN estado = 'entregado' THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*), 2)
        AS DECIMAL(5, 2)
    ) AS porcentaje_exito
FROM final_entregas.entregas
GROUP BY fecha, ciudad
ORDER BY fecha ASC, ciudad ASC;
