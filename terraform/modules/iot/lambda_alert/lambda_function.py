import json
import logging
import os
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_queue_url(queue_name, region='us-east-1'):
    """Obtiene la URL de una cola SQS por su nombre usando boto3."""
    sqs = boto3.client('sqs', region_name=region)
    try:
        response = sqs.get_queue_url(QueueName=queue_name)
        print(response)
        return response['QueueUrl']
    except Exception as e:
        print(f"Error obteniendo la URL de la cola '{queue_name}': {e}")
        print("Asegúrate de que la infraestructura esté desplegada.")
        return None

def send_message(queue_url, message_body, region='us-east-1'):
    """Envía un mensaje a la cola SQS especificada usando boto3."""
    if not queue_url:
        print("La URL de la cola está vacía. ¿Se desplegó correctamente la infraestructura?")
        return

    sqs = boto3.client('sqs', region_name=region)
    try:
        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=message_body
        )
        print(f"Mensaje enviado a {queue_url}")
        print(f"MessageId: {response['MessageId']}")
    except Exception as e:
        print(f"Error al enviar mensaje: {e}")

def handler(event, context):
    device_id   = event.get("device_id", "desconocido")
    sensor_type = event.get("sensor_type", "desconocido")
    value       = event.get("value", 0)
    timestamp   = event.get("timestamp", "")

    # se obtiene la URL de la cola desde las variables de entorno
    queue_url = get_queue_url('my-lambda-queue')
    
    # se construye el mensaje a publicar en la cola
    message = (
        f"ALERTA TEMPERATURA CRITICA | "
        f"Dispositivo: {device_id} | "
        f"Tipo: {sensor_type} | "
        f"Valor: {value} | "
        f"Timestamp: {timestamp}"
    )
    
    send_message(queue_url, message)
    

    #logger.warning(message)

    return {
        "statusCode": 200,
        "body": json.dumps({"alerta": message})
    }