#!/usr/bin/env bash
set -euo pipefail

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

RESET='\033[0m'
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'

ok()   { printf "${GREEN}[ OK ]${RESET} %s\n" "$1"; }
init() { printf "${CYAN}[INIT]${RESET} %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${RESET} %s\n" "$1"; exit 1; }

echo
init "Fully unmounting THOTH Weather..."

# First perform the normal destructive runtime reset.
"$BASE/reset-weather.sh"

echo
init "Removing installed appliance files..."

cd /
rm -rf "$BASE"

ok "THOTH Weather installation removed"

echo
printf "${YELLOW}THOTH Weather has been fully unmounted.${RESET}\n"
echo
echo "To install and start it again, run the THOTH Weather .run installer."
echo
