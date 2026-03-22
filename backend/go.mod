FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

COPY go.mod ./
RUN go mod download && go mod verify

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o raonson .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata wget
WORKDIR /app
COPY --from=builder /app/raonson .
EXPOSE 10000
HEALTHCHECK --interval=30s --timeout=5s \
  CMD wget -qO- http://localhost:10000/health || exit 1
CMD ["./raonson"]
