FROM python:3.13-alpine

WORKDIR /app

COPY weather-exporter.py /app/weather-exporter.py

RUN mkdir -p /data

ENV WEATHER_PORT=9190
ENV WEATHER_CACHE=/data/latest.json
ENV WEATHER_USER_AGENT=THOTH-Weather-Container/0.1

EXPOSE 9190

CMD ["python3", "/app/weather-exporter.py"]
