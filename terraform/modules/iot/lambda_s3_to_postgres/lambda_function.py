import json
import logging
import boto3
import pg8000.native
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_ssm_parameter(name: str, default: str = None) -> str:
    """
    Consulta un parámetro del Parameter Store de AWS.
    Si no existe, retorna el valor default.
    """
    client = boto3.client("ssm", region_name="us-east-1")
    try:
        response = client.get_parameter(Name=name)
        return response["Parameter"]["Value"]
    except ClientError as e:
        if e.response["Error"]["Code"] == "ParameterNotFound":
            print(f"[WARN] Parámetro '{name}' no encontrado. Usando: '{default}'")
            return default
        raise

def get_db():
    postgres_ip = get_ssm_parameter(
        name="/iot-edge/lab/postgres/public_ip",
        default="localhost"
    )
    return pg8000.native.Connection(
        host=postgres_ip,
        database="sensordb",
        user="postgres",
        password="Sebas123",
        port=5432
    )

def handler(event, context):
    """
    Se activa cuando llega un nuevo archivo JSON al bucket de S3.
    Lee el evento, lo inserta en PostgreSQL y mantiene solo los
    últimos 10 registros por sensor (lógica acíclica).
    """
    s3 = boto3.client("s3")

    # Extraer bucket y key del evento de S3
    record  = event["Records"][0]["s3"]
    bucket  = record["bucket"]["name"]
    key     = record["object"]["key"]

    logger.info(f"Procesando archivo: s3://{bucket}/{key}")

    # Leer el JSON desde S3
    response = s3.get_object(Bucket=bucket, Key=key)
    payload  = json.loads(response["Body"].read().decode("utf-8"))

    device_id   = payload["device_id"]
    sensor_type = payload["sensor_type"]
    value       = float(payload["value"])
    timestamp   = payload["timestamp"]

    logger.info(f"Insertando evento: {device_id} | {sensor_type} | {value}")

    con = get_db()

    # Insertar el nuevo evento
    con.run(
        "INSERT INTO sensor_events (device_id, sensor_type, value, timestamp) "
        "VALUES (:device_id, :sensor_type, :value, :timestamp)",
        device_id=device_id,
        sensor_type=sensor_type,
        value=value,
        timestamp=timestamp
    )

    # Mantener solo los últimos 10 eventos por sensor (lógica acíclica).
    # Borra todo lo que quede fuera de los 10 más recientes del mismo device_id.
    con.run(
        "DELETE FROM sensor_events "
        "WHERE device_id = :device_id "
        "AND id NOT IN ( "
        "    SELECT id FROM sensor_events "
        "    WHERE device_id = :device_id "
        "    ORDER BY timestamp DESC "
        "    LIMIT 10 "
        ")",
        device_id=device_id
    )

    logger.info(f"Listo. Eventos anteriores al top 10 eliminados para {device_id}")

    return {
        "statusCode": 200,
        "body": json.dumps({"mensaje": f"Evento de {device_id} procesado correctamente"})
    }