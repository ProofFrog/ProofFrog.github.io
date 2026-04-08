---
title: Command-Line Interface
layout: default
parent: Manual
nav_order: 60
---

# CLI Reference

The ProofFrog command-line interface (`proof_frog`) lets you parse, type-check, and verify cryptographic game-hopping proofs entirely from the terminal. Six public commands cover the full workflow from inspecting files to running complete proof verification. If you prefer a graphical environment, a browser-based editor is also available via the `web` command described below.

{: .important }
**Activate your Python virtual environment first.** All of the commands below assume that the virtual environment in which ProofFrog was installed is activated in the current terminal session. If you opened a new terminal, re-activate it before running any `proof_frog` (or `python -m proof_frog`) command: `source .venv/bin/activate` on macOS/Linux (bash/zsh), `source .venv/bin/activate.fish` on fish, or `.venv\Scripts\Activate.ps1` on Windows PowerShell. See [Installation]({% link manual/installation.md %}) for details. A `command not found: proof_frog` error almost always means the virtual environment is not active.

## Command Summary

| Command | Description |
|---------|-------------|
| [`version`](#version) | Print the ProofFrog version. |
| [`parse`](#parse) | Parse a FrogLang file and print its AST. |
| [`check`](#check) | Type-check and semantically analyze a FrogLang file. |
| [`prove`](#prove) | Run proof verification on a `.proof` file. |
| [`describe`](#describe) | Print a concise interface description of a FrogLang file. |
| [`web`](#web) | Start the ProofFrog web interface. |

---

## version

### Synopsis

```
python -m proof_frog version [OPTIONS]
```

### Behavior

Prints the installed ProofFrog version string to standard output and exits. The output format is `ProofFrog <version>`, for example `ProofFrog 0.4.0.dev0` on development builds. Use this to confirm which release is active in your environment or to include version information in bug reports.

### Examples

```bash
# Print the installed version
python -m proof_frog version
```

Expected output (version may differ):

```
ProofFrog 0.4.0.dev0
```

---

## parse

### Synopsis

```
python -m proof_frog parse [OPTIONS] FILE
```

### Behavior

Parses any FrogLang source file (`.primitive`, `.scheme`, `.game`, or `.proof`) and prints a normalized source representation of the parsed file to standard output. The default output is a pretty-printed form (useful for confirming the parser saw what you intended); the `--json` flag instead emits a JSON-encoded AST suitable for tooling. This command is mainly useful for debugging grammar issues. If the file cannot be parsed, ProofFrog prints an error with the offending line and column and exits with a non-zero status.

### Options

| Flag | Description |
|------|-------------|
| `-j`, `--json` | Output JSON instead of the default text representation. |

### Examples

```bash
# Parse a primitive definition
python -m proof_frog parse examples/Primitives/PRG.primitive

# Parse a scheme and get JSON output
python -m proof_frog parse --json examples/joy/Schemes/SymEnc/OTP.scheme

# Parse a proof file
python -m proof_frog parse examples/joy/Proofs/Ch2/OTPSecure.proof
```

### Common Errors

**Parse error at line N, column M** — The file contains a syntax error. The message indicates the exact position; check for missing semicolons, unbalanced braces, or unknown keywords near that location.

---

## check

### Synopsis

```
python -m proof_frog check [OPTIONS] FILE
```

### Behavior

Type-checks and performs semantic analysis on any FrogLang file. This goes beyond parsing: ProofFrog verifies that types are used consistently, that scheme implementations match the signatures declared in the corresponding primitive, that method modifiers (`deterministic`, `injective`) match between the scheme and the primitive it extends, and that all referenced identifiers are in scope. Running `check` is a good first step before `prove` — it catches structural errors quickly without the overhead of full equivalence checking. On success, `check` prints `<file> is well-formed.` and exits with status 0. On failure it prints a diagnostic and exits with a non-zero status.

### Options

| Flag | Description |
|------|-------------|
| `-j`, `--json` | Output JSON instead of the default text representation. |

### Examples

```bash
# Type-check a symmetric encryption scheme
python -m proof_frog check examples/joy/Schemes/SymEnc/OTP.scheme

# Type-check a primitive definition
python -m proof_frog check examples/Primitives/SymEnc.primitive

# Check a proof file and emit JSON diagnostics
python -m proof_frog check --json examples/joy/Proofs/Ch2/OTPSecure.proof
```

### Common Errors

**Type error** — An expression or assignment involves incompatible types. The error message names the conflicting types and the relevant line.

**Modifier mismatch** — A scheme method declares a `deterministic`/`injective` modifier that differs from what the primitive's signature requires. Align the modifiers between the scheme and the primitive it extends.

---

## prove

### Synopsis

```
python -m proof_frog prove [OPTIONS] FILE
```

### Behavior

Verifies a game-hopping proof written in a `.proof` file. ProofFrog works through each game-hop step, reduces both sides to canonical form, and checks equivalence. If every step is valid and the proof begins and ends at the required security games, the proof is accepted.

By default ProofFrog runs equivalence checks in parallel. Pass `--sequential` (or set the environment variable `PROOFFROG_SEQUENTIAL=1`) to force single-process execution, which is useful for reproducible output in CI environments.

Pass `-v` once to print the canonical game form after each hop, which is invaluable for diagnosing why a step fails. Pass `-vv` to additionally show which transformation rules fire during canonicalization.

### Options

| Flag | Description |
|------|-------------|
| `-v`, `--verbose` | Increase verbosity. Use `-v` to print each game's canonical form; use `-vv` to also show transformation activity. |
| `-j`, `--json` | Output JSON instead of the default text representation. |
| `--no-diagnose` | Suppress diagnostic analysis on failure (print summary only). |
| `--skip-lemmas` | Skip lemma proof verification (trust lemmas without re-checking). |
| `--sequential` | Disable parallel equivalence checking (use a single process). Can also be forced via the `PROOFFROG_SEQUENTIAL` environment variable. |

{: .important }
`--skip-lemmas` bypasses verification of any lemmas referenced by the proof and trusts them unconditionally. Use this only during iterative development when you have already confirmed that the lemmas are correct and want faster turnaround on the main proof steps. Never use it as a substitute for verifying a complete proof.

### Examples

```bash
# Verify the OTP security proof from Joy of Cryptography examples
python -m proof_frog prove examples/joy/Proofs/Ch2/OTPSecure.proof

# Verbose: print canonical game forms at each hop
python -m proof_frog prove -v examples/joy/Proofs/Ch2/OTPSecure.proof

# Very verbose: also show transformation rule firings
python -m proof_frog prove -vv examples/joy/Proofs/Ch2/OTPSecure.proof

# Verify a PRG security proof, skipping lemma re-verification
python -m proof_frog prove --skip-lemmas examples/Proofs/PRG/CounterPRGSecure.proof
```

### Common Errors

**Step N invalid** — The two game expressions at hop N do not reduce to the same canonical form. Run with `-v` to see the canonical forms of both sides and identify the discrepancy.

**First/last game must be the security property** — The proof's opening or closing game does not match the security definition required by the proof statement. Verify that the first and last games in the proof file reference the correct security game.

**Assumption not in assume block** — A game hop cites an assumption (e.g., a hardness assumption) that is not listed in the proof's `assume` block. Add the missing assumption to the block or correct the citation.

---

## describe

### Synopsis

```
python -m proof_frog describe [OPTIONS] FILE
```

### Behavior

Prints a concise, human-readable summary of any FrogLang file's interface — the type parameters, oracles, and their signatures — without showing the full implementation. This is useful for confirming that you have understood a scheme's interface before writing a proof, and for quickly reviewing what a primitive exposes without reading the full source file.

### Options

| Flag | Description |
|------|-------------|
| `-j`, `--json` | Output JSON instead of the default text representation. |

### Examples

```bash
# Describe a primitive
python -m proof_frog describe examples/Primitives/PRG.primitive

# Describe a scheme
python -m proof_frog describe examples/joy/Schemes/SymEnc/OTP.scheme

# Describe with JSON output (useful for tooling)
python -m proof_frog describe --json examples/Primitives/SymEnc.primitive
```

---

## web

### Synopsis

```
python -m proof_frog web [OPTIONS] [DIRECTORY]
```

### Behavior

Starts the ProofFrog browser-based editor, which provides an in-browser environment for editing and running proofs. The optional `DIRECTORY` argument sets the working directory that the editor will use as its file root; it defaults to the current working directory if omitted. The server starts on port 5173 if it is free, otherwise it scans upward for the next available port; the actual URL is printed to the terminal at startup. ProofFrog also opens that URL in your default browser automatically.

{: .note }
The web interface provides the same verification engine as the CLI. It is particularly useful for exploring examples and for interactive proof development where you want to see game hops rendered graphically.

### Examples

```bash
# Start the editor using the current directory as the file root
python -m proof_frog web

# Start the editor rooted at the bundled examples directory
python -m proof_frog web examples/

# Start the editor rooted at a specific project directory
python -m proof_frog web /path/to/my/proofs
```

---

## Advanced Commands

ProofFrog also includes several engine-introspection commands (`step-detail`, `inlined-game`, `canonicalization-trace`, `step-after-transform`, `lsp`, `mcp`) that expose internal engine state and protocol servers. These are intended for researchers and tool authors who need low-level access to the proof engine. They are documented separately in the researcher-facing [Engine Internals]({% link researchers/engine-internals.md %}) page.
