#!/usr/bin/env bash
# Flash a built firmware.bin to the OTA app partition over USB, like the
# "Custom .bin" uploader at https://crosspointreader.com/#flash-tools does
# (both write only the app image to app0 at 0x10000; bootloader and partition
# table are left untouched, so this only works on a device already running
# CrossPoint or compatible partitions).
#
#   scripts/usb-flash.sh <env> [port]
#
#   scripts/usb-flash.sh default              # X4/X3 (ESP32-C3), autodetect port
#   scripts/usb-flash.sh x4pro-gh_release      # X4 Pro (ESP32-S3)
#   scripts/usb-flash.sh default /dev/cu.usbmodem1101
#
# Chip is inferred from the env name (x4pro/x4c/sticky/lilygo -> esp32s3,
# everything else -> esp32c3); override with USB_FLASH_CHIP if that's wrong.
# Firmware must already be built into build/<env>/firmware.bin, e.g. via
# scripts/docker-pio.sh run -e <env> && scripts/docker-pio.sh --export <env>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv"
OTA_OFFSET=0x10000  # app0, see partitions.csv

ENV_NAME="${1:-}"
if [ -z "$ENV_NAME" ]; then
  echo "Usage: $0 <env> [port]" >&2
  exit 1
fi
PORT="${2:-}"

FIRMWARE="$ROOT/build/$ENV_NAME/firmware.bin"
if [ ! -f "$FIRMWARE" ]; then
  echo "Not found: $FIRMWARE (build and export it first)" >&2
  exit 1
fi

if [ ! -x "$VENV/bin/esptool.py" ]; then
  echo "esptool not found in $VENV; run: python3 -m venv .venv && .venv/bin/pip install esptool" >&2
  exit 1
fi

case "${USB_FLASH_CHIP:-$ENV_NAME}" in
  *x4pro*|*x4c*|*sticky*|*lilygo*) CHIP=esp32s3 ;;
  *) CHIP=esp32c3 ;;
esac

if [ -z "$PORT" ]; then
  # shellcheck disable=SC2012,SC2231
  CANDIDATES=($(ls /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial* 2>/dev/null))
  if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo "No USB serial device found; plug in the device or pass a port explicitly" >&2
    exit 1
  fi
  if [ "${#CANDIDATES[@]}" -gt 1 ]; then
    echo "Multiple USB serial devices found, pass one explicitly: ${CANDIDATES[*]}" >&2
    exit 1
  fi
  PORT="${CANDIDATES[0]}"
fi

echo "Flashing $FIRMWARE ($CHIP) to $PORT at $OTA_OFFSET"
"$VENV/bin/esptool.py" --chip "$CHIP" --port "$PORT" --baud 921600 \
  write_flash "$OTA_OFFSET" "$FIRMWARE"
