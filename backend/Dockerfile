# ── Build stage ──────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

# АВВАЛ ҳамаи кодро copy мекунем
COPY . .

# Баъд go mod tidy - акнун ҳамаи файлҳоро мебинад ва go.sum месозад
RUN go mod tidy

# Build
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
