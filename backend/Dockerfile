FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

USER nobody
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --proxy-headers --no-server-header
