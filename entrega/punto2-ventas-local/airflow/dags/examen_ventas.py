import json
import os
from datetime import datetime, timezone

from airflow import DAG
from airflow.operators.python import PythonOperator
from runtime import run_dbt


def registrar_resultado_freshness(context):
    """Escribe en el log de la tarea el resultado de `dbt source freshness`.

    run_dbt no captura la salida de dbt, así que el motivo (pass/warn/error y la antigüedad
    de la última carga) se lee del artefacto sources.json. Solo informa: no cambia el estado.
    """
    log = context["ti"].log
    ruta = os.path.join(os.environ.get("DBT_TARGET_PATH", "/workspace/dbt/target"), "sources.json")
    try:
        with open(ruta) as archivo:
            resultados = json.load(archivo)["results"]
    except (OSError, KeyError, ValueError) as error:
        log.warning("No se pudo leer %s: %s", ruta, error)
        return
    for r in resultados:
        criterio = r.get("criteria", {})
        log.info(
            "FRESHNESS %s: status=%s | max(_loaded_at)=%s | antigüedad=%.1f h (%d s) "
            "| warn_after=%s error_after=%s",
            r.get("unique_id"),
            r.get("status", "?").upper(),
            r.get("max_loaded_at"),
            r.get("max_loaded_at_time_ago_in_s", 0) / 3600,
            r.get("max_loaded_at_time_ago_in_s", 0),
            criterio.get("warn_after"),
            criterio.get("error_after"),
        )


with DAG(
    dag_id="examen_ventas",
    start_date=datetime(2026, 1, 1, tzinfo=timezone.utc),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    default_args={"retries": 0},
    tags=["examen"],
) as dag:
    # Advertencia (>12 h) -> dbt sale con código 0 y la tarea queda en success.
    # Error (>24 h) -> dbt sale con código 1, run_dbt lanza CalledProcessError y la tarea falla.
    # Los callbacks solo dejan el motivo (status y antigüedad) en el log de Airflow.
    comprobar_frescura = PythonOperator(
        task_id="comprobar_frescura",
        python_callable=run_dbt,
        op_args=[["source", "freshness"]],
        on_success_callback=registrar_resultado_freshness,
        on_failure_callback=registrar_resultado_freshness,
    )

    construir_resumen = PythonOperator(
        task_id="construir_resumen",
        python_callable=run_dbt,
        op_args=[["build"]],
    )

    # Regla por defecto all_success: si la frescura falla, build queda upstream_failed.
    comprobar_frescura >> construir_resumen
