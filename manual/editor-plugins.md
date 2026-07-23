---
title: Editor Plugins
layout: default
parent: Manual
nav_order: 80
---

# Editor Plugins
{: .no_toc }

ProofFrog ships a plugin for Visual Studio Code and a major mode for Emacs, both of which provide rich editing support for FrogLang files. A plugin is also available for JetBrains IDEs. Any editor that supports the Language Server Protocol can be connected to ProofFrog's bundled LSP server; see the [Engine Internals]({% link researchers/engine-internals.md %}) page for details.

- TOC
{:toc}

---

## VSCode

### Installation

The extension is available on the [VSCode Marketplace](https://marketplace.visualstudio.com/items?itemName=ProofFrog.prooffrog). To install it, open the Extensions view in VSCode, search for "ProofFrog", and click Install.

**Requirements.** The extension requires VSCode 1.85 or later and Python 3.11 or later with ProofFrog installed in the Python environment it uses. By default the extension looks for `python3` on your PATH. If you use a virtual environment, set the `prooffrog.pythonPath` setting to the full path of that environment's interpreter:

```json
{
  "prooffrog.pythonPath": "/path/to/ProofFrog/.venv/bin/python"
}
```

See [Installation]({% link manual/installation.md %}) for instructions on setting up ProofFrog itself.

---

### Features

**Syntax highlighting.** Provides highlighting for all four FrogLang file extensions (`.primitive`, `.scheme`, `.game`, and `.proof`), covering keywords, types, literals, comments, and import paths.

**Diagnostics.** Parse errors are reported as squiggle underlines on every keystroke. On save, the extension runs type checking and reports any type errors inline. For `.proof` files, saving also triggers full proof verification: each game hop is checked, and failed hops appear as error diagnostics on the relevant line in the `games:` list.

**Go-to-definition.** Pressing F12 (or Cmd/Ctrl+click) on an import path navigates to the imported file. On a dotted name such as `E.KeyGen`, the extension jumps to the declaration of that field or method within the imported file.

**Hover information.** Hovering over an import name or a dotted member reference shows a popup with the interface description for that primitive, scheme, or game, or the signature of the specific method.

**Outline panel.** The Explorer Outline panel shows the structural elements of the active file: primitive or scheme names with their fields and methods, game or reduction definitions with their oracle methods, the `theorem:` declaration in a proof file, and the `games:` list with each step as a child entry.

**Code folding.** Method bodies, game and reduction bodies, and the `games:` list in a proof file can be collapsed. Blocks of three or more consecutive comment lines are also foldable.

**Rename (F2).** Renames all whole-word occurrences of an identifier throughout the current file, skipping occurrences inside comments and string literals. Language keywords and built-in type names cannot be renamed.

**Completion and signature help.** Context-sensitive keyword completion offers different keyword sets for each file type. Member completion triggers after a dot (`.`) and lists the fields and methods of the named import or `let:` binding. Signature help appears when you open a parenthesis on a method call and highlights the active parameter as you type commas.

**Code lens for proof hops.** In `.proof` files, after a save triggers proof verification, each line in the `games:` list receives an inline annotation showing whether that hop passed, failed, or was an assumption hop. Failed hops are also reported as error diagnostics.

**Proof hops tree view.** When a `.proof` file is active, a "ProofFrog: Proof Hops" panel appears in the Explorer sidebar. It lists every game hop with its pass/fail status and the descriptions of the two games being compared. Clicking an entry navigates to the corresponding line in the proof file.

---

## Emacs

Since version 0.6.0 ProofFrog ships an Emacs major mode, `prooffrog-mode`, in the [`emacs/`](https://github.com/ProofFrog/ProofFrog/tree/main/emacs) directory of the repository.

### Installation

The package is not yet on MELPA or NonGNU ELPA, so install it from a checkout of the repository:

```elisp
(add-to-list 'load-path "/path/to/ProofFrog/emacs")
(require 'prooffrog-mode)
```

Or, with `use-package`:

```elisp
(use-package prooffrog-mode
  :load-path "/path/to/ProofFrog/emacs")
```

**Requirements.** Emacs 26.1 or later (27+ recommended), ProofFrog installed in a Python environment, and either `eglot` (built in since Emacs 29, and the recommended choice) or `lsp-mode` for the LSP features.

The mode associates itself automatically with all four FrogLang extensions: `.primitive`, `.scheme`, `.game`, and `.proof`.

### Features

**Syntax highlighting.** Covers declaration keywords (`Primitive`, `Scheme`, `Game`, `Reduction`, `Phase`), the proof-structure labels (`proof:`, `let:`, `assume:`, `lemma:`, `theorem:`, `games:`, `by`), control flow, built-in types, constants and binary literals, the sampling operator, quoted import paths, and definition names.

**Indentation.** Brace-based, with awareness of the proof section labels. The width is configurable via `prooffrog-indent-offset` (default 4).

**Comments.** `//` line comments, wired to the standard Emacs commenting commands (`M-;`).

**Electric pairs.** Auto-closing of `{}`, `[]`, and `<>`.

**Imenu.** `M-x imenu` jumps to `Primitive`, `Scheme`, `Game`, and `Reduction` definitions.

**LSP integration.** The full feature set of ProofFrog's language server is available: diagnostics, context-aware completion, hover, go-to-definition, rename, code lens showing proof verification status, document symbols, folding, and signature help. The client starts automatically when you open a FrogLang file — no per-project configuration needed.

### Customization

```elisp
;; Change indentation width (default: 4)
(setq prooffrog-indent-offset 2)

;; Point the LSP server at a specific Python interpreter
(setq prooffrog-python-path "/path/to/ProofFrog/.venv/bin/python3")

;; Disable automatic LSP startup
(setq prooffrog-lsp-enabled nil)
```

With automatic startup disabled, `M-x prooffrog-start-lsp` starts the client by hand. To use `lsp-mode` in place of `eglot`, add `:hook (prooffrog-mode . lsp)` to your `use-package` form.

---

## JetBrains

There's a plugin available for JetBrains IDE-s which provides syntax validation and highlighting, custom color settings, import statement file path references, context-menu actions and other features for the ProofFrog language. You can obtain the plugin from the JetBrains Marketplace inside the IDE. The project is hosted in [this GitHub repository](https://github.com/aabmets/proof-frog-ide-plugin).

---

## Adding a new editor

Any editor that supports the Language Server Protocol can be connected to ProofFrog's LSP server. The server is started with `proof_frog lsp` (or `python3 -m proof_frog lsp`) and communicates over stdio using the standard JSON-RPC wire protocol. It uses full document synchronisation (`TextDocumentSyncKind.Full`). The language ID for all four file types is `prooffrog`. The server expects the working directory to match the directory from which the proof files are being edited, so that import paths resolve correctly. See the [Engine Internals]({% link researchers/engine-internals.md %}) page for a full description of the protocol surface, the supported LSP methods, and the custom notifications (`prooffrog/verificationDone`, `prooffrog/proofSteps`) used by the proof hops tree view.
