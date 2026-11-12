# Punto 2 (2.0) – Ventas diarias con control de actualidad

Solución del repositorio [smm-0216/DE-Final-Ventas](https://github.com/smm-0216/DE-Final-Ventas).
El enunciado original está en [`ENUNCIADO.md`](ENUNCIADO.md). Esta carpeta es la copia de trabajo del
proyecto: el entorno Docker (`compose.yaml`, imagen `smendezm/examen-ventas:1.0`) se ejecutó desde aquí.

## Archivos modificados (solo los tres permitidos)

| Archivo | Cambio |
|---|---|
| [`dbt/models/ventas_diarias.sql`](dbt/models/ventas_diarias.sql) | Resumen por `fecha_venta` desde `ref('stg_ventas')`: `count(id_venta)`, `sum(cantidad)`, `sum(cantidad * precio_unitario)`. El ingreso se calcula sobre `DECIMAL(12,2)` y queda como `DECIMAL(38,2)` (sin pasar por float). |
| [`dbt/models/sources.yml`](dbt/models/sources.yml) | En la tabla `ventas`: `loaded_at_field: _loaded_at` y `freshness` con `warn_after` 12 h y `error_after` 24 h, al nivel de la tabla (sintaxis dbt 1.9, fuera de `config`). |
| [`airflow/dags/examen_ventas.py`](airflow/dags/examen_ventas.py) | Nueva tarea `comprobar_frescura` (`PythonOperator` → `run_dbt(["source", "freshness"])`) y dependencia `comprobar_frescura >> construir_resumen`, con la regla por defecto `all_success` y sin `--warn-error`. La tarea tiene `on_success_callback`/`on_failure_callback` que escriben en el log de Airflow el resultado de freshness (`status`, `max(_loaded_at)`, antigüedad, umbrales) leído de `sources.json`; solo informan, no cambian el estado. |

No se modificaron datos, pruebas, perfiles, `scripts/runtime.py` ni la infraestructura.

## Cómo se ejecutó

```bash
bash scripts/preparar.sh                 # .env ya existía (entorno preparado con el ZIP)
docker compose up -d --wait airflow
bash scripts/examen.sh check
bash scripts/examen.sh scenario actualizada
bash scripts/examen.sh dbt build         # PASS=19
bash scripts/examen.sh query 'select * from analytics.ventas_diarias order by fecha_venta'
docker compose exec airflow airflow dags trigger examen_ventas   # ejecución 1
bash scripts/examen.sh scenario desactualizada
docker compose exec airflow airflow dags trigger examen_ventas   # ejecución 2 (nueva)
bash scripts/examen.sh query 'select * from analytics.ventas_diarias order by fecha_venta'
bash scripts/examen.sh scenario advertencia   # opcional
docker compose exec airflow airflow dags trigger examen_ventas   # ejecución 3
```

Cada `dags trigger` crea una ejecución manual nueva, igual que el botón **Trigger DAG** de la UI. Las
capturas se tomaron después en la UI de Airflow (http://localhost:8080). La comprobación directa del
modelo (`evidencias/01-comprobacion/`) se hizo antes de las ejecuciones del DAG; el modelo no cambió después.

## Resultado del modelo

| fecha_venta | numero_ventas | unidades_vendidas | ingreso_total |
|---|---:|---:|---:|
| 2026-01-10 | 2 | 3 | 46.00 |
| 2026-01-11 | 3 | 6 | 51.25 |
| 2026-01-12 | 1 | 4 | 12.40 |

Coincide con lo esperado. `dbt build`: `PASS=19 WARN=0 ERROR=0` ([salida](evidencias/01-comprobacion/02-dbt-build.txt)).

## Ejecuciones del DAG `examen_ventas`

| # | Escenario | Run ID | `comprobar_frescura` | `construir_resumen` |
|---|---|---|---|---|
| 1 | actualizada (2.0 h) | `manual__2026-11-12T11:30:54+00:00` | success (`status=PASS`) | success |
| 2 | desactualizada (30.0 h) | `manual__2026-11-12T11:31:25+00:00` | **failed** (`status=ERROR`, 108010 s) | **upstream_failed** (no se ejecutó) |
| 3 | advertencia (18.0 h, opcional) | `manual__2026-11-12T11:31:50+00:00` | success (`status=WARN`) | success |

## Evidencias

| Evidencia | Archivo |
|---|---|
| Ejecución 1: grafo con estados y detalle con Run ID | [`capturas/01-actualizada/`](evidencias/capturas/01-actualizada/) |
| Ejecución 1: logs de las dos tareas (`INICIO dbt` / `FIN dbt`, `FRESHNESS ... status=PASS`) y estados | [`logs/01-actualizada/`](evidencias/logs/01-actualizada/) |
| Resumen **antes** del bloqueo | [`resumen/01-antes-del-bloqueo.txt`](evidencias/resumen/01-antes-del-bloqueo.txt) |
| Ejecución 2: grafo `failed` / `upstream_failed` y detalle con Run ID | [`01-grafo-failed-upstream-failed.jpg`](evidencias/capturas/02-desactualizada/01-grafo-failed-upstream-failed.jpg), [`02-detalle-run-id.jpg`](evidencias/capturas/02-desactualizada/02-detalle-run-id.jpg) |
| Ejecución 2: **log de freshness con el motivo del fallo** (`status=ERROR`, 30.0 h > 24 h) | captura [`03-log-freshness-error.jpg`](evidencias/capturas/02-desactualizada/03-log-freshness-error.jpg) y log completo [`01-airflow-comprobar_frescura.log`](evidencias/logs/02-desactualizada/01-airflow-comprobar_frescura.log) |
| Ejecución 2: build sin intento ni `INICIO dbt` | [`02-estados-y-build-no-ejecutado.txt`](evidencias/logs/02-desactualizada/02-estados-y-build-no-ejecutado.txt) |
| Resumen **después** del bloqueo (idéntico) | [`resumen/02-despues-del-bloqueo.txt`](evidencias/resumen/02-despues-del-bloqueo.txt) |
| Ejecución 3 (opcional): log con `status=WARN` (18.0 h) | [`capturas/03-advertencia-opcional/`](evidencias/capturas/03-advertencia-opcional/), [`logs/03-advertencia-opcional/`](evidencias/logs/03-advertencia-opcional/) |
| Respuestas conceptuales | [`respuestas.md`](respuestas.md) |

**Log de freshness en Airflow.** `run_dbt` lanza dbt con `subprocess.run` sin capturar su salida, así
que la línea de dbt (`ERROR STALE freshness of ventas_raw.ventas`) va a la salida del contenedor y no al
log de la tarea. Como `runtime.py` no se puede modificar, la tarea `comprobar_frescura` tiene un callback
que lee el artefacto `sources.json` que acaba de escribir dbt y deja el motivo en el log de Airflow:

```
FRESHNESS source.examen_ventas.ventas_raw.ventas: status=ERROR | max(_loaded_at)=2026-11-11T05:31:25.242909+00:00
| antigüedad=30.0 h (108010 s) | warn_after={'count': 12, 'period': 'hour'} error_after={'count': 24, 'period': 'hour'}
```

La tarea sigue llamando directamente a `run_dbt` y el `CalledProcessError` se propaga igual a Airflow.

**Prueba de que build no corrió en la ejecución 2.** El estado es `upstream_failed`. No existe carpeta de
logs de `construir_resumen` para ese Run ID, así que no hubo intento ni `INICIO dbt`. Justo después del
bloqueo, el último `run_results.json` seguía siendo el del build de las 11:31:12 UTC, de la ejecución 1.
