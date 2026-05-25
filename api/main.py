from fastapi import FastAPI, HTTPException
import os
import boto3
import pg8000.native
from botocore.exceptions import ClientError
from decimal import Decimal
from pydantic import BaseModel

app = FastAPI(
    title="IoT Sensor API",
    description="API unificada para consultar datos de sensores IoT",
    version="1.0.0"
)

class SensorIn(BaseModel):
    device_id: str = "sensor-light-01"
    sensor_type: str = "light"
    value: float = 5000.0
    timestamp: str = "2026-05-25T00:00:00Z"

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

@app.get("/sensors")
def get_sensors():
    """
    Lista todos los sensores existentes consultando DynamoDB.
    """
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table    = dynamodb.Table(TABLE_NAME)

    response = table.scan()
    items    = response.get("Items", [])

    return {"sensors": items, "total": len(items)}

@app.post("/sensors")
def register_sensor(sensor: SensorIn):
    """
    Registra un nuevo sensor en DynamoDB.
    Recibe un JSON con device_id, sensor_type, value y timestamp.
    """
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table    = dynamodb.Table(TABLE_NAME)

    item = sensor.model_dump()
    item["value"] = Decimal(str(item["value"]))
    
    table.put_item(Item=item)

    return {"mensaje": f"Sensor '{sensor.device_id}' registrado correctamente", "sensor": sensor}

@app.get("/sensor/{device_id}/current")
def get_current(device_id: str):
    """
    Obtiene el dato más reciente del sensor consultando DynamoDB.
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

@app.get("/sensor/{device_id}/history")
def get_history(device_id: str):
    """
    Obtiene el histórico completo del sensor consultando PostgreSQL.
    """
    con = get_db()

    rows = con.run(
        "SELECT id, device_id, sensor_type, value, timestamp "
        "FROM sensor_events "
        "WHERE device_id = :device_id "
        "ORDER BY timestamp DESC",
        device_id=device_id
    )

    if not rows:
        raise HTTPException(status_code=404, detail=f"No hay historial para '{device_id}'")

    events = [
        {
            "id":          row[0],
            "device_id":   row[1],
            "sensor_type": row[2],
            "value":       float(row[3]),
            "timestamp":   str(row[4])
        }
        for row in rows
    ]

    return {"device_id": device_id, "total": len(events), "history": events}