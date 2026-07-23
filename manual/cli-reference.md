---
title: Command-Line Interface
layout: default
parent: Manual
nav_order: 60
---

# CLI Reference

The ProofFrog command-line interface (`proof_frog`) lets you parse, type-check, and verify cryptographic game-hopping proofs entirely from the terminal. Eight public commands cover the full workflow from inspecting files to running complete proof verification. If you prefer a graphical environment, a browser-based editor is also available via the `web` command described below.

> **Activate your Python virtual environment first.** All of the commands below assume that the virtual environment in which ProofFrog was installed is activated in the current terminal session. If you opened a new terminal, re-activate it before running any `proof_frog` (or `python -m proof_frog`) command: 
>
> - `source .venv/bin/activate` on macOS/Linux (bash/zsh)
> - `source .venv/bin/activate.fish` on fish
> - `.venv\Scripts\Activate.ps1` on Windows PowerShell
>
> See [Installation]({% link manual/installation.md %}) for details. A `command not found: proof_frog` error almost always means the virtual environment is not active.
{: .important }

## Command Summary

| Command | Description |
|---------|-------------|
| [`version`](#version) | Print the ProofFrog version. |
| [`parse`](#parse) | Parse a FrogLang file and pretty-print it. |
| [`check`](#check) | Type-check and semantically analyze a FrogLang file. |
| [`prove`](#prove) | Run proof verification on a `.proof` file. |
| [`describe`](#describe) | Print a concise interface description of a FrogLang file. |
| [`export-latex`](#export-latex) | Render a FrogLang file as typeset LaTeX pseudocode. |
| [`download-examples`](#download-examples) | Download the examples repository. |
| [`web`](#web) | Start the ProofFrog web interface. |

---

## version

### Synopsis

```
proof_frog version [OPTIONS]
```

### Behavior

Prints the installed ProofFrog version string to standard output and exits. The output format is `ProofFrog <version>`, for example `ProofFrog 0.6.1.dev0` on development builds. Use this to confirm which release is active in your environment or to include version information in bug reports.

### Examples

```bash
# Print the installed version
proof_frog version
```

Expected output (version may differ):

```
ProofFrog 0.6.0
```

---

## parse

### Synopsis

```
proof_frog parse [OPTIONS] FILE
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
proof_frog parse examples/Primitives/PRG.primitive

# Parse a scheme and get JSON output
proof_frog parse --json examples/joy/Schemes/SymEnc/OTP.scheme

# Parse a proof file
proof_frog parse examples/joy/Proofs/Ch2/OTPSecure.proof
```

### Common Errors

**Parse error at line N, column M** — The file contains a syntax error. The message indicates the exact position; check for missing semicolons, unbalanced braces, or unknown keywords near that location.

---

## check

### Synopsis

```
proof_frog check [OPTIONS] FILE
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
proof_frog check examples/joy/Schemes/SymEnc/OTP.scheme

# Type-check a primitive definition
proof_frog check examples/Primitives/SymEnc.primitive

# Check a proof file and emit JSON diagnostics
proof_frog check --json examples/joy/Proofs/Ch2/OTPSecure.proof
```

### Common Errors

**Type error** — An expression or assignment involves incompatible types. The error message names the conflicting types and the relevant line.

**Modifier mismatch** — A scheme method declares a `deterministic`/`injective` modifier that differs from what the primitive's signature requires. Align the modifiers between the scheme and the primitive it extends.

---

## prove

### Synopsis

```
proof_frog prove [OPTIONS] FILE
```

### Behavior

Verifies a game-hopping proof written in a `.proof` file. ProofFrog works through each game-hop step, reduces both sides to canonical form, and checks equivalence. If every step is valid and the proof begins and ends at the required security games, the proof is accepted.

By default ProofFrog runs equivalence checks in parallel. Pass `--sequential` (or set the environment variable `PROOFFROG_SEQUENTIAL=1`) to force single-process execution, which is useful for reproducible output in CI environments.

Pass `-v` once to print the canonical game form after each hop, which is invaluable for diagnosing why a step fails. Pass `-vv` to additionally show which transformation rules fire during canonicalization.

After the hop summary table, a successful run prints the [advantage bound]({% link manual/advantage-bounds.md %}) the proof establishes:

```
Advantage bound: Adv^PRGSecurity(T)(A) <= Adv^PRGSecurity(G)(B1) + Adv^PRGSecurity(G)(B2)
```

If the proof file declares a `bound:` clause, a verdict line follows saying whether the claimed bound was verified against the synthesized one.

### Options

| Flag | Description |
|------|-------------|
| `-v`, `--verbose` | Increase verbosity. Use `-v` to print each game's canonical form; use `-vv` to also show transformation activity. |
| `-j`, `--json` | Output JSON instead of the default text representation. |
| `--no-diagnose` | Suppress diagnostic analysis on failure (print summary only). |
| `--skip-lemmas` | Skip lemma proof verification (trust lemmas without re-checking). |
| `--skip-bound` | Do not fail the proof when a claimed `bound:` cannot be verified. |
| `--sequential` | Disable parallel equivalence checking (use a single process). Can also be forced via the `PROOFFROG_SEQUENTIAL` environment variable. |

{: .important }
`--skip-lemmas` bypasses verification of any lemmas referenced by the proof and trusts them unconditionally. Use this only during iterative development when you have already confirmed that the lemmas are correct and want faster turnaround on the main proof steps. Never use it as a substitute for verifying a complete proof.

{: .important }
`--skip-bound` downgrades a refuted `bound:` claim from an error to a warning. A refuted claim means the proof asserts *more* security than its hop sequence actually establishes, so this flag is for iterative development — while you work out which term the claim is missing — and not for a proof you intend to publish. It does not affect the synthesized bound, which is printed either way.

### Examples

```bash
# Verify the OTP security proof from Joy of Cryptography examples
proof_frog prove examples/joy/Proofs/Ch2/OTPSecure.proof

# Verbose: print canonical game forms at each hop
proof_frog prove -v examples/joy/Proofs/Ch2/OTPSecure.proof

# Very verbose: also show transformation rule firings
proof_frog prove -vv examples/joy/Proofs/Ch2/OTPSecure.proof

# Verify a PRG security proof, skipping lemma re-verification
proof_frog prove --skip-lemmas examples/Proofs/PRG/CounterPRG_PRGSecurity.proof
```

### Common Errors

**Step N invalid** — The two game expressions at hop N do not reduce to the same canonical form. Run with `-v` to see the canonical forms of both sides and identify the discrepancy.

**First/last game must be the security property** — The proof's opening or closing game does not match the security definition required by the proof statement. Verify that the first and last games in the proof file reference the correct security game.

**Assumption not in assume block** — A game hop cites an assumption (e.g., a hardness assumption) that is not listed in the proof's `assume` block. Add the missing assumption to the block or correct the citation.

---

## describe

### Synopsis

```
proof_frog describe [OPTIONS] FILE
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
proof_frog describe examples/Primitives/PRG.primitive

# Describe a scheme
proof_frog describe examples/joy/Schemes/SymEnc/OTP.scheme

# Describe with JSON output (useful for tooling)
proof_frog describe --json examples/Primitives/SymEnc.primitive
```

---

## export-latex

### Synopsis

```
proof_frog export-latex [OPTIONS] FILE
```

### Behavior

Renders any FrogLang file (`.primitive`, `.scheme`, `.game`, or `.proof`) as typeset pseudocode, using the [`cryptocode`](https://www.ctan.org/pkg/cryptocode) LaTeX package. The command writes the result to a file and prints `Wrote <path>`; the default output path is the input path with its extension changed to `.tex`.

By default the output is a complete, compilable `\documentclass{article}` document. Pass `--no-standalone` to get a fragment suitable for `\input`-ing into a larger paper instead.

For the details of what the exporter produces — the macro preamble and how to override it, how a proof document is laid out, and the known gaps in this first version — see [LaTeX Export]({% link manual/latex-export.md %}).

{: .warning }
LaTeX export is preliminary. Expect to hand-adjust the output, and expect the output style to change in future versions.

### Options

| Flag | Description |
|------|-------------|
| `-o`, `--output PATH` | Output path for the `.tex` file. Defaults to the input path with a `.tex` extension. |
| `--backend NAME` | Pseudocode package backend. Only `cryptocode` is available in this version. |
| <code>--composition [symbolic&#124;inlined]</code> | How reduction-based steps render (default: `symbolic`). |
| `--standalone` / `--no-standalone` | Emit a complete document (default) or an `\input`-able fragment. |
| `--diff` / `--no-diff` | In a proof, highlight the lines of each game that changed relative to the previous game (default: on; proof files only). |
| <code>--diff-style [box&#124;color]</code> | How a changed line renders: gray box (default) or colored text. |

### Examples

```bash
# Export a proof; writes examples/Proofs/PRG/TriplingPRG_PRGSecurity.tex
proof_frog export-latex examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof

# Export a game to a chosen path
proof_frog export-latex -o figures/indcpa.tex examples/Games/SymEnc/INDCPA_MultiChal.game

# Produce a fragment to \input into a paper, with no change highlighting
proof_frog export-latex --no-standalone --no-diff examples/Schemes/SymEnc/OTP.scheme

# Highlight changed lines in color rather than with a gray box
proof_frog export-latex --diff-style color examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof
```

---

## download-examples

### Synopsis

```
proof_frog download-examples [OPTIONS] [DIRECTORY]
```

### Behavior

Downloads the [ProofFrog examples repository](https://github.com/ProofFrog/examples) into the specified directory (default: `examples`). By default the command downloads the version of the examples that was pinned when your copy of ProofFrog was built, ensuring the examples are compatible with your installed version. Use `--ref` to override this and download a specific commit, tag, or branch instead. If the target directory already exists, the command exits with an error unless `--force` is passed.

### Options

| Flag | Description |
|------|-------------|
| `--force` | Overwrite the target directory if it already exists. |
| `--ref REF` | Git ref (commit SHA, tag, or branch) to download. Defaults to the version pinned at build time. |

### Examples

```bash
# Download the examples matching your version of ProofFrog into an "examples" directory
proof_frog download-examples

# Download into a custom directory
proof_frog download-examples my-examples

# Download the latest main branch instead of the pinned version
proof_frog download-examples --ref main

# Overwrite an existing examples directory
proof_frog download-examples --force
```

---

## web

### Synopsis

```
proof_frog web [OPTIONS] [DIRECTORY]
```

### Behavior

Starts the ProofFrog browser-based editor, which provides an in-browser environment for editing and running proofs. The optional `DIRECTORY` argument sets the working directory that the editor will use as its file root; it defaults to the current working directory if omitted. The server starts on port 5173 if it is free, otherwise it scans upward for the next available port; the actual URL is printed to the terminal at startup. ProofFrog also opens that URL in your default browser automatically.

{: .note }
The web interface provides the same verification engine as the CLI. It is particularly useful for exploring examples and for interactive proof development where you want to see game hops rendered graphically.

### Examples

```bash
# Start the editor using the current directory as the file root
proof_frog web

# Start the editor rooted at the bundled examples directory
proof_frog web examples/

# Start the editor rooted at a specific project directory
proof_frog web /path/to/my/proofs
```

---

## Advanced Commands

ProofFrog also includes several engine-introspection commands (`step-detail`, `inlined-game`, `canonicalization-trace`, `step-after-transform`, `lsp`, `mcp`) that expose internal engine state and protocol servers. These are intended for researchers and tool authors who need low-level access to the proof engine. They are documented separately in the researcher-facing [Engine Internals]({% link researchers/engine-internals.md %}) page.
