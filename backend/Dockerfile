FROM golang:1.21-alpine AS builder
RUN apk add --no-cache git ca-certificates tzdata
WORKDIR /app
COPY . .
RUN go mod tidy && \
    go mod download && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o raonson .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata wget
WORKDIR /app
COPY --from=builder /app/raonson .
EXPOSE 10000
CMD ["./raonson"]
