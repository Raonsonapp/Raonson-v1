FROM golang:1.22

WORKDIR /app

ENV GOSUMDB=off

COPY go.mod ./

RUN go mod tidy

COPY . .

RUN go build -o app

CMD ["./app"]
