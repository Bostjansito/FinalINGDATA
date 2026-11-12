#!/usr/bin/env bash
# Ejecuta una consulta de consultas/*.sql en el workgroup del ejercicio, espera el resultado,
# lo descarga a resultados/... y registra la ejecución en evidencias/ejecuciones_athena.csv.
#
# Uso (desde la raíz de punto1-entregas-aws):
#   bash scripts/athena.sh <etapa> <archivo_sql> <archivo_resultado> [n_sentencia]
#   bash scripts/athena.sh inicial consultas/intentos_por_fecha_estado.sql resultados/inicial/intentos_por_fecha_estado.csv
set -euo pipefail
cd "$(dirname "$0")/.."

etapa=$1; archivo_sql=$2; archivo_resultado=$3; n=${4:-1}
registro=evidencias/ejecuciones_athena.csv

workgroup=$(terraform -chdir=infraestructura output -raw workgroup)
base_datos=$(terraform -chdir=infraestructura output -raw base_datos)

# Sentencia n del archivo: se quitan comentarios -- y se separa por ';'.
sentencia=$(sed 's/--.*$//' "$archivo_sql" | awk -v n="$n" 'BEGIN{RS=";"} {gsub(/^[ \t\n]+|[ \t\n]+$/, "")} length($0)>0 {i++; if (i==n) print}')
[ -n "$sentencia" ] || { echo "No existe la sentencia $n en $archivo_sql" >&2; exit 1; }

id=$(aws athena start-query-execution \
      --work-group "$workgroup" \
      --query-execution-context "Database=$base_datos" \
      --query-string "$sentencia" \
      --query QueryExecutionId --output text)

while :; do
  estado=$(aws athena get-query-execution --query-execution-id "$id" --query QueryExecution.Status.State --output text)
  case $estado in
    SUCCEEDED) break ;;
    FAILED|CANCELLED)
      aws athena get-query-execution --query-execution-id "$id" --query QueryExecution.Status.StateChangeReason --output text >&2
      exit 1 ;;
  esac
  sleep 1
done

salida=$(aws athena get-query-execution --query-execution-id "$id" --query QueryExecution.ResultConfiguration.OutputLocation --output text)
mkdir -p "$(dirname "$archivo_resultado")"
# Athena entrega el CSV con comillas dobles y fin de línea CRLF; los valores no tienen comas, así que se quitan
# para dejar el mismo formato que resultados_esperados/.
aws s3 cp "$salida" - | tr -d '"\r' > "$archivo_resultado"

[ -f "$registro" ] || echo "etapa,archivo_sql,id_ejecucion,archivo_resultado" > "$registro"
echo "$etapa,$archivo_sql,$id,$archivo_resultado" >> "$registro"

echo "OK $etapa $archivo_sql (sentencia $n) -> $archivo_resultado  [id $id, origen $salida]"
cat "$archivo_resultado"
