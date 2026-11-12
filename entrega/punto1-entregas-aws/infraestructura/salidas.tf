output "bucket" {
  description = "Nombre del bucket S3 del ejercicio."
  value       = aws_s3_bucket.entregas.bucket
}

output "ubicacion_datos" {
  description = "Prefijo S3 donde se cargan los CSV (fecha=yyyy-MM-dd/entregas.csv)."
  value       = local.ubicacion_datos
}

output "ubicacion_resultados_athena" {
  description = "Prefijo S3 donde Athena guarda los resultados."
  value       = local.ubicacion_resultados
}

output "base_datos" {
  description = "Base de datos de Glue Data Catalog."
  value       = aws_glue_catalog_database.entregas.name
}

output "tabla" {
  description = "Tabla externa con partition projection."
  value       = aws_glue_catalog_table.entregas.name
}

output "tabla_completa" {
  description = "Nombre calificado para las consultas de Athena."
  value       = "${aws_glue_catalog_database.entregas.name}.${aws_glue_catalog_table.entregas.name}"
}

output "workgroup" {
  description = "Workgroup de Athena donde se ejecutan las consultas."
  value       = aws_athena_workgroup.entregas.name
}

output "region" {
  description = "Región del despliegue."
  value       = var.region
}
