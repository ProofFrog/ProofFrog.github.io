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

```bash
proof_frog web [directory]
```

The command starts a local Flask server and automatically opens the editor in your default browser. The optional `[directory]` argument sets the working directory that the editor treats as its file root: every file read, written, or checked through the editor is resolved relative to that path. If you omit `[directory]`, the editor uses the current working directory.

The server starts on port **5173** by default. If that port is already in use, ProofFrog increments the port number until it finds a free one (up to port 5272). The URL is printed to the terminal; if the browser does not open automatically, copy that URL and paste it into your browser.

To open the editor on the bundled examples:

```bash
proof_frog web examples/
```

To open the editor on a specific project directory:

```bash
proof_frog web /path/to/my/proofs
```

Press **Ctrl-C** in the terminal to stop the server.

<!-- TODO screenshot: web editor on launch -->

---

## Layout

The editor is divided into four regions.

<!-- TODO screenshot: annotated layout -->

**Toolbar (top).** Contains buttons for file actions (New File, Save, Save All), the Insert wizard dropdown, validation buttons (Parse, Type Check, Run Proof), and inspection buttons (Describe, Inlined Game). The current working directory is shown at the right end of the toolbar. A light/dark mode toggle is available at the far right.

**File tree (left sidebar).** Shows the directory tree rooted at the working directory you passed to `proof_frog web`. Click a file to open it in the editor. The sidebar also has a collapsible **Game Hops** panel below the file tree: when a `.proof` file is active, each game in the `games:` list is displayed as a clickable entry so you can jump to any hop quickly.

**Editor pane (center).** A multi-tab code editor powered by CodeMirror. Each open file gets its own tab. The editor provides FrogLang syntax highlighting for all four file types (`.primitive`, `.scheme`, `.game`, `.proof`). Unsaved changes are indicated on the tab. Use **Cmd-S** (macOS) or **Ctrl-S** (Windows/Linux) to save the active file.

**Output pane (bottom).** Displays results from Parse, Type Check, Run Proof, Describe, and Inlined Game operations. The pane can be closed with the X button in its header and reopens automatically when a new operation runs.

---

## Editing

### Syntax highlighting

The editor applies FrogLang syntax highlighting to any file with a `.primitive`, `.scheme`, `.game`, or `.proof` extension. Keywords, types, literals, comments, and string literals (import paths) are coloured distinctly. Both light and dark themes are available; the theme toggle in the toolbar applies to the editor as well.

### Insert wizards

The **Insert** dropdown in the toolbar lists wizards that are applicable to the active file's type. Choosing a wizard opens a modal form; filling in the form and clicking Create inserts a correctly-structured code fragment into the editor at the appropriate location. The available wizards are:

**Creation wizards (empty-file only):**
- Create new primitive
- Create new scheme
- Create new game
- Create new proof

**Always-available wizards:**
- Add import
- Add primitive method
- Add scheme method
- Add game oracle method
- Insert reduction hop
- New reduction stub
- New intermediate game stub
- Add assumption
- Add lemma

The creation wizards are shown only when the active file is empty. All other wizards are shown whenever a file of the matching type is active. Wizard items not applicable to the current file type are hidden automatically.

### File actions

The toolbar's **New File** button opens a dialog where you choose a folder, a base name, and a file extension. The editor then creates an empty file on disk and opens it for editing.

The **Save** button (or Cmd/Ctrl-S) writes the active tab's content to disk. **Save All** writes all modified tabs. Files are written through the server's `/api/file` endpoint and are subject to the same path-safety check that prevents writing outside the working directory.

---

## Validation buttons

Three toolbar buttons run the same verification steps available through the CLI.

### Parse

Calls `/api/parse` on the active file. The output pane shows the AST if parsing succeeded, or the error position if it did not.

CLI equivalent: [`proof_frog parse`]({% link manual/cli-reference.md %}#parse)

### Type Check

Calls `/api/check` on the active file. The output pane reports `<file> is well-formed.` on success, or a type-error message on failure.

CLI equivalent: [`proof_frog check`]({% link manual/cli-reference.md %}#check)

### Run Proof

Available only when a `.proof` file is active. Calls `/api/prove` on the file. The **verbosity selector** next to the button controls the level of detail in the output: Quiet, Verbose, or Very Verbose, corresponding to the CLI's no-flag, `-v`, and `-vv` modes respectively.

CLI equivalent: [`proof_frog prove`]({% link manual/cli-reference.md %}#prove)

---

## Inspecting hops

### Describe

The **Describe** button calls `/api/describe` on the active file and shows a concise, human-readable summary of its interface (type parameters, oracle names, and their signatures). This is useful for confirming what a primitive or game exposes before writing a proof.

CLI equivalent: [`proof_frog describe`]({% link manual/cli-reference.md %}#describe)

### Inlined Game

The **Inlined Game** button opens a dialog where you type a game-step expression (such as `Security.Left compose Reduction(params) against Adversary`). The editor evaluates it against the current proof's `let:` and `assume:` context by calling `/api/inlined-game`, then displays the inlined and canonicalized form of the resulting game in a split-pane view with a diff against the adjacent step.

This is the primary tool for understanding why a proof hop is or is not valid: you can experiment with step expressions and immediately see the canonical form without modifying the proof file. See the Transformations page for a conceptual explanation of inlining and canonicalization.

---

## Limitations of the web editor

The web editor covers the common proof-writing workflow but does not expose every feature available on the CLI.

**Engine-introspection commands are CLI-only.** The following commands are available from the terminal but have no equivalent button in the web editor:

- `step-detail` --- returns the canonical form of a specific numbered step in an existing proof, by step index.
- `inlined-game` (CLI variant) --- evaluates an arbitrary game expression from the command line, outside the modal dialog flow.
- `canonicalization-trace` --- shows the sequence of transformation passes that were applied during canonicalization, which is essential for diagnosing why the engine fails to simplify a particular expression.
- `step-after-transform` --- applies a single named transform pass to a game expression and shows the result, enabling step-by-step debugging of the canonicalization pipeline.

These commands are intended for researchers and tool authors who need low-level access to proof engine internals. They are covered in full on the engine internals page. If you encounter a proof step that the engine cannot verify and need to diagnose the canonicalization pipeline, switch to the CLI for these commands.

**File operations are constrained to the working directory.** The server enforces a path-safety check on all file reads and writes. Files and directories whose names begin with a dot (for example `.git`) are not accessible through the editor. You cannot open files outside the directory you passed to `proof_frog web`.

**Single working directory per session.** The `proof_frog web` command takes a single working directory at startup. To switch to a different directory you must stop the server and restart it with the new path.
