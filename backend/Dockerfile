# ── Build stage ──────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install git (needed for go mod download)
RUN apk add --no-cache git

COPY go.mod go.sum ./

# Download + verify all dependencies (fixes missing go.sum entries)
RUN go mod download && go mod verify

COPY . .

# Tidy ensures go.sum is complete, then build
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -o raonson-api ./main.go

# ── Run stage ────────────────────────────────────────────────────
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

# HuggingFace runs as non-root
RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder /app/raonson-api .

# Create empty templates dir (prevents LoadHTMLGlob panic if called anywhere)
RUN mkdir -p templates && echo '<html></html>' > templates/empty.html

RUN chmod +x raonson-api

USER app

# HuggingFace Spaces REQUIRES port 7860
EXPOSE 7860

ENV PORT=7860
ENV GIN_MODE=release

CMD ["./raonson-api"]
