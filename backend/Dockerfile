# ── Build stage ──────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

# Танҳо go.mod - go.sum набошад ҳам кор мекунад
COPY go.mod ./

# Агар go.sum бошад copy мекунем, набошад - мушкил нест
COPY go.su[m] ./

# go mod tidy go.sum-ро худаш месозад
RUN go mod tidy

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o raonson-api ./main.go

# ── Run stage ────────────────────────────────────────────────────
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder /app/raonson-api .

RUN mkdir -p templates && echo '<html></html>' > templates/empty.html

RUN chmod +x raonson-api

USER app

EXPOSE 7860

ENV PORT=7860
ENV GIN_MODE=release

CMD ["./raonson-api"]
