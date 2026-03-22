FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Copy everything first
COPY . .

# Then generate go.sum and download deps
RUN go mod tidy && \
    go mod download && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o raonson .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata wget
WORKDIR /app
COPY --from=builder /app/raonson .
EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=5s \
  CMD wget -qO- http://localhost:10000/health || exit 1
CMD ["./raonson"]
