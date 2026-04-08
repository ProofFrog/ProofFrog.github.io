---
title: Web Editor
layout: default
parent: Manual
nav_order: 70
---

# Web Editor

ProofFrog includes a browser-based editor that gives you a graphical environment for writing and verifying FrogLang files. It runs entirely on your local machine; nothing leaves your computer. The web editor is well-suited to interactive proof development and to exploring the bundled examples, because it keeps the file tree, source code, and proof output in a single window.

---

## Launching

{: .important }
**Activate your Python virtual environment first.** In every new terminal, run `source .venv/bin/activate` (macOS/Linux bash/zsh), `source .venv/bin/activate.fish` (fish), or `.venv\Scripts\Activate.ps1` (Windows PowerShell) before invoking `proof_frog`. See [Installation]({% link manual/installation.md %}).

```bash
proof_frog web [directory]
```

The command starts a local Flask server and opens the editor in your default browser. The optional `[directory]` argument sets the working directory the editor treats as its file root; everything you read, write, or check is resolved relative to that path. Without an argument, the current working directory is used.

The server listens on port **5173** if free, otherwise scans upward for the next available port; the actual URL is printed to the terminal. If the browser does not open automatically, copy that URL by hand. Press **Ctrl-C** in the terminal to stop the server.

<!-- TODO screenshot: web editor on launch -->

---

## Layout

The editor has four regions.

<!-- TODO screenshot: annotated layout -->

**Toolbar (top).** File actions (New File, Save, Save All), the Insert wizard dropdown, validation buttons (Parse, Type Check, Run Proof), inspection buttons (Describe, Inlined Game), the current working directory, and a light/dark theme toggle.

**File tree (left sidebar).** The directory tree rooted at the working directory; click a file to open it. Below the tree, a collapsible **Game Hops** panel lists the entries of the active `.proof` file's `games:` block as clickable jump targets.

**Editor pane (center).** A multi-tab CodeMirror editor with FrogLang syntax highlighting for `.primitive`, `.scheme`, `.game`, and `.proof` files. Unsaved changes are flagged on the tab. **Cmd-S** / **Ctrl-S** saves the active file.

**Output pane (bottom).** Results from Parse, Type Check, Run Proof, Describe, and Inlined Game operations. Closes with the X button and reopens automatically on the next operation.

---

## Editing

The **Insert** dropdown lists wizards applicable to the active file's type; choosing one opens a modal that inserts a correctly-structured fragment at the right location. Four creation wizards (Create new primitive / scheme / game / proof) appear only on an empty file. The remaining wizards are file-type-filtered and shown when a matching file is open: Add import, Add primitive method, Add scheme method, Add game oracle method, Insert reduction hop, New reduction stub, New intermediate game stub, Add assumption, Add lemma.

The **New File** button takes a folder, base name, and extension and creates an empty file. **Save** writes the active tab; **Save All** writes every modified tab. All file operations are constrained to the working directory by a server-side path-safety check.

---

## Validation buttons

Each toolbar validation button has a CLI equivalent:

- **Parse** ([`proof_frog parse`]({% link manual/cli-reference.md %}#parse)) — calls `/api/parse` and shows the parsed source or the parse-error position.
- **Type Check** ([`proof_frog check`]({% link manual/cli-reference.md %}#check)) — calls `/api/check` and reports `<file> is well-formed.` or a type error.
- **Run Proof** ([`proof_frog prove`]({% link manual/cli-reference.md %}#prove)) — only for `.proof` files. Calls `/api/prove`. The verbosity selector next to the button picks Quiet, Verbose, or Very Verbose, corresponding to the CLI's no-flag, `-v`, and `-vv` modes.

---

## Inspecting hops

**Describe** ([`proof_frog describe`]({% link manual/cli-reference.md %}#describe)) calls `/api/describe` on the active file and shows a concise interface summary (type parameters, oracle names and signatures). Useful for confirming what a primitive or game exposes before writing a proof.

**Inlined Game** opens a dialog where you type a game-step expression (such as `Security.Left compose Reduction(params) against Adversary`). The editor evaluates it against the current proof's `let:` and `assume:` context by calling `/api/inlined-game` and displays the resulting inlined-and-canonicalized game. This is the primary tool for understanding why a proof hop is or is not valid: you can experiment with step expressions and immediately see the canonical form without modifying the proof file. See the [Canonicalization]({% link manual/canonicalization.md %}) page for a conceptual explanation of inlining and canonicalization.

---

## Limitations of the web editor

The CLI exposes four engine-introspection commands that have no web-editor equivalent: `step-detail`, `inlined-game` (the CLI variant, with no modal-dialog dependency), `canonicalization-trace`, and `step-after-transform`. These are diagnostic tools for tool authors and are covered on the [Engine Internals]({% link researchers/engine-internals.md %}) page. The web editor is also constrained to a single working directory chosen at startup, with file access denied outside it and to dot-files.
