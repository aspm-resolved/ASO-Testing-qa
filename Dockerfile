FROM golang:1.23-alpine AS GOLANG
WORKDIR /src
ARG USER
ARG TOKEN
RUN apk --no-cache add make git gcc libtool musl-dev ca-certificates dumb-init \
  && go install golang.org/x/vuln/cmd/govulncheck@latest \
  && go env -w GOPRIVATE="github.com/cloudbees-compliance/*" \
  && git config --global url."https://${USER}:${TOKEN}@github.com".insteadOf  "https://github.com"
COPY go.mod go.sum /src/
RUN go mod download && go mod verify
COPY . /src
RUN go test -short ./...
RUN govulncheck ./... || true
RUN go build -o /tmp/myapp \
        -ldflags="-linkmode 'external' -extldflags '-static'" --buildvcs=0 \
  && go version /tmp/myapp

FROM alpine:3.16
WORKDIR /app/
RUN apk --no-cache add curl lsof ca-certificates \
  && adduser -D nonpriv # create user and group
USER nonpriv
COPY --from=GOLANG /tmp/myapp /app/myapp
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
CMD ["/app/myapp", "start"]
