---
title: Getting Started
layout: default
nav_order: 2
---

# Getting Started

## Installation

Requires **Python 3.11+**.

### From PyPI

```txt
python3 -m venv .venv
source .venv/bin/activate
pip install proof_frog
```

### From source

```txt
git clone https://github.com/ProofFrog/ProofFrog
cd ProofFrog
git submodule update --init
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
pip install -r requirements-dev.txt
```

## Web Interface

```txt
proof_frog web [directory]
```

Starts a local web server (default port 5173) and opens the editor in your browser. The `[directory]` argument specifies the working directory for proof files; it defaults to the current directory.

The web interface lets you edit ProofFrog files with syntax highlighting, validate proofs from the web editor, and explore the game state at each hop.

## Command-Line Interface

| Command | Description |
|---------|-------------|
| `proof_frog parse <file>` | Parse a file and print its AST representation |
| `proof_frog check <file>` | Type-check a file for well-formedness |
| `proof_frog prove <file>` | Verify a game-hopping proof (`-v` for verbose output) |
| `proof_frog web [dir]` | Launch the browser-based editor |

## Writing a Proof

See the [guide to writing a proof in ProofFrog]({% link guide.md %}) for a tutorial on writing proofs in ProofFrog, covering all four file types (primitives, games, schemes, proofs) with examples, and the proof structure.

## Examples

The [examples repository](https://github.com/ProofFrog/examples) contains primitives, schemes, games, and proofs largely adapted from [*The Joy of Cryptography*](https://joyofcryptography.com/) by Mike Rosulek. See the [Examples]({% link examples.md %}) page for a full list.

For example:

```txt
git clone https://github.com/ProofFrog/examples.git
proof_frog prove 'examples/Proofs/SymEnc/OTUCimpliesOTS.proof'
```

## Vibe-Coding a Proof

See the information from [HACS 2026 on vibe-coding a ProofFrog proof with Claude Code]({% link hacs-2026/vibe/index.md %}).
