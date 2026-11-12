-- Resumen diario: una fila por fecha de negocio.
-- ingreso_total se calcula sobre DECIMAL(12,2) para conservar la precisión (sin pasar por float).
select
    fecha_venta,
    count(id_venta)                 as numero_ventas,
    sum(cantidad)                   as unidades_vendidas,
    sum(cantidad * precio_unitario) as ingreso_total
from {{ ref('stg_ventas') }}
group by fecha_venta
