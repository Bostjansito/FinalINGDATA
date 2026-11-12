# =====================================================================
# Punto 1 – Entregas: S3 + Glue Data Catalog (partition projection) + Athena
# =====================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto  = "examen-final-ingdata"
      Punto     = "1-entregas"
      Gestion   = "terraform"
      Propiedad = "sebastian-perez"
    }
  }
}

data "aws_caller_identity" "actual" {}

locals {
  nombre_bucket        = "${var.prefijo}-${data.aws_caller_identity.actual.account_id}"
  ubicacion_datos      = "s3://${local.nombre_bucket}/${var.prefijo_datos}"
  ubicacion_resultados = "s3://${local.nombre_bucket}/${var.prefijo_resultados}"
}

# ---------------------------------------------------------------------
# 1. Bucket S3 privado (datos en entregas/ y resultados en resultados-athena/)
# ---------------------------------------------------------------------
resource "aws_s3_bucket" "entregas" {
  bucket = local.nombre_bucket

  # Permite que terraform destroy elimine el bucket aunque queden CSV o resultados de Athena.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "entregas" {
  bucket = aws_s3_bucket.entregas.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "entregas" {
  bucket = aws_s3_bucket.entregas.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "entregas" {
  bucket = aws_s3_bucket.entregas.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------
# 2. Base de datos de Glue Data Catalog
# ---------------------------------------------------------------------
resource "aws_glue_catalog_database" "entregas" {
  name        = var.nombre_base_datos
  description = "Examen final – intentos de entrega de paquetes (CSV en S3)."
}

# ---------------------------------------------------------------------
# 3. Tabla externa con partition projection sobre fecha
# ---------------------------------------------------------------------
resource "aws_glue_catalog_table" "entregas" {
  name          = var.nombre_tabla
  database_name = aws_glue_catalog_database.entregas.name
  description   = "Intentos de entrega. fecha sale de la carpeta fecha=yyyy-MM-dd y se proyecta, no se registra."
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"               = "TRUE"
    "classification"         = "csv"
    "skip.header.line.count" = "1"

    # Partition projection: Athena calcula las particiones al consultar, sin registrarlas en el catálogo.
    "projection.enabled"             = "true"
    "projection.fecha.type"          = "date"
    "projection.fecha.format"        = "yyyy-MM-dd"
    "projection.fecha.range"         = join(",", var.rango_fechas)
    "projection.fecha.interval"      = "1"
    "projection.fecha.interval.unit" = "DAYS"
    # Prefijo de cada partición (termina en /); el archivo entregas.csv está dentro.
    # $${fecha} se escribe así para que Terraform deje literal ${fecha} para Athena.
    "storage.location.template" = "${local.ubicacion_datos}fecha=$${fecha}/"
  }

  partition_keys {
    name    = "fecha"
    type    = "string"
    comment = "Fecha del archivo (yyyy-MM-dd), tomada de la carpeta fecha=..."
  }

  storage_descriptor {
    location      = local.ubicacion_datos
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-coma"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
      }
    }

    # Las cinco columnas del CSV, en el orden del archivo.
    columns {
      name    = "id_envio"
      type    = "string"
      comment = "Identificador único del envío (texto)"
    }
    columns {
      name    = "ciudad"
      type    = "string"
      comment = "Bogota o Medellin"
    }
    columns {
      name    = "transportadora"
      type    = "string"
      comment = "RutaNorte o RutaSur"
    }
    columns {
      name    = "estado"
      type    = "string"
      comment = "entregado, destinatario_ausente o direccion_incorrecta"
    }
    columns {
      name    = "duracion_minutos"
      type    = "int"
      comment = "Positiva si entregado, 0 si fallido"
    }
  }
}

# ---------------------------------------------------------------------
# 4. Workgroup de Athena con resultados en resultados-athena/
# ---------------------------------------------------------------------
resource "aws_athena_workgroup" "entregas" {
  name          = "${var.prefijo}-wg"
  description   = "Workgroup del examen final (punto 1)."
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false
    bytes_scanned_cutoff_per_query     = var.limite_bytes_por_consulta

    result_configuration {
      output_location = local.ubicacion_resultados

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
