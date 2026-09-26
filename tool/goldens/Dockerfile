# The one environment the goldens are generated and verified in.
#
# A golden is a picture of what the engine drew, and the engine draws text
# through the host's font rasteriser: FreeType on Linux, DirectWrite on
# Windows, CoreText on macOS. Drawn natively on Windows, with the same Flutter
# and the same fonts, the committed goldens differ in 0.8-5.5% of their pixels,
# every one at a glyph edge. So goldens are only ever made and checked here.
# docs/goldens.md says why each line is pinned and how to run it.

# Pinned by digest: glibc's libm is what dart:math calls for sin and cos.
FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3

# The tag fixes the engine hash, and with it flutter_tester, Skia and the
# FreeType it rasterises with. Changing it means regenerating every golden.
ARG FLUTTER_VERSION=3.47.5

ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/opt/flutter \
    PUB_CACHE=/pub-cache \
    LANG=C.UTF-8 \
    TZ=UTC
ENV PATH=${FLUTTER_HOME}/bin:${PATH}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git rsync unzip xz-utils zip \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" \
      https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
 && git config --global --add safe.directory "${FLUTTER_HOME}" \
 && flutter config --no-analytics --no-cli-animations \
 && dart --disable-analytics \
 && flutter precache --universal --linux --no-android --no-ios --no-web \
 && flutter --version

COPY run.sh /usr/local/bin/helix-goldens
RUN chmod +x /usr/local/bin/helix-goldens

WORKDIR /work
ENTRYPOINT ["helix-goldens"]
