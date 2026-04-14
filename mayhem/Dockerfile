# Build Stage
FROM --platform=linux/amd64 rustlang/rust:nightly AS builder

RUN cargo install cargo-fuzz

ADD . /src
WORKDIR /src/crates/syntax

RUN cargo +nightly fuzz build && \
    mv fuzz/target/x86_64-unknown-linux-gnu/release/parser /parser && \
    mv fuzz/target/x86_64-unknown-linux-gnu/release/reparse /reparse

# Package Stage
FROM ubuntu:22.04

COPY --from=builder /parser /reparse /
