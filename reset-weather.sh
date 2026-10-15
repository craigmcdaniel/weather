#!/usr/bin/env bash
set -euo pipefail

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$BASE"

RESET='\033[0m'
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'

ok()   { printf "${GREEN}[ OK ]${RESET} %s\n" "$1"; }
init() { printf "${CYAN}[INIT]${RESET} %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${RESET} %s\n" "$1"; exit 1; }

if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
else
    fail "Docker engine is unavailable"
fi

dc() {
    "${DOCKER[@]}" compose "$@"
}

echo
init "Resetting THOTH Weather..."

dc down -v --remove-orphans

ok "Containers removed"
ok "Prometheus history cleared"
ok "Weather cache cleared"
ok "Grafana runtime state cleared"

rm -f "$BASE/.env"

cat > "$BASE/prometheus/prometheus.yml" <<'PROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs: []
PROM

# Remove the previous literal location from the dashboard template.
python3 - "$BASE/grafana/dashboards/thoth-weather.json" <<'PY'
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
d = json.loads(p.read_text())

for panel in d.get("panels", []):
    if panel.get("id") == 15:
        panel["type"] = "text"
        panel["title"] = "LOCATION"
        panel["options"] = {
            "mode": "markdown",
            "content": "# Location configured at first launch"
        }
        panel.pop("targets", None)
        panel.pop("datasource", None)
        break

p.write_text(json.dumps(d, indent=2) + "\n")
PY

ok "ZIP/location configuration cleared"
ok "Dashboard location cleared"

echo
printf "${YELLOW}THOTH Weather has been reset.${RESET}\n"
echo "The appliance remains installed."
echo "The next launch will ask for a ZIP code."
echo
echo "To start fresh, run:"
echo
echo "    sudo /opt/thoth-weather/run-weather.sh"
echo
