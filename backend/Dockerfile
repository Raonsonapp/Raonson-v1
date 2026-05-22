# ── Build stage ──────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o raonson-api ./main.go

# ── Run stage ────────────────────────────────────────────────────
FROM alpine:3.19

# HuggingFace Spaces runs as non-root user
RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

# Copy binary
COPY --from=builder /app/raonson-api .

# Create empty templates dir to prevent panic if LoadHTMLGlob is called
RUN mkdir -p templates && \
    echo '<html></html>' > templates/empty.html

# Make binary executable
RUN chmod +x raonson-api

# Switch to non-root user
USER app

# HuggingFace Spaces REQUIRES port 7860
EXPOSE 7860

ENV PORT=7860
ENV GIN_MODE=release

CMD ["./raonson-api"]
