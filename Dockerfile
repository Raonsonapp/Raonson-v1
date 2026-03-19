FROM golang:1.22

WORKDIR /app

COPY . .

RUN rm -f go.sum
RUN go mod tidy
RUN go build -o main

CMD ["./main"] master
