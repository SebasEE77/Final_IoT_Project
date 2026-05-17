FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt pika fastapi uvicorn psycopg2-binary boto3

COPY sensor_simulator.py .

CMD ["python", "-u", "sensor_simulator.py"]
