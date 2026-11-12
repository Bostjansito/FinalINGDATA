# Respuestas – Punto 1 (Entregas: S3 + Glue + Athena con partition projection)

## 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque la tabla no depende de particiones registradas en el catálogo: usa **partition projection**.
En lugar de buscar en Glue la lista de particiones (que está vacía: ver
`evidencias/capturas/03-etapa-final/03-glue-sigue-sin-particiones.jpg` y `aws glue get-partitions` = `0` en
`evidencias/carga_final_s3.txt`), Athena **calcula** las particiones al momento de la consulta con las reglas
guardadas en las propiedades de la tabla (`infraestructura/principal.tf`):

- `projection.fecha.type = date`, `projection.fecha.format = yyyy-MM-dd`
- `projection.fecha.range = 2026-10-01,2026-10-03` (ambos incluidos), con intervalo de `1` `DAYS`
- `storage.location.template = s3://final-entregas-387512138242/entregas/fecha=${fecha}/`

Con eso Athena genera los valores `2026-10-01`, `2026-10-02` y `2026-10-03` y, para cada uno, el prefijo de
S3 donde debe leer. El día 3 ya estaba dentro del rango desde el despliegue inicial, pero en la etapa
inicial su prefijo estaba vacío, así que no aportaba filas (12 registros: `resultados/inicial/conteo_total.csv`).
Al subir `entregas/fecha=2026-10-03/entregas.csv`, la siguiente consulta encontró el archivo en la ruta que
Athena ya proyectaba, sin crawler, sin `MSCK REPAIR TABLE`, sin `ALTER TABLE ADD PARTITION` y sin cambiar
Terraform (`terraform plan` antes de la carga: *no changes*). Resultado: 6 registros del día 3 y 18 en total
(`resultados/final/verificacion_tercer_dia.csv`, `resultados/final/total_registros_tabla.csv`).

En resumen: **subir el archivo crea los datos; la proyección ya sabía dónde buscarlos.** La proyección no crea
archivos ni garantiza que existan; solo define qué fechas y rutas son consultables.

## 2. Si se subiera un archivo para el 4 de octubre manteniendo la configuración actual, ¿qué resultado se esperaría y qué se debería modificar para incluirlo?

**Resultado esperado:** el archivo quedaría en S3, pero **Athena no lo leería**. La fecha `2026-10-04` está
fuera de `projection.fecha.range = 2026-10-01,2026-10-03`, así que Athena nunca genera esa partición ni
consulta su prefijo. Las consultas devolverían lo mismo que ahora (18 registros, tres fechas). Un
`WHERE fecha = '2026-10-04'` devolvería **cero filas sin error**, no un fallo. Además, como la proyección está
activa, Athena ignora las particiones del catálogo, así que registrarla a mano tampoco la incluiría.

**Qué modificar:** el rango de la proyección, en Terraform y no en la consola, para que siga siendo reproducible:

```hcl
# infraestructura/variables.tf (o un terraform.tfvars)
rango_fechas = ["2026-10-01", "2026-10-04"]
```

y luego `terraform apply`, que solo actualiza la propiedad `projection.fecha.range` de la tabla. Después basta
con consultar: no hay que registrar particiones. Si se esperan archivos diarios de forma continua, una
alternativa es usar un rango relativo como `2026-10-01,NOW`, para no tener que tocar la tabla cada día.
Cualquier archivo nuevo debe respetar la ruta `entregas/fecha=yyyy-MM-dd/` y el mismo esquema de cinco columnas.
