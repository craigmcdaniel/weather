# THOTH Weather Release Notes

## 0.2.4

Unattended Linux bootstrap release.

- Suppresses interactive needrestart dialogs during package installation.
- Keeps Docker and Docker Compose bootstrap fully non-interactive on supported Debian/Ubuntu hosts.
- Fix discovered during Debian 13 clean-room installation testing.

## 0.2.3

Independent Docker Compose bootstrap release.

- Docker Engine and Docker Compose are now treated as separate prerequisites.
- Fixes hosts where Docker is already installed but Compose v2 is missing.
- Retains Debian `docker-compose` package compatibility.
- Retains Ubuntu `docker-compose-v2` and `docker-compose-plugin` compatibility.
- Fix discovered during bare Debian clean-room testing.

## 0.2.2

Debian Compose compatibility release.

- Adds support for Debian's `docker-compose` package when it provides Compose v2.
- Retains support for `docker-compose-v2`.
- Retains support for `docker-compose-plugin`.
- Fixes bare Debian 13/Trixie bootstrap discovered during clean-room testing.

## 0.2.1

Linux runtime bootstrap release.

- Automatically installs Docker Engine on supported Debian and Ubuntu hosts.
- Automatically installs Docker Compose v2 from the host package repositories.
- Detects Proxmox VE hosts and refuses automatic Docker installation there.
- Detects users who have sudo installed but are not authorized to use it.
- Provides clearer privilege and Docker prerequisite failures.
- Preserves the portable handoff bundle introduced in 0.2.0.

## 0.2.0

Portable handoff release.

- Release directory is now self-contained for human handoff.
- Added INSTALL.txt with a three-step quick-start procedure.
- Bundled README.md with each release.
- Bundled RELEASE_NOTES.md with each release.
- Installer remains self-verifying with SHA-256.
- Release archives remain outside the appliance uninstall path.
- Release tooling now also lives outside the appliance uninstall path.

## 0.1.9

Usability and packaging polish.

- Reduced redundant startup banners.
- Preserved visible SHA-256 verification.
- Added README documentation.
- Added release notes.
- Moved developer release archives outside /opt/thoth-weather.
- Release archives now survive appliance full-unmount.
- Recreated the automated release builder.

## 0.1.8

- Added automated release builder.
- Automated source validation.
- Automated dependency pin validation.
- Automated dashboard validation.
- Automated location-neutrality checks.
- Automated self-extracting installer generation.
- Automated SHA-256 and MD5 generation.
- Automated release archive verification.

## 0.1.7

- Made SHA-256 verification visible during startup.
- Positive checksum test passed.
- Deliberately corrupted installer correctly rejected.
- Added deployment manifest.
- Added deployed version and component information.

## Earlier work

Earlier releases established:

- ZIP-driven NWS discovery.
- Portable Docker Compose deployment.
- Prometheus collection.
- Grafana provisioning.
- Five-minute dashboard refresh.
- Wind-direction mappings.
- Graceful stop.
- Reset mode.
- Full-unmount mode.
- Location-neutral packaging.
