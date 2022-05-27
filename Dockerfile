#FROM registry1.dso.mil/ironbank/google/golang/golang-1.18:latest
FROM docker.io/golang:latest
LABEL maintainer="Frank Naw <franknaw@gmail.com>"
LABEL version="0.0.1"
LABEL description="Go Simple API"

ENV PORT=8080

RUN cat /etc/os-release

RUN mkdir /myapp
COPY go.mod /myapp
COPY go.sum /myapp
COPY *.go /myapp

WORKDIR /myapp

RUN go mod download

# set linker flags -s and -w to get the smallest binaries
# -s: turns off generation of the Go symbol table
# downside:  you will not be able to use go tool nm to list the symbols in the binary
# -w: turns off DWARF debugging information:
# downside: You won't be able to run gdb or various other non-Go-specific tools.
RUN GOOS=linux GOARCH=amd64 go build -o /simple-ping -ldflags="-s -w"

EXPOSE $PORT

CMD ["/simple-ping"]
