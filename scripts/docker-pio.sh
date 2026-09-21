#!/usr/bin/env bash
# Runs PlatformIO inside the toolchain container (docker/Dockerfile).
#
#   scripts/docker-pio.sh run -e default     # any pio arguments
#   scripts/docker-pio.sh --format           # ./bin/clang-format-fix -g
#   scripts/docker-pio.sh --export [env]     # copy firmware*.bin to build/<env>/ (default env: default)
#   scripts/docker-pio.sh --shell            # interactive shell
#   scripts/docker-pio.sh --rebuild          # rebuild the image, then continue
#
# The very first build on an empty toolchain volume rebuilds the Arduino IDF libs and
# can fail at link time with "No module named 'SCons.Tool.FortranCommon'"; run it again.
#
# Flashing and serial monitoring are not possible from the container on macOS
# (Docker Desktop has no USB passthrough); use the host's pio/esptool for that.
set -euo pipefail

IMAGE="${CROSSPOINT_TOOLCHAIN_IMAGE:-crosspoint-toolchain}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found" >&2
  exit 1
fi

if [ -z "$(ls -A "$ROOT/freeink-sdk" 2>/dev/null)" ]; then
  echo "freeink-sdk submodule is empty; run: git submodule update --init --recursive" >&2
  exit 1
fi

if [ "${1:-}" = "--rebuild" ]; then
  docker rmi "$IMAGE" >/dev/null 2>&1 || true
  shift
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker build -t "$IMAGE" \
    --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" \
    -f "$ROOT/docker/Dockerfile" "$ROOT/docker"
fi

TTY_ARGS=(-i)
[ -t 0 ] && [ -t 1 ] && TTY_ARGS=(-it)

# Toolchain cache and build output live in named volumes: much faster than the
# bind mount on macOS and keeps host-side .pio untouched.
RUN=(docker run --rm "${TTY_ARGS[@]}"
  -v "$ROOT":/workspace
  -v crosspoint-pio-core:/pio
  -v crosspoint-pio-build:/workspace/.pio
  "$IMAGE")

case "${1:-}" in
  --format) exec "${RUN[@]}" ./bin/clang-format-fix -g ;;
  --export)
    ENV_NAME="${2:-default}"
    exec "${RUN[@]}" sh -c 'mkdir -p "build/$1" && cp .pio/build/"$1"/firmware*.bin "build/$1"/ && ls -l "build/$1"' _ "$ENV_NAME"
    ;;
  --shell) exec "${RUN[@]}" bash ;;
  "") exec "${RUN[@]}" pio run ;;
  *) exec "${RUN[@]}" pio "$@" ;;
esac
