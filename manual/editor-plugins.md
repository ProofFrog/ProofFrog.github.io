---
title: Editor Plugins
layout: default
parent: Manual
nav_order: 80
---

# Editor Plugins

ProofFrog ships a plugin for Visual Studio Code that provides rich editing support for FrogLang files. The plugin connects to an LSP server bundled with ProofFrog (`proof_frog lsp`); any other editor that supports the Language Server Protocol can be wired up to the same server without a dedicated plugin. Additional first-party plugins may be added in the future. See the [Engine Internals]({% link researchers/engine-internals.md %}) page for details on the LSP protocol, the language IDs, and the workspace configuration the server expects.

---

## VSCode

### Installation

The extension is not currently published on the VSCode Marketplace. It ships as a `.vsix` package that you install manually.

**From a pre-built package.** If you have a `.vsix` file (distributed separately or built by a colleague), install it from within VSCode: open the Extensions view, click the `...` menu in its header, and choose "Install from VSIX...". Select the `.vsix` file and reload the window when prompted.

**Building from source.** From the repository root, run:

```bash
# Compile the extension
make vscode-extension

# Package as .vsix
make vscode-vsix
```

Then install the resulting `.vsix` via the Extensions view as described above.

**Requirements.** The extension requires VSCode 1.85 or later and Python 3.11 or later with ProofFrog installed in the Python environment it uses. By default the extension looks for `python3` on your PATH. If you use a virtual environment, set the `prooffrog.pythonPath` setting to the full path of that environment's interpreter:

```json
{
  "prooffrog.pythonPath": "/path/to/ProofFrog/.venv/bin/python"
}
```

See [Installation]({% link manual/installation.md %}) for instructions on setting up ProofFrog itself.

---

### Features

The features described below are implemented in the LSP server (`proof_frog/lsp/`) and surfaced through the VSCode extension client.

**Syntax highlighting.** The extension registers a single language ID (`prooffrog`, also aliased as `ProofFrog` and `FrogLang`) for all four FrogLang file extensions: `.primitive`, `.scheme`, `.game`, and `.proof`. A TextMate grammar provides token-based highlighting for keywords, types, literals, comments, and import paths.

**Diagnostics.** Parse errors are reported as squiggle underlines on every keystroke, without waiting for a save. On save, the server runs semantic analysis (type checking) and reports any type errors inline. For `.proof` files, saving also triggers full proof verification: each game hop is checked, and failed hops appear as error diagnostics on the relevant line in the `games:` list. All diagnostics come from `proof_frog/lsp/diagnostics.py` and `proof_frog/lsp/proof_features.py`.

**Go-to-definition.** Pressing F12 (or Cmd/Ctrl+click) on an import path navigates to the imported file. On a dotted name such as `E.KeyGen`, the extension jumps to the declaration of that field or method within the imported file. Implemented in `proof_frog/lsp/navigation.py`.

**Hover information.** Hovering over an import name or a dotted member reference shows a Markdown popup with the interface description for that primitive, scheme, or game, or the signature of the specific method. Implemented in `proof_frog/lsp/navigation.py`.

**Outline panel and document symbols.** The Explorer Outline panel is populated with the structural elements of the active file: the primitive or scheme name with its fields and methods, game or reduction definitions with their oracle methods, the `theorem:` declaration in a proof file, and the `games:` list with each step as a child entry. This uses `proof_frog/lsp/symbols.py`.

**Code folding.** Method bodies, game and reduction bodies, and the `games:` list in a proof file can be collapsed with the standard fold controls. Blocks of three or more consecutive comment lines are also foldable as a comment region. Implemented in `proof_frog/lsp/folding.py`.

**Rename (F2).** Pressing F2 on an identifier renames all whole-word occurrences of that identifier throughout the current file, skipping occurrences inside comments and string literals. Language keywords and built-in type names (`Initialize`, `Finalize`, `BitString`, etc.) cannot be renamed. Implemented in `proof_frog/lsp/rename.py`.

**Completion and signature help.** The extension provides two forms of IntelliSense. Keyword completion offers context-sensitive keywords for each file type (different sets for `.primitive`, `.scheme`, `.game`, and `.proof` files). Member completion triggers after a dot (`.`) and lists the fields and methods of the named import or `let:` binding. Signature help appears when you open a parenthesis on a method call and highlights the active parameter as you type commas. Completion also resolves `let:` bindings in proof files so that aliases like `E2.KeyGen` are completed correctly. Implemented in `proof_frog/lsp/completion.py`.

**Code lens for proof hops.** In `.proof` files, after a save triggers proof verification, each line in the `games:` list receives an inline annotation showing whether that hop passed (`interchangeability`), failed (`interchangeability -- FAILED`), or was an assumption hop (`assumption`). Failed hops are also reported as error diagnostics. Implemented in `proof_frog/lsp/proof_features.py`.

**Proof hops tree view.** When a `.proof` file is active, a "ProofFrog: Proof Hops" panel appears in the Explorer sidebar. It lists every game hop with its pass/fail status and the descriptions of the two games being compared. Clicking an entry navigates to the corresponding line in the proof file. This view is updated automatically each time proof verification completes. Implemented in `proof_frog/lsp/proof_features.py` (server side) and `vscode-extension/src/proof_tree.ts` (client side).

<!-- TODO screenshot: VSCode showing a proof file with hop status code lens -->

---

## (Future) Emacs

ProofFrog does not yet ship a dedicated Emacs plugin. The LSP server (`proof_frog lsp`) can be used directly with `eglot` or `lsp-mode` for syntax highlighting, diagnostics, and the basic LSP feature set. You would configure the server command as `python3 -m proof_frog lsp` (or the equivalent path for your environment) and associate it with the `.primitive`, `.scheme`, `.game`, and `.proof` extensions. See the [Engine Internals]({% link researchers/engine-internals.md %}) page for LSP protocol details.

---

## (Future) JetBrains

ProofFrog does not yet ship a dedicated JetBrains plugin. JetBrains IDEs support generic LSP integration via the LSP4IJ plugin (for IDEs running on the 2023.2 platform or later). You can configure it to launch `python3 -m proof_frog lsp` as the server process for the four FrogLang file extensions. Feature availability will vary depending on the IDE and plugin version. See the [Engine Internals]({% link researchers/engine-internals.md %}) page for LSP protocol details.

---

## Adding a new editor

Any editor that supports the Language Server Protocol can be connected to ProofFrog's LSP server. The server is started with `proof_frog lsp` (or `python3 -m proof_frog lsp`) and communicates over stdio using the standard JSON-RPC wire protocol. It uses full document synchronisation (`TextDocumentSyncKind.Full`). The language ID for all four file types is `prooffrog`. The server expects the working directory to match the directory from which the proof files are being edited, so that import paths resolve correctly. See the [Engine Internals]({% link researchers/engine-internals.md %}) page for a full description of the protocol surface, the supported LSP methods, and the custom notifications (`prooffrog/verificationDone`, `prooffrog/proofSteps`) used by the proof hops tree view.
