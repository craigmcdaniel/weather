#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

# ----------------------------
# Console formatting
# ----------------------------
RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'

init() { printf "${CYAN}[INIT]${RESET} %s\n" "$1"; }
ok()   { printf "${GREEN}[ OK ]${RESET} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${RESET} %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${RESET} %s\n" "$1"; exit 1; }

wait_http() {
    local url="$1"
    local name="$2"
    local attempts="${3:-30}"

    for ((i=1; i<=attempts; i++)); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            ok "$name online"
            return 0
        fi
        sleep 2
    done

    fail "$name did not become ready"
}


printf "${CYAN}[INIT]${RESET} Starting appliance setup...\n"

# ----------------------------
# Prerequisites
# ----------------------------
init "Checking host requirements..."

# --- THOTH DOCKER BOOTSTRAP ---
if ! command -v docker >/dev/null 2>&1; then
    warn "Docker is not installed."

    # Do not modify a Proxmox VE hypervisor automatically.
    if command -v pveversion >/dev/null 2>&1 || [[ -d /etc/pve ]]; then
        fail "Proxmox VE host detected. Install THOTH Weather inside a Linux VM or container."
    fi

    [[ -f /etc/os-release ]] ||
        fail "Cannot determine Linux distribution."

    . /etc/os-release

    case "${ID:-}" in
        debian|ubuntu)
            ;;
        *)
            fail "Automatic Docker installation currently supports Debian and Ubuntu only."
            ;;
    esac

    # run-weather.sh is normally launched with root privileges by
    # the .run installer. Refuse an unsafe partial bootstrap otherwise.
    if [[ $EUID -ne 0 ]]; then
        fail "Docker is missing and automatic installation requires root privileges."
    fi

    init "Installing Docker Engine..."

    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt-get update

    apt-get install -y \
        ca-certificates \
        curl \
        docker.io

    init "Installing Docker Compose v2..."

    if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
        apt-get install -y docker-compose-v2
    elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        apt-get install -y docker-compose-plugin
    elif apt-cache show docker-compose >/dev/null 2>&1; then
        apt-get install -y docker-compose
    else
        fail "Docker Engine installed, but a Docker Compose v2 package is unavailable from this host's repositories."
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now docker
    elif command -v service >/dev/null 2>&1; then
        service docker start
    fi

    command -v docker >/dev/null 2>&1 ||
        fail "Docker installation did not produce the docker command."

    docker info >/dev/null 2>&1 ||
        fail "Docker was installed but the Docker Engine is not running."

    docker compose version >/dev/null 2>&1 ||
        fail "Docker Compose v2 installation could not be verified."

    ok "Docker Engine installed"
    ok "Docker Compose v2 installed"
fi
# --- END THOTH DOCKER BOOTSTRAP ---

# --- THOTH COMPOSE BOOTSTRAP ---
if ! docker compose version >/dev/null 2>&1; then
    warn "Docker Compose v2 is not installed."

    [[ -f /etc/os-release ]] ||
        fail "Cannot determine Linux distribution."

    . /etc/os-release

    case "${ID:-}" in
        debian|ubuntu)
            ;;
        *)
            fail "Automatic Docker Compose installation currently supports Debian and Ubuntu only."
            ;;
    esac

    if [[ $EUID -ne 0 ]]; then
        fail "Docker Compose installation requires root privileges."
    fi

    init "Installing Docker Compose v2..."

    apt-get update

    if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
        apt-get install -y docker-compose-v2

    elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        apt-get install -y docker-compose-plugin

    elif apt-cache show docker-compose >/dev/null 2>&1; then
        apt-get install -y docker-compose

    else
        fail "No supported Docker Compose v2 package was found in this host's repositories."
    fi

    docker compose version >/dev/null 2>&1 ||
        fail "Docker Compose was installed but 'docker compose' is still unavailable."

    ok "Docker Compose v2 installed"
fi
# --- END THOTH COMPOSE BOOTSTRAP ---


# Bootstrap lightweight installer dependencies when possible.
MISSING=()

command -v curl >/dev/null 2>&1 || MISSING+=("curl")
command -v jq >/dev/null 2>&1 || MISSING+=("jq")

if ((${#MISSING[@]})); then
    init "Installing required tools: ${MISSING[*]}"

    if command -v apt-get >/dev/null 2>&1; then
        if [[ $EUID -eq 0 ]]; then
            APT=(apt-get)
        elif command -v sudo >/dev/null 2>&1; then
            APT=(sudo apt-get)
        else
            fail "Missing ${MISSING[*]} and sudo is unavailable"
        fi

        "${APT[@]}" update
        "${APT[@]}" install -y "${MISSING[@]}"
    else
        fail "Missing ${MISSING[*]}. Automatic installation currently supports Debian/Ubuntu hosts."
    fi
fi

command -v curl >/dev/null 2>&1 || fail "curl installation failed"
command -v jq >/dev/null 2>&1 || fail "jq installation failed"

# Docker may require root depending on the host.
if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
else
    fail "Docker is installed but cannot be accessed"
fi

"${DOCKER[@]}" compose version >/dev/null 2>&1 ||
    fail "Docker Compose v2 is not installed"

dc() {
    "${DOCKER[@]}" compose "$@"
}

ok "Docker available"
ok "Docker Compose available"
ok "Docker engine accessible"
ok "curl available"
ok "jq available"

echo

# ----------------------------
# ZIP prompt / location resolution
# ----------------------------
while true; do
    echo
    read -rp "Enter your 5-digit ZIP code: " ZIP

    if [[ ! "$ZIP" =~ ^[0-9]{5}$ ]]; then
        warn "ZIP code must contain exactly 5 digits."
        continue
    fi

    init "Resolving ZIP code..."

    if ! ZIP_JSON="$(
        curl -fsS \
          --max-time 15 \
          "https://api.zippopotam.us/us/${ZIP}"
    )"; then
        warn "ZIP code ${ZIP} could not be resolved. Please try another."
        continue
    fi

    LAT="$(jq -r '.places[0].latitude // empty' <<<"$ZIP_JSON")"
    LON="$(jq -r '.places[0].longitude // empty' <<<"$ZIP_JSON")"
    CITY="$(jq -r '.places[0]["place name"] // empty' <<<"$ZIP_JSON")"
    STATE="$(jq -r '.places[0]["state abbreviation"] // empty' <<<"$ZIP_JSON")"

    if [[ -z "$LAT" || -z "$LON" || -z "$CITY" || -z "$STATE" ]]; then
        warn "ZIP code ${ZIP} returned incomplete location data. Please try another."
        continue
    fi

    ok "Location resolved: ${CITY}, ${STATE}"

    init "Querying National Weather Service..."

    UA="THOTH-Weather-Appliance/0.1"

    if ! POINT_JSON="$(
        curl -fsS \
          --max-time 15 \
          -A "$UA" \
          "https://api.weather.gov/points/${LAT},${LON}"
    )"; then
        warn "NWS could not resolve weather coverage for ${ZIP}. Please try another ZIP."
        continue
    fi

    STATIONS_URL="$(jq -r '.properties.observationStations // empty' <<<"$POINT_JSON")"

    if [[ -z "$STATIONS_URL" ]]; then
        warn "No NWS observation-station endpoint was returned for ${ZIP}."
        continue
    fi

    if ! STATION_JSON="$(
        curl -fsS \
          --max-time 15 \
          -A "$UA" \
          "$STATIONS_URL"
    )"; then
        warn "NWS station lookup failed for ${ZIP}. Please try again."
        continue
    fi

    STATION="$(jq -r '.features[0].properties.stationIdentifier // empty' <<<"$STATION_JSON")"

    if [[ -z "$STATION" ]]; then
        warn "No usable NWS observation station was found for ${ZIP}."
        continue
    fi

    ok "Coordinates resolved"
    ok "Nearest weather station: ${STATION}"

    break
done

# ----------------------------
# Write appliance configuration
# ----------------------------
init "Writing appliance configuration..."

cat > "$BASE/.env" <<ENV
WEATHER_ZIP=${ZIP}
WEATHER_CITY=${CITY}
WEATHER_STATE=${STATE}
WEATHER_STATION=${STATION}
WEATHER_LAT=${LAT}
WEATHER_LON=${LON}
ENV

ok "Configuration saved"

# ----------------------------
# Generate location-aware Prometheus configuration
# ----------------------------
init "Configuring telemetry location..."

cat > "$BASE/prometheus/prometheus.yml" <<PROM
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: weather
    static_configs:
      - targets:
          - weather:9190
        labels:
          role: weather
          location_zip: "${ZIP}"
          location_city: "${CITY}"
          location_state: "${STATE}"
          weather_station: "${STATION}"
PROM

ok "Telemetry location configured"

# ----------------------------
# Personalize dashboard location banner
# ----------------------------
init "Updating dashboard location..."

python3 - "$BASE/grafana/dashboards/thoth-weather.json" "$ZIP" "$CITY" "$STATE" "$STATION" <<'PYDASH'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
zip_code = sys.argv[2]
city = sys.argv[3]
state = sys.argv[4]
station = sys.argv[5]

data = json.loads(path.read_text())

for panel in data.get("panels", []):
    if panel.get("id") == 15:
        panel.clear()
        panel.update({
            "id": 15,
            "type": "text",
            "title": "LOCATION",
            "gridPos": {
                "h": 3,
                "w": 24,
                "x": 0,
                "y": 0
            },
            "options": {
                "mode": "markdown",
                "content": f"# {zip_code} — {city}, {state}\n\n### NWS {station}"
            }
        })
        break
else:
    raise SystemExit("LOCATION panel id 15 not found")

path.write_text(json.dumps(data, indent=2) + "\n")
PYDASH

ok "Dashboard location updated"

# ----------------------------
# Start appliance
# ----------------------------
init "Building weather collector..."

dc build weather >/dev/null

ok "Weather collector built"

init "Starting appliance stack..."

dc up -d

ok "Containers started"

# ----------------------------
# Health validation
# ----------------------------
init "Waiting for weather collector..."

for ((i=1; i<=30; i++)); do
    if "${DOCKER[@]}" exec thoth-weather \
        wget -qO- http://127.0.0.1:9190/health 2>/dev/null |
        jq -e '.ok == true' >/dev/null 2>&1; then
        ok "Weather collector online"
        break
    fi

    [[ "$i" -eq 30 ]] && fail "Weather collector did not become ready"
    sleep 2
done

init "Waiting for Prometheus..."
wait_http "http://127.0.0.1:9091/-/ready" "Prometheus"

init "Validating weather target..."

for ((i=1; i<=30; i++)); do
    UP="$(
        curl -fsS \
          --get \
          --data-urlencode 'query=up{job="weather"}' \
          http://127.0.0.1:9091/api/v1/query 2>/dev/null |
        jq -r '.data.result[0].value[1] // "0"'
    )"

    if [[ "$UP" == "1" ]]; then
        ok "Prometheus weather target UP"
        break
    fi

    [[ "$i" -eq 30 ]] && fail "Prometheus cannot scrape weather collector"
    sleep 2
done

init "Waiting for Grafana..."
wait_http "http://127.0.0.1:3001/api/health" "Grafana"

# ----------------------------
# Discover host address
# ----------------------------
HOST_IP="$(
    hostname -I |
    awk '{for (i=1;i<=NF;i++) if ($i !~ /^127\./ && $i !~ /:/) {print $i; exit}}'
)"

[[ -n "$HOST_IP" ]] || HOST_IP="localhost"

# ----------------------------
# Current observation
# ----------------------------
WEATHER="$(
    "${DOCKER[@]}" exec thoth-weather \
      wget -qO- http://127.0.0.1:9190/weather 2>/dev/null || true
)"

TEMP="$(
    jq -r '.temperature_f // "unknown"' <<<"$WEATHER" 2>/dev/null || echo unknown
)"

RH="$(
    jq -r '.relative_humidity_percent // "unknown"' <<<"$WEATHER" 2>/dev/null || echo unknown
)"

COND="$(
    jq -r '.conditions // "unknown"' <<<"$WEATHER" 2>/dev/null || echo unknown
)"

clear

printf "${BOLD}"
cat <<'READY'
========================================
       THOTH WEATHER APPLIANCE
                READY
========================================
READY
printf "${RESET}\n"

printf "Location:      %s, %s\n" "$CITY" "$STATE"
printf "ZIP code:      %s\n" "$ZIP"
printf "NWS station:   %s\n" "$STATION"
printf "Conditions:    %s\n" "$COND"
printf "Temperature:   %s °F\n" "$TEMP"
printf "Humidity:      %.1f %%\n" "$RH" 2>/dev/null || printf "Humidity:      %s %%\n" "$RH"

echo
printf "${GREEN}Collector:     ONLINE${RESET}\n"
printf "${GREEN}Prometheus:    ONLINE${RESET}\n"
printf "${GREEN}Grafana:       ONLINE${RESET}\n"

echo
printf "${BOLD}Please connect to:${RESET}\n\n"
printf "    ${CYAN}http://%s:3001${RESET}\n\n" "$HOST_IP"

echo "The appliance is running."
echo "This window may remain open as the server console."
echo
echo "Press Ctrl+C to stop THOTH Weather safely."
echo "Location and history will be preserved."
echo
echo "To RESET weather data/location but keep the appliance installed:"
echo
echo "    sudo /opt/thoth-weather/reset-weather.sh"
echo
echo "To FULLY UNMOUNT and remove THOTH Weather:"
echo
echo "    sudo /opt/thoth-weather/unmount-weather.sh"
echo

# ----------------------------
# Persistent server console
# ----------------------------
trap '
echo
echo "[INIT] Stopping THOTH Weather..."
cd "$BASE"
dc down
echo
echo "[ OK ] THOTH Weather stopped"
echo "[ OK ] Location and history preserved"
echo
echo "To resume with the same ZIP and history, run:"
echo
echo "    sudo /opt/thoth-weather/run-weather.sh"
echo
echo "To reset all weather state but keep the appliance installed:"
echo
echo "    sudo /opt/thoth-weather/reset-weather.sh"
echo
echo "To fully unmount and remove the appliance:"
echo
echo "    sudo /opt/thoth-weather/unmount-weather.sh"
exit 0
' INT TERM

while true; do
    sleep 60
done
