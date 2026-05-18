from fastapi import FastAPI, HTTPException
import os
import boto3
import pg8000.native
from fastapi import FastAPI, HTTPException
from botocore.exceptions import ClientError

app = FastAPI(
    title="IoT Sensor API",
    description="API unificada para consultar datos de sensores IoT",
    version="1.0.0"
)

# Nombre de la tabla DynamoDB
TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "SensorData-lab")

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
    """Abre una conexión a PostgreSQL leyendo la IP desde SSM."""
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

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/sensor/{device_id}/current")
def get_current(device_id: str):
    """
    Obtiene el dato más reciente del sensor consultando DynamoDB.
    DynamoDB sobrescribe siempre el mismo registro por device_id,
    por lo que este endpoint siempre devuelve el valor en tiempo real.
    """
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table    = dynamodb.Table(TABLE_NAME)

    response = table.get_item(Key={"device_id": device_id})
    item     = response.get("Item")

    if not item:
        raise HTTPException(status_code=404, detail=f"Sensor '{device_id}' no encontrado")

    return item

@app.get("/sensor/{device_id}/recent")
def get_recent(device_id: str):
    """
    Obtiene los últimos 10 eventos del sensor consultando PostgreSQL.
    PostgreSQL mantiene siempre los 10 eventos más recientes por sensor.
    """
    con = get_db()

    rows = con.run(
        "SELECT id, device_id, sensor_type, value, timestamp "
        "FROM sensor_events "
        "WHERE device_id = :device_id "
        "ORDER BY timestamp DESC "
        "LIMIT 10",
        device_id=device_id
    )

    if not rows:
        raise HTTPException(status_code=404, detail=f"No hay eventos para '{device_id}'")

    events = [
        {
            "id":          row[0],
            "device_id":   row[1],
            "sensor_type": row[2],
            "value":       row[3],
            "timestamp":   str(row[4])
        }
        for row in rows
    ]

    return {"device_id": device_id, "events": events}