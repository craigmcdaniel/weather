# THOTH Weather Appliance

THOTH Weather is a portable Docker/Linux observability lab with a weather workload included as its working **Hello World** example.

The weather application is not the whole point of the project. It is the first workload running on top of a reusable environment built around Prometheus, Grafana, persistent telemetry, Docker Compose, and a small Python collector. The included National Weather Service integration proves that the stack can ingest real data continuously, retain it over time, and visualize it immediately after installation.

In other words:

**Weather is the example workload. The reusable monitoring environment is the project.**

Once installed, the same environment can be extended with additional Prometheus scrape targets, exporters, dashboards, and lab services without rebuilding the platform from scratch. CPU, memory, network, application, security-lab, and other telemetry can be added alongside the weather example.

## Architecture

The included weather workload follows this path:

    National Weather Service
              |
              v
      thoth-weather collector
              |
              v
          Prometheus
              |
              v
            Grafana

The collector exposes weather metrics internally on port 9190. Prometheus stores the time-series data and Grafana provides the dashboard and historical visualization layer.

The services are intentionally separated so the stack remains understandable, reusable, and easy to extend.

## Why the weather workload exists

The weather component gives a fresh installation an immediately useful workload instead of an empty monitoring stack.

It demonstrates:

1. External API ingestion.
2. A Python metrics exporter.
3. Prometheus scraping and time-series retention.
4. PromQL-backed historical queries.
5. Grafana dashboards and visualization.
6. Persistent telemetry across normal runtime.
7. A concrete pattern that can be copied for other workloads.

After the example is running, the environment can be treated as a general-purpose observability lab rather than a weather-only appliance.

## Installation

Configuration is driven by a five-digit U.S. ZIP code. The appliance automatically resolves the location and chooses an NWS observation station.

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

## Extending the lab

The included weather exporter is only one Prometheus target. Additional exporters and applications can be added to the Prometheus configuration and visualized in Grafana using the same running environment.

Typical extensions include:

- host CPU, memory, disk, and network telemetry
- Windows or Linux exporters
- application metrics
- homelab infrastructure monitoring
- cybersecurity-lab telemetry
- additional custom Python exporters

Keep unrelated workloads logically separated with their own metrics, jobs, dashboards, credentials, and data stores where appropriate. The goal is to reuse the platform without turning the example application into a dependency for every future workload.

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

The manifest contains the appliance version, installation timestamp, Prometheus version, Grafana version, and installer SHA-256.

## Pinned components

Prometheus 3.15.0

Grafana 13.2.4

## Checksums

SHA-256 is the authoritative integrity checksum.

MD5 is retained only as a convenience/legacy checksum and is not a security mechanism.
