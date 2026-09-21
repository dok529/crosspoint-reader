# Build toolchain for CrossPoint Reader. Mirrors .github/workflows/ci.yml.
# Use via scripts/docker-pio.sh; the repo is bind-mounted at /workspace.
FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates xz-utils unzip cmake ninja-build build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv

RUN uv pip install --system --no-cache \
      https://github.com/pioarduino/platformio-core/archive/refs/tags/v6.1.19.zip \
    && uv pip install --system --no-cache \
      "littlefs-python>=0.16.0" "fatfs-ng>=0.1.14" "pyyaml>=6.0.2" \
      "rich-click>=1.8.6" "zopfli>=0.2.2" "intelhex>=2.3.0" "rich>=14.0.0" "urllib3<2" \
      "cryptography>=45.0.3" "certifi>=2025.8.3" "ecdsa>=0.19.1" "bitstring>=4.3.1" \
      "reedsolo>=1.5.3,<1.8" "esp-idf-size>=2.0.0" "esp-coredump>=1.14.0" \
      "clang-format>=21,<22"

# Match the host user so files written to the bind mount and named volumes are owned by the caller.
ARG UID=1000
ARG GID=1000
RUN groupadd -o -g "${GID}" builder \
    && useradd -o -m -u "${UID}" -g "${GID}" builder \
    && mkdir -p /pio /workspace/.pio \
    && chown -R builder:builder /pio /workspace \
    && git config --system --add safe.directory '*'

ENV PLATFORMIO_CORE_DIR=/pio \
    PLATFORMIO_CHECK_PLATFORMIO_INTERVAL=0 \
    PLATFORMIO_SETTING_ENABLE_TELEMETRY=no

USER builder
WORKDIR /workspace
CMD ["pio", "run"]
