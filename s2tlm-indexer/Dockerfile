# Use Rust nightly image
FROM rustlang/rust:nightly-slim AS builder

# Install dependencies needed for building
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Set workdir and copy source
WORKDIR /usr/src/app
COPY . .

# Build with nightly
RUN cargo +nightly build --release --package indexer-singlejp2

# ---
# Final lightweight image
FROM debian:bookworm-slim

# Install runtime deps (if needed)
RUN apt-get update && apt-get install -y libssl-dev && rm -rf /var/lib/apt/lists/*

# Copy binary
COPY --from=builder /usr/src/app/target/release/indexer-singlejp2 /usr/local/bin/

# Default to binary
ENTRYPOINT ["indexer-singlejp2"]