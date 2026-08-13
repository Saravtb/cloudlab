FROM public.ecr.aws/docker/library/python:3.12-slim

LABEL org.opencontainers.image.title="cloudlab-events"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="Workload minimo do Projeto 1 - AWS CloudLab"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py /app/main.py

# A aplicacao nao precisa de privilegios administrativos para escutar na 8000.
USER 10001:10001

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
