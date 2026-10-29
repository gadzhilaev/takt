FROM python:3.12-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends curl \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --create-home --uid 10001 appuser

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini .
COPY alembic ./alembic/
COPY app ./app/

RUN mkdir -p /data/uploads && chown -R appuser:appuser /data/uploads

USER appuser
ENV PYTHONUNBUFFERED=1
EXPOSE 8000

HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
