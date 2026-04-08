# guacd-debian

[![Docker Build](https://github.com/jasonwwl/docker-guacd/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/jasonwwl/docker-guacd/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/wenleigood/guacd-debian)](https://hub.docker.com/r/wenleigood/guacd-debian)

[Apache Guacamole](https://guacamole.apache.org/) guacd built on **Debian (glibc)** instead of Alpine (musl libc).

## Why?

The official `guacamole/guacd` image is based on Alpine Linux which uses musl libc. When guacd forks >50 child processes concurrently, musl's dynamic linker (`ld-musl-x86_64.so.1`) hits a race condition that causes segfaults (see [GUACAMOLE-2135](https://issues.apache.org/jira/browse/GUACAMOLE-2135)). This affects guacd 1.5.5 and 1.6.0.

This image uses **Debian Bookworm (glibc)** to completely eliminate the issue.

### Key differences from the official image

| | Official (`guacamole/guacd`) | This image (`wenleigood/guacd-debian`) |
|---|---|---|
| Base OS | Alpine (musl libc) | Debian Bookworm (glibc) |
| High-concurrency stability | Segfaults at >50 forks | Stable (tested with 73+ concurrent connections) |
| FreeRDP | Source-compiled | Source-compiled (same approach) |
| NLA authentication | Works | Works (writable home dir for cert storage) |

### Build details

- **3-stage build**: FreeRDP source compile -> guacd source compile (linked to custom FreeRDP) -> minimal runtime image
- **FreeRDP must be source-compiled**: System packages (`apt install freerdp2-dev`) won't generate guacamole channel plugins, causing NLA security negotiation failures
- **Writable home directory**: FreeRDP requires a writable home to store certificates; user home is set to `/home/guacd` with pre-created `.config/freerdp/{certs,server}` directories

## Quick Start

```bash
docker run -d --name guacd -p 4822:4822 wenleigood/guacd-debian:latest
```

## Tags

| Tag | Description |
|---|---|
| `latest` | Latest stable build (guacd 1.5.5, FreeRDP 2.11.5) |
| `1.5.5` | guacd 1.5.5 + FreeRDP 2.11.5 |

## Supported Protocols

- **RDP** (via source-compiled FreeRDP 2.11.5)
- **VNC** (via libvncclient)
- **SSH** (via libssh2)
- **Telnet** (via libtelnet)

## Build Locally

```bash
docker build -t guacd-debian .
```

### Build Arguments

| Arg | Default | Description |
|---|---|---|
| `DEBIAN_VERSION` | `bookworm` | Debian release |
| `GUACD_VERSION` | `1.5.5` | Apache Guacamole server version |
| `FREERDP_VERSION` | `2.11.5` | FreeRDP version |

## Health Check

Built-in health check via `nc -z localhost 4822` (interval: 10s, timeout: 5s, retries: 3).

## License

Apache License 2.0 (same as Apache Guacamole)

