// Baked ASan defaults for fuzz binaries (§6.3 — no Mayhemfile ASAN_OPTIONS override).
const char *__asan_default_options(void) {
    return "detect_leaks=0:quarantine_size_mb=1:allocator_may_return_null=1";
}
