#!/usr/bin/env python3

import json
import math
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

STATION = os.getenv("WEATHER_STATION")
if not STATION:
    raise RuntimeError("WEATHER_STATION must be set")
PORT = int(os.getenv("WEATHER_PORT", "9190"))
CACHE = Path(os.getenv(
    "WEATHER_CACHE",
    "/var/lib/weather-exporter/latest.json"
))
USER_AGENT = os.getenv(
    "WEATHER_USER_AGENT",
    "Linux-Prometheus-Weather-Exporter/1.0"
)

NWS_URL = (
    f"https://api.weather.gov/stations/"
    f"{STATION}/observations/latest"
)

# Don't hit NWS on every Prometheus scrape.
REFRESH_SECONDS = 600

state = {
    "payload": None,
    "fetch_time": 0.0,
    "fetch_success": 0.0,
    "error": None,
}


def finite(value):
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def measurement(properties, name):
    obj = properties.get(name)
    if isinstance(obj, dict):
        value = obj.get("value")
        if finite(value):
            return float(value)
    return None


def c_to_f(c):
    return c * 9.0 / 5.0 + 32.0


def iso_timestamp(value):
    if not value:
        return None

    try:
        from datetime import datetime
        return datetime.fromisoformat(
            value.replace("Z", "+00:00")
        ).timestamp()
    except Exception:
        return None


def atomic_cache(payload):
    CACHE.parent.mkdir(parents=True, exist_ok=True)

    tmp = CACHE.with_suffix(".tmp")
    tmp.write_text(
        json.dumps(payload, indent=2),
        encoding="utf-8"
    )
    tmp.replace(CACHE)


def load_cache():
    if not CACHE.exists():
        return

    try:
        state["payload"] = json.loads(
            CACHE.read_text(encoding="utf-8")
        )
    except Exception as exc:
        state["error"] = f"cache load: {exc}"


def fetch_weather(force=False):
    now = time.time()

    if (
        not force
        and state["payload"] is not None
        and now - state["fetch_time"] < REFRESH_SECONDS
    ):
        return

    request = urllib.request.Request(
        NWS_URL,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/geo+json",
        },
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=15
        ) as response:
            payload = json.load(response)

        state["payload"] = payload
        state["fetch_time"] = now
        state["fetch_success"] = now
        state["error"] = None

        atomic_cache(payload)

    except Exception as exc:
        # Preserve the last known observation.
        state["fetch_time"] = now
        state["error"] = str(exc)


def metric(name, value, labels=""):
    if value is None or not finite(value):
        return None

    suffix = f"{{{labels}}}" if labels else ""
    return f"{name}{suffix} {value}"


def prometheus():
    fetch_weather()

    payload = state["payload"]

    station = STATION.replace("\\", "\\\\").replace('"', '\\"')
    labels = f'station="{station}",provider="nws"'

    lines = [
        "# HELP weather_exporter_up Whether the exporter has usable weather data.",
        "# TYPE weather_exporter_up gauge",
        metric(
            "weather_exporter_up",
            1 if payload else 0,
            labels
        ),
    ]

    if not payload:
        return "\n".join(x for x in lines if x) + "\n"

    p = payload.get("properties", {})

    temperature = measurement(p, "temperature")
    dewpoint = measurement(p, "dewpoint")
    heat_index = measurement(p, "heatIndex")
    wind_chill = measurement(p, "windChill")

    values = [
        ("weather_temperature_celsius", temperature),
        (
            "weather_temperature_fahrenheit",
            c_to_f(temperature) if temperature is not None else None
        ),

        (
            "weather_relative_humidity_percent",
            measurement(p, "relativeHumidity")
        ),

        ("weather_dewpoint_celsius", dewpoint),
        (
            "weather_dewpoint_fahrenheit",
            c_to_f(dewpoint) if dewpoint is not None else None
        ),

        ("weather_heat_index_celsius", heat_index),
        (
            "weather_heat_index_fahrenheit",
            c_to_f(heat_index) if heat_index is not None else None
        ),

        ("weather_wind_chill_celsius", wind_chill),
        (
            "weather_wind_chill_fahrenheit",
            c_to_f(wind_chill) if wind_chill is not None else None
        ),

        (
            "weather_wind_direction_degrees",
            measurement(p, "windDirection")
        ),
        (
            "weather_wind_speed_meters_per_second",
            measurement(p, "windSpeed")
        ),
        (
            "weather_wind_gust_meters_per_second",
            measurement(p, "windGust")
        ),

        (
            "weather_barometric_pressure_pascals",
            measurement(p, "barometricPressure")
        ),
        (
            "weather_sea_level_pressure_pascals",
            measurement(p, "seaLevelPressure")
        ),

        (
            "weather_visibility_meters",
            measurement(p, "visibility")
        ),

        (
            "weather_max_temperature_last_24_hours_celsius",
            measurement(p, "maxTemperatureLast24Hours")
        ),
        (
            "weather_min_temperature_last_24_hours_celsius",
            measurement(p, "minTemperatureLast24Hours")
        ),

        (
            "weather_precipitation_last_hour_millimeters",
            measurement(p, "precipitationLastHour")
        ),
        (
            "weather_precipitation_last_3_hours_millimeters",
            measurement(p, "precipitationLast3Hours")
        ),
        (
            "weather_precipitation_last_6_hours_millimeters",
            measurement(p, "precipitationLast6Hours")
        ),
    ]

    for name, value in values:
        line = metric(name, value, labels)
        if line:
            lines.append(line)

    observed = iso_timestamp(p.get("timestamp"))

    line = metric(
        "weather_observation_timestamp_seconds",
        observed,
        labels
    )
    if line:
        lines.append(line)

    line = metric(
        "weather_fetch_timestamp_seconds",
        state["fetch_success"],
        labels
    )
    if line:
        lines.append(line)

    if observed:
        line = metric(
            "weather_observation_age_seconds",
            max(0, time.time() - observed),
            labels
        )
        if line:
            lines.append(line)

    # Preserve textual conditions as an info-style metric.
    condition = str(p.get("textDescription") or "Unknown")
    condition = (
        condition
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", " ")
    )

    lines.append(
        'weather_condition_info{'
        f'station="{station}",provider="nws",'
        f'condition="{condition}"'
        '} 1'
    )

    return "\n".join(x for x in lines if x) + "\n"


def normalized_weather():
    fetch_weather()

    payload = state["payload"]
    if not payload:
        return {
            "station": STATION,
            "provider": "nws",
            "available": False,
            "error": state["error"],
        }

    p = payload.get("properties", {})

    temp = measurement(p, "temperature")
    dew = measurement(p, "dewpoint")

    return {
        "station": STATION,
        "provider": "nws",
        "available": True,
        "observation_time": p.get("timestamp"),
        "fetch_time_unix": state["fetch_success"],
        "conditions": p.get("textDescription"),

        "temperature_c": temp,
        "temperature_f": c_to_f(temp) if temp is not None else None,

        "relative_humidity_percent":
            measurement(p, "relativeHumidity"),

        "dewpoint_c": dew,
        "dewpoint_f": c_to_f(dew) if dew is not None else None,

        "wind_direction_degrees":
            measurement(p, "windDirection"),

        "wind_speed_mps":
            measurement(p, "windSpeed"),

        "wind_gust_mps":
            measurement(p, "windGust"),

        "barometric_pressure_pa":
            measurement(p, "barometricPressure"),

        "sea_level_pressure_pa":
            measurement(p, "seaLevelPressure"),

        "visibility_m":
            measurement(p, "visibility"),
    }


class Handler(BaseHTTPRequestHandler):

    def send(self, status, content_type, body):
        encoded = body.encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):

        if self.path == "/metrics":
            self.send(
                200,
                "text/plain; version=0.0.4; charset=utf-8",
                prometheus()
            )
            return

        if self.path == "/weather":
            self.send(
                200,
                "application/json",
                json.dumps(
                    normalized_weather(),
                    indent=2
                ) + "\n"
            )
            return

        if self.path == "/weather/raw":
            fetch_weather()

            if state["payload"] is None:
                self.send(
                    503,
                    "application/json",
                    json.dumps({
                        "error": state["error"]
                    }) + "\n"
                )
            else:
                self.send(
                    200,
                    "application/json",
                    json.dumps(
                        state["payload"],
                        indent=2
                    ) + "\n"
                )
            return

        if self.path == "/health":
            fetch_weather()

            status = 200 if state["payload"] else 503

            self.send(
                status,
                "application/json",
                json.dumps({
                    "ok": bool(state["payload"]),
                    "station": STATION,
                    "provider": "nws",
                    "last_successful_fetch":
                        state["fetch_success"],
                    "error": state["error"],
                }) + "\n"
            )
            return

        self.send(
            404,
            "text/plain",
            "weather exporter\n"
        )

    def log_message(self, format, *args):
        pass


load_cache()

# Populate immediately instead of waiting for the first scrape.
fetch_weather(force=True)

BIND_ADDRESS = os.environ.get("WEATHER_BIND", "127.0.0.1")

server = ThreadingHTTPServer(
    (BIND_ADDRESS, PORT),
    Handler
)

server.serve_forever()
