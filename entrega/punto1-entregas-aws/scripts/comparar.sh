#!/usr/bin/env bash
# Compara los resultados obtenidos en Athena con las referencias de resultados_esperados/.
# Uso: bash scripts/comparar.sh inicial|final
set -uo pipefail
cd "$(dirname "$0")/.."
etapa=$1; fallos=0
comparar() {
  if diff -q "$1" "$2" >/dev/null; then echo "IGUAL      $1  ==  $2"; else echo "DIFERENTE  $1  !=  $2"; diff "$1" "$2"; fallos=$((fallos+1)); fi
}
for c in intentos_por_fecha_estado porcentaje_exito_por_fecha_ciudad; do
  comparar "resultados/$etapa/$c.csv" "resultados_esperados/${c}_$etapa.csv"
done
[ "$etapa" = inicial ] && comparar resultados/inicial/duracion_promedio_2026-10-02.csv resultados_esperados/duracion_promedio_2026-10-02.csv
echo "Diferencias: $fallos"
exit $fallos
