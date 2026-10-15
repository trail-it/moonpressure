# Sources and licensing

Project code and original synthetic traces: MIT, see LICENSE. No upstream implementation source, third-party fixture, font or binary is redistributed. Compiler-generated `.mbti` interfaces are generated artifacts, not handwritten implementation.

- Linux PSI interface: https://docs.kernel.org/accounting/psi.html
- Linux cgroup v2 semantics: https://docs.kernel.org/admin-guide/cgroup-v2.html
- MoonBit core and C FFI documentation: https://docs.moonbitlang.com/en/latest/language/ffi.html
- Contest requirements: https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx (read 2026-10-15).

These are specification references, not copied Linux kernel source. `moonbit.h` is supplied by the user's MoonBit toolchain; it is not vendored. The runtime/compiler and Python/Node/C compiler used for validation are external tools, not packaged project code. CI uses official installation tooling and records actual versions.

`scripts/verify_linux.py` parses same-read raw text independently in Python. Original synthetic filesystem data and replay inputs are created by this project. Real host raw captures stay in ignored demo-output/ and are not public fixtures. Only sanitized pass/fail summaries are distributed.
