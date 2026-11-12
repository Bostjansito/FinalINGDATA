-- Total de registros consultables y desglose por fecha (verificación adicional de cada etapa).
-- Etapa inicial: 12 registros (2026-10-01 y 2026-10-02). Etapa final: 18 registros.
SELECT
    fecha,
    COUNT(*) AS registros
FROM final_entregas.entregas
GROUP BY fecha
UNION ALL
SELECT
    'TOTAL' AS fecha,
    COUNT(*) AS registros
FROM final_entregas.entregas
ORDER BY fecha ASC;
