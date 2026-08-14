"""
Workload do Projeto 1 - AWS CloudLab, incremento v1.1.

Contrato funcional:
    GET  /            -> pagina do frontend
    GET  /api         -> nome e versao do servico
    GET  /health      -> estado, versao, horario e estado do banco
    POST /events      -> recebe um evento sintetico, persiste e devolve id e status
    GET  /events      -> lista os eventos persistidos

A conexao com o PostgreSQL e resiliente por decisao de arquitetura: se o banco
nao responder, o processo NAO encerra. A aplicacao continua no ar, /health
reporta o estado "degraded" e as rotas de dados devolvem 503. Isso evita que
uma indisponibilidade do banco derrube a tarefa no ECS sem diagnostico.
"""

import json
import logging
import os
import sys
import threading
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from psycopg_pool import ConnectionPool
from pydantic import BaseModel, Field

SERVICE_NAME = os.getenv("SERVICE_NAME", "cloudlab-events")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.1.0")
STATIC_DIR = Path(__file__).parent / "static"


# --------------------------------------------------------------------------
# Log estruturado em JSON na saida padrao (capturado pelo driver awslogs).
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
# Credenciais.
# O ECS injeta DB_SECRET com o JSON completo vindo do Secrets Manager.
# As variaveis individuais existem apenas para execucao local.
# --------------------------------------------------------------------------

def build_conninfo():
    raw = os.getenv("DB_SECRET")
    if raw:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            logger.error("DB_SECRET nao contem JSON valido")
            return None
    else:
        data = {
            "host": os.getenv("DB_HOST"),
            "port": os.getenv("DB_PORT", "5432"),
            "dbname": os.getenv("DB_NAME", "cloudlab"),
            "username": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
        }

    host = data.get("host")
    if not host:
        return None

    return (
        f"host={host} "
        f"port={data.get('port', '5432')} "
        f"dbname={data.get('dbname', 'cloudlab')} "
        f"user={data.get('username')} "
        f"password={data.get('password')} "
        f"connect_timeout=5"
    )


DDL = """
CREATE TABLE IF NOT EXISTS events (
    id          UUID PRIMARY KEY,
    type        VARCHAR(100) NOT NULL,
    source      VARCHAR(100) NOT NULL,
    message     VARCHAR(500) NOT NULL,
    status      VARCHAR(20)  NOT NULL DEFAULT 'received',
    received_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
"""


class Database:
    """Pool de conexoes com inicializacao tolerante a falha."""

    def __init__(self):
        self.pool = None
        self.ready = False
        self.last_error = None

    def start(self):
        threading.Thread(target=self._connect_with_retry, daemon=True).start()

    def _connect_with_retry(self):
        conninfo = build_conninfo()
        if not conninfo:
            self.last_error = "credenciais do banco nao configuradas"
            logger.error("banco nao configurado; aplicacao seguira degradada")
            return

        delay = 2
        for attempt in range(1, 8):
            try:
                pool = ConnectionPool(conninfo, min_size=1, max_size=5, open=True)
                with pool.connection() as conn:
                    conn.execute(DDL)
                self.pool = pool
                self.ready = True
                self.last_error = None
                logger.info(f"banco conectado e tabela verificada na tentativa {attempt}")
                return
            except Exception as exc:
                self.last_error = str(exc).splitlines()[0][:200]
                logger.error(f"falha ao conectar no banco (tentativa {attempt}): {self.last_error}")
                time.sleep(delay)
                delay = min(delay * 2, 30)

        logger.error("banco inacessivel apos as tentativas; aplicacao seguira degradada")

    @contextmanager
    def connection(self):
        if not self.ready or self.pool is None:
            raise HTTPException(
                status_code=503,
                detail="Banco de dados indisponivel. Consulte /health.",
            )
        with self.pool.connection() as conn:
            yield conn


db = Database()


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


class EventStored(BaseModel):
    id: str
    type: str
    source: str
    message: str
    status: str
    received_at: datetime


# --------------------------------------------------------------------------
# Aplicacao
# --------------------------------------------------------------------------

app = FastAPI(
    title=SERVICE_NAME,
    description="Workload minimo para validar decisoes de arquitetura na AWS.",
    version=SERVICE_VERSION,
)


@app.on_event("startup")
def on_startup():
    logger.info("aplicacao iniciada")
    db.start()


@app.get("/api")
def api_root():
    return {"service": SERVICE_NAME, "version": SERVICE_VERSION}


@app.get("/health")
def health():
    body = {
        "status": "healthy" if db.ready else "degraded",
        "version": SERVICE_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "database": "connected" if db.ready else "unavailable",
    }
    if not db.ready and db.last_error:
        body["database_error"] = db.last_error
    return body


@app.post("/events", response_model=EventAccepted, status_code=201)
def receive_event(event: Event):
    event_id = str(uuid.uuid4())

    with db.connection() as conn:
        conn.execute(
            "INSERT INTO events (id, type, source, message) VALUES (%s, %s, %s, %s)",
            (event_id, event.type, event.source, event.message),
        )

    logger.info(
        "event received",
        extra={
            "event": {
                "id": event_id,
                "type": event.type,
                "source": event.source,
                "message": event.message,
                "status": "received",
                "persisted": True,
            }
        },
    )

    return EventAccepted(id=event_id, status="received")


@app.get("/events", response_model=list[EventStored])
def list_events(limit: int = 50):
    limit = max(1, min(limit, 200))

    with db.connection() as conn:
        rows = conn.execute(
            "SELECT id, type, source, message, status, received_at "
            "FROM events ORDER BY received_at DESC LIMIT %s",
            (limit,),
        ).fetchall()

    return [
        EventStored(
            id=str(r[0]), type=r[1], source=r[2],
            message=r[3], status=r[4], received_at=r[5],
        )
        for r in rows
    ]


# --------------------------------------------------------------------------
# Frontend servido pela propria aplicacao: mesma origem, sem CORS.
# --------------------------------------------------------------------------

@app.get("/")
def index():
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
