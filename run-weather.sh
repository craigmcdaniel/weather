#!/usr/bin/env bash
set -e

# --- THOTH DEPLOYMENT INFO ---
THOTH_BASE="/opt/thoth-weather"
THOTH_VERSION="unknown"
THOTH_INSTALLED_AT="unknown"
THOTH_PROMETHEUS="unknown"
THOTH_GRAFANA="unknown"
THOTH_INSTALLER_SHA256="unknown"

if [[ -f "$THOTH_BASE/VERSION" ]]; then
    THOTH_VERSION="$(tr -d '\r\n' < "$THOTH_BASE/VERSION")"
fi

if [[ -f "$THOTH_BASE/deployment-info" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            version) THOTH_VERSION="$value" ;;
            installed_at) THOTH_INSTALLED_AT="$value" ;;
            prometheus) THOTH_PROMETHEUS="$value" ;;
            grafana) THOTH_GRAFANA="$value" ;;
            installer_sha256) THOTH_INSTALLER_SHA256="$value" ;;
        esac
    done < "$THOTH_BASE/deployment-info"
fi

echo
echo "THOTH Weather Appliance v${THOTH_VERSION}"

if [[ -f "$THOTH_BASE/deployment-info" ]]; then
    echo "Installed:   $THOTH_INSTALLED_AT"
    echo "Prometheus:  $THOTH_PROMETHEUS"
    echo "Grafana:     $THOTH_GRAFANA"

    if [[ "$THOTH_INSTALLER_SHA256" != "unknown" ]]; then
        echo "Build SHA:   ${THOTH_INSTALLER_SHA256:0:12}"
    fi
fi

echo
# --- END THOTH DEPLOYMENT INFO ---


HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

exec bash "$HERE/install.sh"
