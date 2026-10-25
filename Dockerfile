# Build go
FROM golang:1.27.1-alpine AS builder
WORKDIR /app
COPY . .
ENV CGO_ENABLED=0
RUN GOEXPERIMENT=jsonv2 go mod download
RUN GOEXPERIMENT=jsonv2 go build -v -o xiaov2bXray -tags "sing xray with_quic with_grpc with_utls with_wireguard with_acme with_gvisor" -trimpath -ldflags "-s -w -buildid=" .

# Release
FROM alpine:latest
# 安装时区和证书
RUN apk --update --no-cache add tzdata ca-certificates \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN mkdir -p /etc/xiaov2bXray/
COPY --from=builder /app/xiaov2bXray /usr/local/bin/

ENTRYPOINT [ "xiaov2bXray", "server", "--config", "/etc/xiaov2bXray/config.json"]
