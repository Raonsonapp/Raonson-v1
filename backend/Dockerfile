FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Кӯчонидани тамоми файлҳо
COPY . .

# Танзим ва боркунии вобастагиҳо
RUN go mod tidy && \
    go mod download && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o raonson .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata wget
WORKDIR /app

# Кӯчонидани файли иҷрошаванда
COPY --from=builder /app/raonson .

# Hugging Face ҳатман порти 7860-ро талаб мекунад!
EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=5s \
  CMD wget -qO- http://localhost:7860/health || exit 1

CMD ["./raonson"]
