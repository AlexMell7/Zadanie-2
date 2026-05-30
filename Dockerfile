# FROM golang:alpine AS builder

# RUN apk --no-cache add ca-certificates
# WORKDIR /app
# COPY main.go .
# RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o weather-app main.go
# FROM scratch
# LABEL org.opencontainers.image.authors="Oleksandr Melnyk" \
#       org.opencontainers.image.title="Weather-App" \
#       org.opencontainers.image.description="Minimalistyczna aplikacja pogodowa na laboratoria PAwChO"
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# COPY --from=builder /app/weather-app /weather-app
# EXPOSE 8080
# ENTRYPOINT ["/weather-app"]


# MODYFIKACJA DOCKEFILE DLA CZESCI NIEOBOWIAZKOWEJ
FROM --platform=$BUILDPLATFORM golang:alpine AS builder
RUN apk --no-cache add ca-certificates
WORKDIR /app
RUN go mod init weather-app
COPY main.go .
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-s -w" -o weather-app main.go
FROM scratch
LABEL org.opencontainers.image.authors="Oleksandr Melnyk"  org.opencontainers.image.title="Weather-App"
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/weather-app /weather-app
EXPOSE 8080
ENTRYPOINT ["/weather-app"] 