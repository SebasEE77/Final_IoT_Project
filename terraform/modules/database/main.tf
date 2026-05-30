resource "aws_dynamodb_table" "sensor_data" {
  # Añadimos el sufijo del entorno para evitar conflictos si hay varios ambientes
  name           = "SensorData-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  
  # Con Partition Key + Sort Key, DynamoDB guarda múltiples eventos
  # por sensor. Cada combinación device_id + timestamp es única.
  hash_key  = "device_id"
  range_key = "timestamp"

    attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
