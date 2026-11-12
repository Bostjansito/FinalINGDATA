#!/usr/bin/env bash
# Sube UN solo archivo diario a su ruta en S3 (sin carga recursiva ni sincronización).
# Uso (desde la raíz de punto1-entregas-aws):  bash scripts/cargar_dia.sh 2026-10-01
set -euo pipefail
cd "$(dirname "$0")/.."

fecha=$1
bucket=$(terraform -chdir=infraestructura output -raw bucket)
origen="data/entregas/fecha=$fecha/entregas.csv"
destino="s3://$bucket/entregas/fecha=$fecha/entregas.csv"

echo "\$ aws s3 cp $origen $destino   ($(date -u +%FT%TZ))"
aws s3 cp --no-progress "$origen" "$destino"
