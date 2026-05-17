# Creación del Thing (Dispositivo Edge Gateway)
resource "aws_iot_thing" "edge_gateway" {
  name = "edge-gateway-01-${var.environment}"
}

# Creación de los certificados
resource "aws_iot_certificate" "cert" {
  active = true
}

# Creación de la política de IoT
resource "aws_iot_policy" "sensor_policy" {
  name = "EdgeGatewayPolicy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1 (Connect): Permite al dispositivo establecer una conexión MQTT con AWS IoT Core.
      # Seguridad: Se restringe el recurso a un 'client' específico. Esto asegura que nadie más pueda 
      # conectarse a AWS IoT usando estos certificados si intenta usar un Client ID diferente.
      {
        Action   = ["iot:Connect"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.region}:${var.account_id}:client/${aws_iot_thing.edge_gateway.name}"]
      },
      
      # Statement 2 (Publish / Receive): Permite al dispositivo enviar (Publish) datos a AWS IoT Core 
      # y recibir (Receive) mensajes que le lleguen a través de tópicos específicos.
      # Seguridad: Solo puede interactuar con la jerarquía de tópicos 'lab/sensors/*'
      {
        Action   = ["iot:Publish", "iot:Receive"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.region}:${var.account_id}:topic/lab/sensors/*"]
      },
      
      # Statement 3 (Subscribe): Permite al dispositivo solicitar la suscripción a un tópico MQTT.
      # Seguridad: Utiliza el recurso 'topicfilter' (que permite comodines de MQTT como # y +).
      # Esto autoriza al Edge Gateway a suscribirse para escuchar cualquier sub-tópico de 'lab/sensors/'.
      {
        Action   = ["iot:Subscribe"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.region}:${var.account_id}:topicfilter/lab/sensors/*"]
      }
    ]
  })
}

# Adjuntar política al certificado
# Relaciona la política de seguridad (permisos) creada arriba con el certificado X.509.
# Sin esto, el certificado sería válido criptográficamente pero no tendría autorización para hacer nada en AWS.
resource "aws_iot_policy_attachment" "att" {
  policy = aws_iot_policy.sensor_policy.name
  target = aws_iot_certificate.cert.arn
}

# Adjuntar certificado al Thing
# Relaciona el certificado X.509 con el "Thing" (la representación virtual de nuestro Edge Gateway).
# Esto completa la cadena de identidad lógica: Dispositivo Físico <-> Certificado <-> Política de Permisos.
resource "aws_iot_thing_principal_attachment" "att" {
  principal = aws_iot_certificate.cert.arn
  thing     = aws_iot_thing.edge_gateway.name
}

# Escribir los certificados generados al disco local (Edge Gateway)
# Extrae el contenido PEM del certificado y lo guarda como archivo para que Mosquitto lo pueda leer.
resource "local_file" "certificate_pem" {
  content  = aws_iot_certificate.cert.certificate_pem
  filename = "${path.root}/../edge_gateway/certs/certificate.pem.crt"
}

# Extrae la clave privada generada por AWS y la guarda localmente (¡este archivo es secreto!).
resource "local_file" "private_key" {
  content  = aws_iot_certificate.cert.private_key
  filename = "${path.root}/../edge_gateway/certs/private.pem.key"
}

# Extrae la clave pública y la guarda en un archivo local.
resource "local_file" "public_key" {
  content  = aws_iot_certificate.cert.public_key
  filename = "${path.root}/../edge_gateway/certs/public.pem.key"
}

# Guarda el certificado raíz de Amazon (Root CA) necesario para que Mosquitto verifique la identidad del servidor de AWS.
resource "local_file" "root_ca" {
  content  = var.root_ca_pem
  filename = "${path.root}/../edge_gateway/certs/AmazonRootCA1.pem"
}

# Generar mosquitto.conf automáticamente inyectando el endpoint de AWS
# Crea el archivo de configuración del broker local Mosquitto. Se usa un bloque heredoc (<<-EOT)
# para definir el texto e interpolar dinámicamente el Endpoint ATS de AWS y el nombre del Thing.
resource "local_file" "mosquitto_conf" {
  content  = <<-EOT
# Configuración del servidor local Mosquitto
listener 1883 0.0.0.0
allow_anonymous true

# Configuración del Bridge hacia AWS IoT Core
connection awsiot
address ${var.iot_endpoint}:8883

# Mapeo de tópicos: local -> remoto
topic lab/sensors/data out 1 "" ""

bridge_protocol_version mqttv311
bridge_insecure false

cleansession true
clientid ${aws_iot_thing.edge_gateway.name}
start_type automatic
notifications false
keepalive_interval 60

# Certificados TLS para la conexión con AWS
bridge_cafile /mosquitto/certs/AmazonRootCA1.pem
bridge_certfile /mosquitto/certs/certificate.pem.crt
bridge_keyfile /mosquitto/certs/private.pem.key
EOT
  filename = "${path.root}/../edge_gateway/mosquitto.conf"
}

# === REGLAS IOT ===

# REGLA DE DYNAMODB:
# Actúa como un suscriptor interno en AWS IoT Core. Escucha todo lo que llega a 'lab/sensors/data'
# (vía la sentencia SQL) y ejecuta la acción "dynamodbv2", la cual inserta o actualiza 
# el ítem en la tabla de DynamoDB usando el LabRole para tener permisos de escritura.
resource "aws_iot_topic_rule" "dynamodb_rule" {
  name        = "SensorDataToDynamoDB_${var.environment}"
  description = "Guarda los eventos de sensores en DynamoDB"
  enabled     = true
  sql         = "SELECT * FROM 'lab/sensors/data'"
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = var.lab_role_arn
    put_item {
      table_name = var.sensor_table_name
    }
  }
}

# REGLA DE S3:
# De forma paralela a la regla anterior, intercepta los mismos mensajes de 'lab/sensors/data'.
# En lugar de base de datos, ejecuta la acción "s3", guardando el payload como un archivo JSON.
# La llave (key) usa funciones de interpolación internas de AWS IoT ($${parse_time...}) para organizar los archivos 
# en carpetas particionadas por año/mes/día directamente, optimizando futuras consultas analíticas (Athena).
resource "aws_iot_topic_rule" "s3_rule" {
  name        = "SensorDataToS3_${var.environment}"
  description = "Guarda los eventos de sensores en S3 particionados por fecha"
  enabled     = true
  sql         = "SELECT * FROM 'lab/sensors/data'"
  sql_version = "2016-03-23"

  s3 {
    bucket_name = var.sensor_bucket_name
    key         = "data/year=$${parse_time(\"yyyy\", timestamp())}/month=$${parse_time(\"MM\", timestamp())}/day=$${parse_time(\"dd\", timestamp())}/$${topic(3)}_$${newuuid()}.json"
    role_arn    = var.lab_role_arn
  }
}

# REGLA DE LAMBDA DE ALERTA:
# Empaqueta automáticamente lambda_function.py en un .zip cada vez
# que se ejecuta terraform.
data "archive_file" "lambda_alert_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_alert/lambda_function.py"
  output_path = "${path.module}/lambda_alert.zip"
}

# Función Lambda que se activa cuando IoT Core detecta temperatura > 35.
# El código está en lambda_alert.zip dentro de este mismo módulo.
resource "aws_lambda_function" "alert" {
  function_name    = "SensorTempAlert-${var.environment}"
  role             = var.lab_role_arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_alert_zip.output_path
  source_code_hash = data.archive_file.lambda_alert_zip.output_base64sha256
}

# Permiso explícito para que IoT Core pueda invocar la Lambda.
# A diferencia de DynamoDB y S3, Lambda requiere este permiso adicional 
# o la invocación falla con un 403.
resource "aws_lambda_permission" "iot_invoke_alert" {
  statement_id  = "AllowIoTCoreInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.alert_rule.arn
}

# Regla que escucha 'lab/sensors/data' pero solo procesa mensajes de
# temperatura que superen 35 grados, disparando la Lambda de alerta.
resource "aws_iot_topic_rule" "alert_rule" {
  name        = "SensorTempAlertRule_${var.environment}"
  description = "Dispara una Lambda de alerta cuando la temperatura supera 35 grados"
  enabled     = true
  sql         = "SELECT * FROM 'lab/sensors/data' WHERE sensor_type = 'temperature' AND value > 35"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.alert.arn
  }
}

# REGLA DE LAMBDA DE S3 -> POSTGRES:
# Empaqueta automáticamente la carpeta lambda_s3_to_postgres en un .zip
data "archive_file" "lambda_s3_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_s3_to_postgres"
  output_path = "${path.module}/lambda_s3_to_postgres.zip"
}

# Función Lambda que se activa cuando llega un nuevo archivo JSON a S3.
# Lee el evento, lo inserta en PostgreSQL y mantiene solo los últimos 10
# registros por sensor.
resource "aws_lambda_function" "s3_to_postgres" {
  function_name    = "SensorS3ToPostgres-${var.environment}"
  role             = var.lab_role_arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_s3_zip.output_path
  source_code_hash = data.archive_file.lambda_s3_zip.output_base64sha256
}

# Permiso para que S3 pueda invocar la Lambda cuando llegue un objeto nuevo.
resource "aws_lambda_permission" "s3_invoke_lambda" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_postgres.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.sensor_bucket_name}"
}

# Trigger ObjectCreated: cada vez que S3 reciba un archivo nuevo en el bucket
# de sensores, dispara automáticamente la Lambda de arriba.
resource "aws_s3_bucket_notification" "sensor_data_trigger" {
  bucket = var.sensor_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_postgres.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke_lambda]
}
