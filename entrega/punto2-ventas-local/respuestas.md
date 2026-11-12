# Respuestas conceptuales – Punto 2 (ventas diarias con control de actualidad)

## 1. ¿Por qué usar `_loaded_at` y no `fecha_venta` para este control?

Porque lo que se quiere saber es **si la carga llegó a tiempo**, no cuándo ocurrieron las ventas.
`fecha_venta` es una fecha del negocio: una venta del 10 de enero puede cargarse hoy, o una carga de
hoy puede traer solo ventas antiguas. Si midiéramos la frescura con `fecha_venta`, en este ejercicio la
fuente siempre aparecería "vieja" (las ventas son de enero de 2026), aunque se acabara de cargar, y al
revés: una carga retrasada podría parecer fresca si trae ventas recientes.

`_loaded_at` es el instante (TIMESTAMPTZ en UTC) en que la fila entró a `raw`, así que su máximo indica
cuándo fue la última carga y es lo que se compara con la hora actual. Se ve en la evidencia: los tres
escenarios tienen **exactamente las mismas ventas** (mismas `fecha_venta`) y aun así freshness da
resultados distintos, porque solo cambia `_loaded_at`:

| Escenario | `max(_loaded_at)` | Antigüedad | Resultado |
|---|---|---|---|
| actualizada | 2026-11-12 09:30 UTC | 2.0 h | `PASS` → build se ejecuta |
| advertencia | 2026-11-11 17:31 UTC | 18.0 h | `WARN` → build se ejecuta |
| desactualizada | 2026-11-11 05:31 UTC | 30.0 h (`108010 s`) | `ERROR` → build `upstream_failed` |

(Ver la línea `FRESHNESS ...` en los logs de `comprobar_frescura` de `evidencias/logs/`.) Hay que aclarar que este control solo dice
cuándo fue la última carga; no prueba que hayan llegado todas las ventas esperadas.

## 2. ¿Por qué las pruebas de integridad no garantizan actualidad?

Porque revisan **la forma de los datos que hay**, no **cuándo llegaron**. `unique`, `not_null` y la
prueba `valores_ventas` verifican que no haya ids repetidos, nulos ni cantidades o precios inválidos. Un
conjunto de datos de hace 30 horas (o de hace un mes) puede cumplir todas esas reglas perfectamente.
Ninguna de esas pruebas compara una marca de tiempo con la hora actual.

En la evidencia se ve: con los datos desactualizados, las mismas 6 filas siguen siendo únicas, completas y
válidas, y un `dbt build` habría terminado con `PASS=19` y reconstruido el resumen con información vieja
sin ningún error técnico. Además, `dbt build` no ejecuta `source freshness` automáticamente. Por eso
freshness va como **tarea separada antes del build** en el DAG: con el escenario desactualizado,
`comprobar_frescura` falló y `construir_resumen` quedó `upstream_failed` sin ejecutarse. El resumen anterior
se conservó (`evidencias/resumen/01-antes-del-bloqueo.txt` = `02-despues-del-bloqueo.txt`).
