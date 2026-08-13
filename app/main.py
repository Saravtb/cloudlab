"""
Workload minimo do Projeto 1 - AWS CloudLab.

Expoe apenas o contrato funcional exigido:
    GET  /         -> nome e versao do servico
    GET  /health   -> estado, versao e horario
    POST /events   -> recebe um evento sintetico e devolve id e status

Nao ha persistencia, autenticacao, frontend nem integracao externa.
O processamento e sem estado: o evento e registrado em log estruturado
na saida padrao e descartado da memoria.
"""

import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI
from pydantic import BaseModel, Field

SERVICE_NAME = os.getenv("SERVICE_NAME", "cloudlab-events")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")


# --------------------------------------------------------------------------
# Log estruturado em JSON na saida padrao.
# O ECS captura o stdout do container e envia para o CloudWatch Logs.
# --------------------------------------------------------------------------

class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "message": record.getMessage(),
        }
        # Campos extras enviados via logger.info(..., extra={"event": {...}})
        if hasattr(record, "event"):
            payload["event"] = record.event
        return json.dumps(payload, ensure_ascii=False)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())

logger = logging.getLogger(SERVICE_NAME)
logger.setLevel(logging.INFO)
logger.handlers = [handler]
logger.propagate = False


# --------------------------------------------------------------------------
# Modelos
# --------------------------------------------------------------------------

class Event(BaseModel):
    type: str = Field(..., max_length=100, examples=["operation.created"])
    source: str = Field(..., max_length=100, examples=["cloud-lab"])
    message: str = Field(..., max_length=500, examples=["Evento sintetico para uso academico"])


class EventAccepted(BaseModel):
    id: str
    status: str


# --------------------------------------------------------------------------
# Aplicacao
# --------------------------------------------------------------------------

app = FastAPI(
    title=SERVICE_NAME,
    description="Workload minimo para validar decisoes de arquitetura na AWS.",
    version=SERVICE_VERSION,
)


@app.get("/")
def root():
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "version": SERVICE_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/events", response_model=EventAccepted, status_code=202)
def receive_event(event: Event):
    event_id = str(uuid.uuid4())

    logger.info(
        "event received",
        extra={
            "event": {
                "id": event_id,
                "type": event.type,
                "source": event.source,
                "message": event.message,
                "status": "received",
            }
        },
    )

    return EventAccepted(id=event_id, status="received")
