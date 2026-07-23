---
title: Manual
layout: default
nav_order: 2
has_children: true
permalink: /manual/
has_toc: false
---

# Manual

ProofFrog is a tool for verifying transitions in cryptographic game-hopping proofs. This manual is the place to start if you want to *use* it: install it, write your first proof, and look up language constructs as you go.

## Getting Started

If you are new to ProofFrog, work through the pages below in order:

1. **[Installation]({% link manual/installation.md %})**: Set up Python, install via pip, and verify.
2. **[Tutorial]({% link manual/tutorial/index.md %})**: A two-part hands-on introduction — [Part 1: Hello Frog]({% link manual/tutorial/hello-frog.md %}) runs an existing proof, breaks it on purpose, and fixes it; [Part 2: OTP has one-time secrecy]({% link manual/tutorial/otp-ots.md %}) walks through writing your first complete four-file proof from scratch, about the security of the one-time pad.
3. **[Worked Examples]({% link manual/worked-examples/index.md %})**: Read fully-explained walkthroughs of real proofs, starting with [chained symmetric encryption]({% link manual/worked-examples/chained-encryption.md %}) (the first reduction proof) and then [chosen-plaintext attack security of hybrid public key encryption (the KEM-DEM construction)]({% link manual/worked-examples/kemdem-cpa.md %}) (a multi-primitive proof).

After that, treat the manual as a reference and use the navigation to look up what you need.

## Reference

- **[Language Reference]({% link manual/language-reference/index.md %})**: Types, operators, sampling, statements, the four file types (primitive, scheme, game, proof), and the execution model.
- **[Canonicalization]({% link manual/canonicalization.md %})**: How ProofFrog tries to check that two games are equivalent: what transformations it applies automatically, how to use helper games, and how to diagnose a failing hop.
- **[Advantage Bounds]({% link manual/advantage-bounds.md %})**: The concrete bound a verified proof establishes: how it is synthesized, how a helper game declares its statistical loss, and how to state and check a claimed bound.
- **[Limitations]({% link manual/limitations.md %})**: Capability limits of ProofFrog's language and canonicalization engine. ProofFrog's [soundness]({% link researchers/soundness.md %}) is discussed in the "For Researchers" section.
- **[Command-Line Interface Reference]({% link manual/cli-reference.md %})**: `proof_frog` on the command-line: `version`, `parse`, `check`, `prove`, `describe`, `export-latex`, `download-examples`, `web`.
- **[Web Editor]({% link manual/web-editor.md %})**: Using ProofFrog's web-based editor environment via `proof_frog web`.
- **[LaTeX Export]({% link manual/latex-export.md %})**: Rendering primitives, schemes, games, and proofs as typeset pseudocode via `proof_frog export-latex`.
- **[Editor Plugins]({% link manual/editor-plugins.md %})**: How to add ProofFrog extensions to VSCode, Emacs, and other editors using the <abbr title="Language Server Protocol">LSP</abbr> server.
- **[Troubleshooting]({% link manual/troubleshooting.md %})**: How to diagnose common errors.
