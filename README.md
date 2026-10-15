# THOTH Weather Appliance

THOTH Weather is a portable weather telemetry appliance using National
Weather Service observations, Prometheus, and Grafana.

Configuration is driven by a five-digit U.S. ZIP code. The appliance
automatically resolves the location and chooses an NWS observation station.

## Installation

Keep these files together:

    thoth-weather-X.Y.Z.run
    thoth-weather-X.Y.Z.run.sha256

Run:

    chmod +x thoth-weather-X.Y.Z.run
    ./thoth-weather-X.Y.Z.run

The installer:

1. Calculates its SHA-256.
2. Compares it with the checksum sidecar when present.
3. Refuses installation on a checksum mismatch.
4. Deploys into /opt/thoth-weather.
5. Checks Docker, Docker Compose, curl, and jq.
6. Prompts for a ZIP code.
7. Resolves an NWS station.
8. Configures Prometheus and Grafana.
9. Starts the appliance.
10. Displays the dashboard address.

## Services

Grafana:
    http://HOST:3001

Prometheus:
    http://127.0.0.1:9091

Weather collector:
    Internal container port 9190

## Lifecycle

Graceful stop:

    Ctrl+C

Resume:

    sudo /opt/thoth-weather/run-weather.sh

Reset configuration and appliance state:

    sudo /opt/thoth-weather/reset-weather.sh

Full appliance unmount:

    sudo /opt/thoth-weather/unmount-weather.sh

Full unmount removes /opt/thoth-weather.

Developer release archives are stored separately:

    /opt/thoth-weather-releases

## Deployment metadata

Installed releases record:

    /opt/thoth-weather/deployment-info

The manifest contains the appliance version, installation timestamp,
Prometheus version, Grafana version, and installer SHA-256.

## Pinned components

Prometheus 3.15.0
Grafana 13.2.4

## Checksums

SHA-256 is the authoritative integrity checksum.

MD5 is retained only as a convenience/legacy checksum and is not a
security mechanism.
