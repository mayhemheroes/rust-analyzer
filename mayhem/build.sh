#!/usr/bin/env bash
#
# mayhem/build.sh — cargo-fuzz parser/reparse targets + syntax crate tests (normal flags).
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SRC:=/mayhem}"
: "${MAYHEM_JOBS:=$(nproc)}"
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

cd "$SRC"

: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes}"
DWARF_FLAGS="-Zdwarf-version=3"

FUZZ_RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing -Zsanitizer=address ${RUST_DEBUG_FLAGS} ${DWARF_FLAGS}"
echo "SANITIZER_FLAGS (base, informational) = ${SANITIZER_FLAGS:-<unset>}"

FUZZ_DIR="crates/syntax/fuzz"
TRIPLE="x86_64-unknown-linux-gnu"

# Bake detect_leaks=0 + a smaller quarantine into the fuzz binaries (Mayhem owns runtime
# ASAN_OPTIONS; this is the spec-approved way to tune leak detection without a Mayhemfile override).
ASAN_DEFAULTS_O="$SRC/mayhem/asan_defaults.o"
cc -c "$SRC/mayhem/asan_defaults.c" -o "$ASAN_DEFAULTS_O"
FUZZ_RUSTFLAGS="$FUZZ_RUSTFLAGS -Clink-arg=$ASAN_DEFAULTS_O"

ASAN_A="$(rustc --print sysroot)/lib/rustlib/${TRIPLE}/lib/librustc-nightly_rt.asan.a"
if [ -f "$ASAN_A" ]; then
  echo "stripping debug info from prebuilt ASan runtime: $ASAN_A"
  objcopy --strip-debug "$ASAN_A" 2>/dev/null || objcopy --remove-section '.debug_*' "$ASAN_A" 2>/dev/null || true
fi

FUZZ_TARGETS=()
for f in "$FUZZ_DIR"/fuzz_targets/*.rs; do
  FUZZ_TARGETS+=("$(basename "${f%.*}")")
done
[ "${#FUZZ_TARGETS[@]}" -gt 0 ] || { echo "ERROR: no fuzz targets under $FUZZ_DIR/fuzz_targets/" >&2; exit 1; }

export CFLAGS="${CFLAGS:-} -gdwarf-3"
export CXXFLAGS="${CXXFLAGS:-} -gdwarf-3"

echo "=== cargo fuzz build (ASan via RUSTFLAGS, DWARF 3) ==="
echo "RUSTFLAGS=$FUZZ_RUSTFLAGS"
echo "CFLAGS=$CFLAGS  CXXFLAGS=$CXXFLAGS"
echo "targets: ${FUZZ_TARGETS[*]}"

for t in "${FUZZ_TARGETS[@]}"; do
  echo "--- building fuzz target: $t ---"
  RUSTFLAGS="$FUZZ_RUSTFLAGS" cargo fuzz build --fuzz-dir "$FUZZ_DIR" -O --debug-assertions "$t"
  bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/$t"
  [ -x "$bin" ] || { echo "ERROR: expected fuzz binary not found at $bin" >&2; exit 1; }
  cp "$bin" "/mayhem/$t"
  echo "built /mayhem/$t"
done

echo "=== cargo test -p syntax --no-run (clean flags, for test.sh) ==="
TEST_RUSTFLAGS="--cap-lints=warn"
( cd "$SRC" && RUSTFLAGS="$TEST_RUSTFLAGS" cargo test -p syntax --no-run )

echo "build.sh complete"
