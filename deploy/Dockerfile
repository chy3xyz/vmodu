# VModu Runtime - Multi-stage Dockerfile
# Supports: development, production, and minimal builds

# ═══════════════════════════════════════════════════════════════
# Stage 1: Builder
# ═══════════════════════════════════════════════════════════════
FROM thevlang/vlang:alpine AS builder

LABEL maintainer="VModu Team <team@vmodu.io>"
LABEL description="VModu — modular backend framework for V"

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    git \
    gcc \
    musl-dev \
    openssl-dev \
    postgresql-dev \
    sqlite-dev \
    make

# Copy source (main entry + library + CLI)
COPY v.mod .
COPY main.v .
COPY vmodu/ vmodu/
COPY cmd/ cmd/
COPY config.json .

# Build default runtime (infra/http + /health + /metrics)
RUN v -prod -o vmodu-runtime main.v

# Build CLI tool
RUN v -prod -o vmodu-cli ./cmd/vmodu-cli

# ═══════════════════════════════════════════════════════════════
# Stage 2: Production Runtime
# ═══════════════════════════════════════════════════════════════
FROM alpine:3.19 AS production

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    libpq \
    sqlite-libs \
    && addgroup -g 1000 vmodu \
    && adduser -u 1000 -G vmodu -s /bin/sh -D vmodu

# Copy binaries from builder
COPY --from=builder /build/vmodu-runtime /usr/local/bin/
COPY --from=builder /build/vmodu-cli /usr/local/bin/

# Copy configs
COPY --from=builder /build/config.json /etc/vmodu/
COPY deploy/config/ /etc/vmodu/

# Create data directory
RUN mkdir -p /data/vmodu && chown -R vmodu:vmodu /data/vmodu

USER vmodu

# Expose ports
# 8080: HTTP API
# 9000: gRPC
# 9090: Metrics/Prometheus
EXPOSE 8080 9000 9090

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD vmodu-cli health || exit 1

ENTRYPOINT ["vmodu-runtime"]
CMD ["--config", "/etc/vmodu/config.json"]

# ═══════════════════════════════════════════════════════════════
# Stage 3: Development Runtime
# ═══════════════════════════════════════════════════════════════
FROM thevlang/vlang:alpine AS development

WORKDIR /app

# Install development dependencies
RUN apk add --no-cache \
    git \
    gcc \
    musl-dev \
    openssl-dev \
    postgresql-dev \
    sqlite-dev \
    make \
    curl

# Copy source
COPY . .

EXPOSE 8080 9000 9090

CMD ["v", "-enable-globals", "run", "."]

# ═══════════════════════════════════════════════════════════════
# Stage 4: Minimal Runtime (for edge/IoT)
# ═══════════════════════════════════════════════════════════════
FROM alpine:3.19 AS minimal

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /build/vmodu-runtime /usr/local/bin/
COPY --from=builder /build/config.json /etc/vmodu/
COPY deploy/config/ /etc/vmodu/

EXPOSE 8080

ENTRYPOINT ["vmodu-runtime"]
