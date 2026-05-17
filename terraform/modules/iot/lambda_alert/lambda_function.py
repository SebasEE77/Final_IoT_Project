import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    device_id   = event.get("device_id", "desconocido")
    sensor_type = event.get("sensor_type", "desconocido")
    value       = event.get("value", 0)
    timestamp   = event.get("timestamp", "")

    message = (
        f"ALERTA TEMPERATURA CRITICA | "
        f"Dispositivo: {device_id} | "
        f"Tipo: {sensor_type} | "
        f"Valor: {value} | "
        f"Timestamp: {timestamp}"
    )

    logger.warning(message)

    return {
        "statusCode": 200,
        "body": json.dumps({"alerta": message})
    }