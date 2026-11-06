# This is a test/build environment, not a production importer runtime.
FROM debian@sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392 AS build

RUN --mount=type=secret,id=proxy_ca,required=true,mode=0444 \
    rm /etc/apt/sources.list.d/debian.sources && \
    printf '%s\n' 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20261105T000000Z trixie main' > /etc/apt/sources.list && \
    apt-get -o Acquire::https::CaInfo=/run/secrets/proxy_ca update && \
    apt-get -o Acquire::https::CaInfo=/run/secrets/proxy_ca install --no-install-recommends -y clang-19 python3 ca-certificates libc6-dev unzip && \
    rm -rf /var/lib/apt/lists/*

COPY bend-source.tar.gz bun-linux-x64-baseline.zip /opt/downloads/
RUN mkdir /opt/bend /opt/bun && \
    tar -xzf /opt/downloads/bend-source.tar.gz --strip-components=1 -C /opt/bend && \
    unzip -q /opt/downloads/bun-linux-x64-baseline.zip -d /opt/bun && \
    rm -rf /opt/downloads && \
    dpkg-query -W -f='${Package}=${Version}\n' > /opt/packages.lock

ENV BEND_NO_TELEMETRY=1 BENDRTS="" CC=/usr/bin/clang-19 LANG=C.UTF-8
WORKDIR /work

# Only the native binary and the small exec barrier run in the limited cgroup.
# Keeping the compiler/source tree out also makes isolated per-case launches cheap.
FROM debian@sha256:7378260c0a098d27ac206225db5e7d92b8c7c84ea7afccc86eeb513756bbd392 AS probe
RUN --mount=type=secret,id=proxy_ca,required=true,mode=0444 \
    rm /etc/apt/sources.list.d/debian.sources && \
    printf '%s\n' 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20261105T000000Z trixie main' > /etc/apt/sources.list && \
    apt-get -o Acquire::https::CaInfo=/run/secrets/proxy_ca update && \
    apt-get -o Acquire::https::CaInfo=/run/secrets/proxy_ca install --no-install-recommends -y python3 && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt && dpkg-query -W -f='${Package}=${Version}\n' > /opt/packages.lock
ENV BEND_NO_TELEMETRY=1 BENDRTS="" LANG=C.UTF-8
WORKDIR /scratch
