# ─────────────────────────────────────────────────────────────
# guacd 1.5.5 — Debian (glibc) 版本
#
# 官方 guacamole/guacd 镜像基于 Alpine (musl libc)，当并发 fork
# 子进程 >50 时 musl 动态链接器 (ld-musl-x86_64.so.1) 会 segfault。
# 本镜像改用 Debian bookworm (glibc) 彻底规避此问题。
#
# 与官方镜像一致，FreeRDP 从源码编译（非系统包），确保
# guacamole channel plugins 正确生成。
# ─────────────────────────────────────────────────────────────

ARG DEBIAN_VERSION=bookworm
ARG GUACD_VERSION=1.5.5
ARG FREERDP_VERSION=2.11.5

# ── Stage 1: Build FreeRDP ────────────────────────────────────
FROM debian:${DEBIAN_VERSION}-slim AS freerdp-builder

ARG FREERDP_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    pkg-config \
    # FreeRDP 依赖
    libssl-dev \
    libx11-dev \
    libxext-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxkbfile-dev \
    libxv-dev \
    libxi-dev \
    libxdamage-dev \
    libxrandr-dev \
    libxfixes-dev \
    libcups2-dev \
    libpcsclite-dev \
    libasound2-dev \
    libpulse-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    libicu-dev \
    libavcodec-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libcairo2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/FreeRDP/FreeRDP/archive/refs/tags/${FREERDP_VERSION}.tar.gz" \
        -o /tmp/freerdp.tar.gz \
    && tar xzf /tmp/freerdp.tar.gz -C /tmp \
    && rm /tmp/freerdp.tar.gz

WORKDIR /tmp/FreeRDP-${FREERDP_VERSION}

RUN cmake -B build \
        -DCMAKE_INSTALL_PREFIX=/opt/guacamole \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_CLIENT=OFF \
        -DWITH_SERVER=OFF \
        -DWITH_CHANNELS=ON \
        -DWITH_CUPS=ON \
        -DWITH_PULSE=ON \
        -DWITH_JPEG=OFF \
        -DBUILTIN_CHANNELS=OFF \
        -DCHANNEL_URBDRC=OFF \
    && cmake --build build -j$(nproc) \
    && cmake --install build

# ── Stage 2: Build guacd ──────────────────────────────────────
FROM debian:${DEBIAN_VERSION}-slim AS guacd-builder

ARG GUACD_VERSION

# 从 FreeRDP builder 复制编译产物
COPY --from=freerdp-builder /opt/guacamole /opt/guacamole

# 让 pkg-config 和 ld 找到自编译的 FreeRDP
ENV PKG_CONFIG_PATH=/opt/guacamole/lib/x86_64-linux-gnu/pkgconfig:/opt/guacamole/lib/pkgconfig
ENV LD_LIBRARY_PATH=/opt/guacamole/lib/x86_64-linux-gnu:/opt/guacamole/lib

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # 必需库
    libcairo2-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libltdl-dev \
    uuid-dev \
    # Pango
    libpango1.0-dev \
    # SSH
    libssh2-1-dev \
    # Telnet
    libtelnet-dev \
    # VNC
    libvncserver-dev \
    # WebSocket
    libwebsockets-dev \
    # 音频
    libpulse-dev \
    libvorbis-dev \
    # FFmpeg
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    # OpenSSL
    libssl-dev \
    # WebP
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# 配置 ldconfig 以便编译时找到 FreeRDP
RUN echo "/opt/guacamole/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/guacamole.conf \
    && echo "/opt/guacamole/lib" >> /etc/ld.so.conf.d/guacamole.conf \
    && ldconfig

# 下载并编译 guacamole-server
RUN curl -fsSL "https://apache.org/dyn/closer.lua/guacamole/${GUACD_VERSION}/source/guacamole-server-${GUACD_VERSION}.tar.gz?action=download" \
        -o /tmp/guacamole-server.tar.gz \
    && tar xzf /tmp/guacamole-server.tar.gz -C /tmp \
    && rm /tmp/guacamole-server.tar.gz

WORKDIR /tmp/guacamole-server-${GUACD_VERSION}

RUN autoreconf -fi \
    && ./configure \
        --prefix=/opt/guacamole \
        --disable-static \
        --with-freerdp-plugin-dir=/opt/guacamole/lib/x86_64-linux-gnu/freerdp2 \
    && make -j$(nproc) \
    && make install

# ── Stage 3: Runtime ──────────────────────────────────────────
FROM debian:${DEBIAN_VERSION}-slim

# 从 builder 复制所有编译产物（FreeRDP + guacd）
COPY --from=guacd-builder /opt/guacamole /opt/guacamole

RUN apt-get update && apt-get install -y --no-install-recommends \
    # 运行时库
    libcairo2 \
    libjpeg62-turbo \
    libpng16-16 \
    libltdl7 \
    libuuid1 \
    # Pango
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    # SSH / Telnet / VNC
    libssh2-1 \
    libtelnet2 \
    libvncclient1 \
    # WebSocket
    libwebsockets17 \
    # 音频
    libpulse0 \
    libvorbis0a \
    libvorbisenc2 \
    libasound2 \
    # FFmpeg
    libavcodec59 \
    libavformat59 \
    libavutil57 \
    libswscale6 \
    # OpenSSL
    libssl3 \
    # WebP
    libwebp7 \
    # ICU（FreeRDP NLA 需要）
    libicu72 \
    # X11 运行时（FreeRDP 需要）
    libx11-6 \
    libxext6 \
    libxinerama1 \
    libxcursor1 \
    libxkbfile1 \
    libxv1 \
    libxi6 \
    libxdamage1 \
    libxrandr2 \
    libxfixes3 \
    # CUPS（打印支持）
    libcups2 \
    # 字体（RDP 需要）
    fonts-dejavu \
    fonts-liberation \
    # 工具
    ghostscript \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# 配置动态链接器路径
RUN echo "/opt/guacamole/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/guacamole.conf \
    && echo "/opt/guacamole/lib" >> /etc/ld.so.conf.d/guacamole.conf \
    && ldconfig

# 创建非 root 用户，home 目录设为可写（FreeRDP 需要存储证书）
RUN groupadd -g 1000 guacd && \
    useradd -u 1000 -g guacd -d /home/guacd -s /sbin/nologin guacd && \
    mkdir -p /home/guacd/.config/freerdp/certs /home/guacd/.config/freerdp/server && \
    chown -R guacd:guacd /home/guacd

# 健康检查
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=5s \
    CMD nc -z localhost 4822 || exit 1

EXPOSE 4822

USER guacd

CMD ["/opt/guacamole/sbin/guacd", "-b", "0.0.0.0", "-L", "info", "-f"]
