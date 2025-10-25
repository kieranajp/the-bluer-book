# Build stage
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata nodejs npm

# Set working directory
WORKDIR /app

# Copy dependency files
COPY go.mod go.sum package.json package-lock.json* ./

# Download dependencies
RUN go mod download
RUN npm ci

# Copy source code
COPY . .

# Build CSS
RUN npm run css

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o bluer-book ./main.go

# Runtime stage
FROM alpine:3.19

# Install CA certificates and timezone data
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN adduser -D -s /bin/sh -u 1000 appuser

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/bluer-book .

# Copy static assets (if they exist)
COPY --from=builder /app/static ./static

# Change ownership to appuser
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Run the application
CMD ["./bluer-book", "server"]
