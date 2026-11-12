variable "region" {
  description = "Región de AWS donde se despliega el ejercicio."
  type        = string
  default     = "us-east-1"
}

variable "prefijo" {
  description = "Prefijo de nombres. El bucket queda como <prefijo>-<id de cuenta> para que sea único."
  type        = string
  default     = "final-entregas"
}

variable "nombre_base_datos" {
  description = "Base de datos de Glue Data Catalog (solo minúsculas, números y guion bajo)."
  type        = string
  default     = "final_entregas"
}

variable "nombre_tabla" {
  description = "Tabla externa de Glue con los intentos de entrega."
  type        = string
  default     = "entregas"
}

variable "prefijo_datos" {
  description = "Prefijo del bucket donde se cargan los CSV (sin barra inicial, con barra final)."
  type        = string
  default     = "entregas/"
}

variable "prefijo_resultados" {
  description = "Prefijo del bucket donde Athena escribe los resultados (sin barra inicial, con barra final)."
  type        = string
  default     = "resultados-athena/"
}

variable "rango_fechas" {
  description = "Rango de partition projection para la clave fecha: inicio y fin, ambos incluidos (yyyy-MM-dd)."
  type        = list(string)
  default     = ["2026-10-01", "2026-10-03"]

  validation {
    condition     = length(var.rango_fechas) == 2 && alltrue([for f in var.rango_fechas : can(regex("^\\d{4}-\\d{2}-\\d{2}$", f))])
    error_message = "rango_fechas debe tener exactamente dos fechas con formato yyyy-MM-dd."
  }
}

variable "limite_bytes_por_consulta" {
  description = "Límite de bytes escaneados por consulta en el workgroup (control de costos; mínimo de AWS: 10 MB)."
  type        = number
  default     = 10485760
}
