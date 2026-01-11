FROM rust:1.86-slim

SHELL ["bash", "-c"]

# Install dependencies including lld (faster, lower-memory linker)
RUN apt-get update && apt-get install -y \
    pkg-config \
    protobuf-compiler \
    clang \
    lld \
    make \
    jq \
    git \
    curl \
    python3

# Clone repository
RUN git clone https://github.com/linera-io/linera-protocol.git && \
    cd linera-protocol && \
    git checkout 288296873fb92eda7ced5e825d5c1d0dd49aec42

# Build storage server first (smaller binary)
RUN cd linera-protocol && \
    CARGO_BUILD_JOBS=2 cargo install --locked --path linera-storage-service

# Build linera service with memory-optimized settings:
# - Use lld linker (lower memory usage than default ld)
# - Single codegen unit reduces peak memory during linking
# - Single job to avoid parallel linking OOM
RUN cd linera-protocol && \
    CARGO_BUILD_JOBS=1 \
    RUSTFLAGS="-C linker=clang -C link-arg=-fuse-ld=lld -C codegen-units=1" \
    cargo install --locked --path linera-service

WORKDIR /build

HEALTHCHECK CMD ["curl", "-s", "http://localhost:5173"]

ENTRYPOINT bash /build/docker-run.sh
