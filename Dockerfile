FROM golang:1.22

WORKDIR /app

ENV GOSUMDB=off

COPY . .

RUN go get github.com/lib/pq

RUN go mod tidy

RUN go build -o app

CMD ["./app"]
