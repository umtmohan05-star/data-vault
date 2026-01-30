FROM golang:1.24-alpine AS builder

WORKDIR /chaincode

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /healthcare-chaincode

FROM alpine:3.18
WORKDIR /
COPY --from=builder /healthcare-chaincode /healthcare-chaincode

EXPOSE 7052

CMD ["/healthcare-chaincode"]
