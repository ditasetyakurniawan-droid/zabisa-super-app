FROM golang:1.26.7-alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY packages ./packages
COPY services/identity ./services/identity
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app ./services/identity
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
