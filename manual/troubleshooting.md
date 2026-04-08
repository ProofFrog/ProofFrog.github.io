---
title: Troubleshooting
layout: default
parent: Manual
nav_order: 90
---

# Troubleshooting

This page is keyed by symptom. Find the error message or behavior you are
seeing, then follow the **Fix** to resolve it. Where a more detailed
explanation exists elsewhere in the manual, a **See also** link is provided.

---

## Install problems

**Symptom:** `proof_frog: command not found`

**Likely cause:** The virtual environment where ProofFrog was installed is not
activated in the current shell session, or you installed ProofFrog into a
different Python installation than the one your shell resolves.

**Fix:** Activate the virtual environment (`source .venv/bin/activate` on
macOS/Linux, `.venv\Scripts\Activate.ps1` on Windows PowerShell) before
running `proof_frog`. If you are not using a virtual environment, verify with
`which proof_frog` (macOS/Linux) or `where proof_frog` (Windows) that the
command is on your `PATH`.

**See also:** [Installation]({% link manual/installation.md %})

---

**Symptom:** `python3: command not found`

**Likely cause:** Python is not installed, or the installer did not add it to
the system `PATH`.

**Fix:** Install Python 3.11 or newer from python.org or your operating
system's package manager, then open a new terminal. On macOS, `brew install
python@3.11` is the recommended path; on Windows, the installer checkbox
"Add Python to PATH" must be checked.

**See also:** [Installation]({% link manual/installation.md %})

---

**Symptom:** `pip install proof_frog` completes but then says "no matching
distribution found" or installs a very old version unexpectedly.

**Likely cause:** The active `pip` belongs to a Python version older than
3.11. ProofFrog requires Python 3.11 or newer; packages published for older
Python versions are not compatible.

**Fix:** Run `python3 --version` to confirm which interpreter is active. If
the version is below 3.11, create your virtual environment with an explicit
path, for example `python3.11 -m venv .venv`, then activate and install again.

**See also:** [Installation]({% link manual/installation.md %})

---

**Symptom:** On Windows PowerShell, running `.venv\Scripts\Activate.ps1`
prints `cannot be loaded because running scripts is disabled on this system`.

**Likely cause:** PowerShell's default execution policy on a fresh Windows
install blocks running `.ps1` scripts.

**Fix:** Run the following command once per user account (no administrator
privileges required), then try activating again:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**See also:** The execution-policy warning in [Installation]({% link manual/installation.md %})

---

## Parse errors

Parse errors use the format `<file>:<line>:<col>: parse error: <message>`,
followed by the offending source line and a caret pointing to the problem
character.

**Symptom:** `<file>:<line>:<col>: parse error: missing ';' before '}'`
(or `missing ';' (found '<token>' on next line)`)

**Likely cause:** A statement in a method body is missing its terminating
semicolon.

**Fix:** Add `;` at the end of the statement on the indicated line.

---

**Symptom:** `<file>:<line>:<col>: parse error: unexpected 'export'; a closing
'}' is missing for a Game or method definition above`

**Likely cause:** A `Game` block or method body is missing its closing brace.
The parser does not detect the problem until it reaches the next top-level
`export` keyword.

**Fix:** Check the Game or method that ends just before line `<line>` for a
missing `}`.

---

**Symptom:** `<file>:<line>:<col>: parse error: a .game security property
file must contain exactly two Game definitions (e.g. Left and Right), but only
one was found`

**Likely cause:** A `.game` file contains only one `Game` block instead of
the required pair (such as `Real` and `Ideal`, or `Left` and `Right`).

**Fix:** Add the second `Game` definition to the file.

**See also:** [Games]({% link manual/language-reference/games.md %})

---

**Symptom:** `<file>:<line>:<col>: parse error: import paths must use single
quotes, not double quotes (e.g. import '../path/to/file';)`

**Likely cause:** An `import` statement used double-quoted path strings, which
FrogLang does not allow.

**Fix:** Replace `"..."` with `'...'` in all `import` statements.

---

**Symptom:** `<file>:<line>: imported file not found: '<path>'`

**Likely cause:** The path in an `import` statement does not resolve to an
existing file relative to the directory where the CLI was invoked.

**Fix:** Confirm the file exists at the given path and that the import is
relative to the directory from which you are running `proof_frog`, not
relative to the source file. Import paths in FrogLang are resolved from the
working directory of the CLI invocation.

**See also:** [Language Reference: Basics]({% link manual/language-reference/basics.md %})

---

## Type errors

Type errors use the format `<file>:<line>:<col>: error: <message>`, with the
offending source line and a caret on the next two lines.

**Symptom:**
`<file>:<line>:<col>: error: Method '<name>' has different signatures in <Game1> and <Game2>: <sig1> vs <sig2>`

**Likely cause:** The two games in a `.game` security-property file declare
the same method name but with different parameter types or return types. The
two games must have exactly matching method signatures.

**Fix:** Align the method signatures in both games so they agree on parameter
types, return type, and order.

**See also:** [Games]({% link manual/language-reference/games.md %})

---

**Symptom:**
`<file>:<line>:<col>: error: Scheme <S> does not correctly implement primitive <P>: method '<m>' is missing the 'deterministic' modifier required by primitive <P>`

(Variants exist for `'deterministic' modifier not declared by primitive`,
`'injective' modifier required`, and `'injective' modifier not declared`.)

**Likely cause:** The primitive declares a method with a `deterministic` or
`injective` annotation, but the scheme's implementation of that method omits
(or adds) the annotation, or vice versa. The typechecker requires the
annotation set to match exactly.

**Fix:** Add or remove the `deterministic` / `injective` modifier on the
scheme method so it matches the corresponding primitive method declaration.

**See also:** [Schemes]({% link manual/language-reference/schemes.md %})

---

**Symptom:**
`<file>:<line>:<col>: error: Scheme <S> does not correctly implement primitive <P>: method '<m>' return type <T1> does not match primitive <P> return type <T2>`

**Likely cause:** The scheme's method return type is `T?` (optional) where
the primitive declares `T` (non-optional), or the concrete type does not match
what the primitive specifies. The typechecker applies strict optional checking
for scheme-vs-primitive conformance.

**Fix:** Make the scheme method's return type agree exactly with the primitive,
including the presence or absence of `?`. If the method legitimately returns
`None` in some cases, the primitive itself must declare the optional type.

**See also:** [Language Reference: Basics]({% link manual/language-reference/basics.md %})

---

**Symptom:**
`<file>:<line>:<col>: error: Could not determine type of <expr>`

**Likely cause:** An identifier is used before it is declared, or a name that
should refer to an imported primitive, scheme, or game is not visible in the
current scope. This can also occur if a `let:` binding in a proof file is
missing.

**Fix:** Check that every name referenced in the expression is declared (in
scope) before its first use and that the containing file imports all necessary
primitives, schemes, and games.

---

**Symptom:**
`<file>:<line>:<col>: error: <name> not found in imports`

**Likely cause:** A reduction, game step, or proof `assume:` block references
a name that does not appear in any `import` statement in the file.

**Fix:** Add an `import` statement for the file that defines the missing name,
and ensure the path is correct relative to the directory where the CLI is
invoked.

---

## Proof errors

Proof errors are printed to standard output (not standard error) and are
prefixed with a colored status line.

**Symptom:**
`Proof Succeeded, but is incomplete: first and last steps use the same side (<side>)`

**Likely cause:** All individual hops verified, but the first and last game
steps both use the same side (e.g., both `Real`) of the security game, so the
chain of games does not connect the two sides of the theorem. A complete proof
must begin on one side and end on the other.

**Fix:** Add the missing intermediate hops so that the game sequence starts on
one side of the security property and ends on the other. Check that the final
game step uses the opposite side from the first step.

---

**Symptom:**
`Proof Failed! (<n> step(s) failed: <step numbers>)`

together with a per-step line like `Step 3/8  <GameA> -> <GameB>  equivalence  FAILED`

**Likely cause:** One or more interchangeability hops could not be verified
because the canonical forms of the two adjacent games differ in a way the
engine cannot reconcile. A diagnostic summary line (indented below the step)
describes the first detected difference.

**Fix:** Run `proof_frog prove -v` to see full canonical-form diagnostics.
If the diagnostic reports a known engine limitation (see the section below),
apply the listed workaround. Otherwise, inspect the canonical forms of the
two games and ensure they are genuinely equivalent under ProofFrog's semantics.

**See also:** [CLI Reference]({% link manual/cli-reference.md %})

---

**Symptom:**
`<file>:<line>:<col>: error: lemma proof file not found: '<path>'`

**Likely cause:** A `lemma:` block in a proof file references a `.proof` path
that does not exist relative to the directory of the proof file.

**Fix:** Correct the path in the `lemma:` entry, or use `--skip-lemmas` on
the CLI to bypass lemma verification temporarily while developing the proof.

**See also:** [CLI Reference]({% link manual/cli-reference.md %})

---

**Symptom:** The engine prints `Proof must start with a game matching the
theorem's security game` followed by lines showing `Theorem expects:` and
`First step uses:`.

**Likely cause:** The first game step in the `games:` list does not match the
security game named in the `theorem:` line.

**Fix:** Change the first step so it uses a side of the game named in
`theorem:`, or correct the `theorem:` declaration to match the game used in
the first step.

---

**Symptom:** An assumption hop is listed in the `games:` sequence but the
engine treats it as an equivalence check (which then fails) rather than
accepting it by assumption.

**Likely cause:** The pair of game steps does not match any entry in the
`assume:` block. The engine recognizes an assumption hop only when the two
adjacent steps compose with the two sides of an assumed security game.

**Fix:** Verify that the game named in `assume:` exactly matches (same name,
same parameters) the game used in the two steps. Any parameter mismatch causes
the engine to fall through to an equivalence check.

**See also:** [Language Reference: Proofs]({% link manual/language-reference/proofs.md %})

---

## Web editor problems

**Symptom:** Running `proof_frog web` prints an address but immediately exits,
or you see a message like `Could not find a free port`.

**Likely cause:** All 100 ports starting from 5173 are already in use, which
is extremely unlikely in practice. The more common scenario is that a previous
`proof_frog web` process is still running in another terminal.

**Fix:** Stop any existing `proof_frog web` process. The server automatically
scans from port 5173 upward for the next free port and prints the actual URL
it bound to; you do not need to free a specific port.

**See also:** [Web Editor]({% link manual/web-editor.md %})

---

**Symptom:** `proof_frog web` starts and prints a URL but no browser window
opens.

**Likely cause:** The `webbrowser.open` call in the server failed silently
because there is no default browser configured in the environment (common in
headless or remote SSH sessions).

**Fix:** Copy the URL printed to the terminal (for example
`http://127.0.0.1:5173`) and open it manually in any browser.

**See also:** [Web Editor]({% link manual/web-editor.md %})

---

**Symptom:** The web editor output panel shows a red "Failed" status but the
body of the output contains the text "Succeeded".

**Likely cause:** This matches the `Proof Succeeded, but is incomplete` case
described in the Proof errors section above. All hops verified individually,
but the game sequence does not span both sides of the theorem.

**Fix:** See the "Proof Succeeded, but is incomplete" entry above under Proof
errors.

---

## "My proof should work but doesn't"

If all of your proof steps look logically correct but one or more
interchangeability hops still fail, the steps below help narrow down the
cause.

**Step 1: run with verbose output.**

```bash
proof_frog prove -v your_proof.proof
```

The `-v` flag enables Level 3 diagnostics: the canonical form of both games
at each failing hop, a near-miss report, and a notice when the failure matches
a known engine limitation.

**See also:** [CLI Reference]({% link manual/cli-reference.md %})

**Step 2: check for known engine limitations.**

The ProofFrog engine currently does not normalize the following patterns when
comparing canonical game forms. If the verbose output shows a diff that matches
one of these descriptions, apply the listed workaround in your intermediate
game or reduction.

1. **Operand order for `||` and `&&` is not normalized.**
   The engine normalizes `+` and `*` via commutative chains but does not
   reorder the operands of `||` (logical OR on `Bool`) or `&&`.
   *Workaround:* Reorder operands manually in your intermediate game to match
   the order used in the adjacent game.

2. **Field (statement) declaration order within a method is not reordered.**
   Two games that are identical except that their field assignments appear in a
   different order will not be recognized as equivalent.
   *Workaround:* Match the statement order from the previous game in your
   intermediate game.

3. **Associativity of `||` and `&&` is not normalized.**
   `(a || b) || c` and `a || (b || c)` are not recognized as equivalent, even
   though they are semantically identical.
   *Workaround:* Reparenthesize the expression in your intermediate game to
   match the parenthesization used in the adjacent game.

4. **Extra temporary variable vs. direct return.**
   If one game writes `Type v = expr; return v;` and the adjacent game writes
   `return expr;` directly, the `SimplifyReturn` transform may fire on one
   but not the other, leaving a residual difference.
   *Workaround:* Either inline the temporary (use `return expr;` directly in
   both games) or add the temporary to both games so they match.

5. **`if`/`else-if` branch order is not normalized.**
   Two games with the same set of conditional branches listed in a different
   order will not be recognized as equivalent.
   *Workaround:* Match the branch order from the previous game in your
   intermediate game.

**Step 3: check for deeper engine issues.**

If none of the limitations above apply and the diff still looks semantically
equivalent, there may be an engine bug or an unimplemented transformation.
The Transformations and Limitations pages (forthcoming in the Researchers
section) will document the full canonicalization pipeline and its current gaps.
In the meantime, consult the ProofFrog issue tracker or contact the
maintainers.
