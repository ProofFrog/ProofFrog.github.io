---
title: Manual
layout: default
nav_order: 2
has_children: true
permalink: /manual/
---

# Manual

ProofFrog is a tool for verifying transitions in cryptographic game-hopping proofs. This manual is the place to start if you want to *use* it: install it, write your first proof, and look up language constructs as you go.

## Reading order

If you are new to ProofFrog, work through the pages below in order:

1. [Installation]({% link manual/installation.md %}) — set up Python, install via pip, and verify.
2. [Tutorial Part 1: Hello Frog]({% link manual/tutorial-1-hello-frog.md %}) — run an existing proof, break it on purpose, fix it. No FrogLang written.
3. [Tutorial Part 2: OTP has one-time secrecy]({% link manual/tutorial-2-otp-ots.md %}) — write your first complete four-file proof from scratch.
4. [Worked Examples]({% link manual/worked-examples/index.md %}) — read fully-explained walkthroughs of real proofs from `examples/`, starting with [Chained Encryption]({% link manual/worked-examples/chained-encryption.md %}) (the first reduction proof) and [KEM-DEM CPA]({% link manual/worked-examples/kemdem-cpa.md %}) (a multi-primitive proof).

After that, treat the manual as a reference and use the navigation to look up what you need.

## Reference

- [Language Reference]({% link manual/language-reference/index.md %}) — types, operators, sampling, statements, the four file types, and the execution model.
- [Transformations]({% link manual/transformations.md %}) — the engine's canonicalization pipeline at a user-facing level: what fires automatically, the catalogue of helper games, and how to diagnose a failing hop.
- [Limitations]({% link manual/limitations.md %}) — capability limits and engine soft spots; distinct from soundness.
- [CLI Reference]({% link manual/cli-reference.md %}) — the public commands: `version`, `parse`, `check`, `prove`, `describe`, `web`.
- [Web Editor]({% link manual/web-editor.md %}) — using `proof_frog web`.
- [Editor Plugins]({% link manual/editor-plugins.md %}) — VSCode and the LSP server.
- [Troubleshooting]({% link manual/troubleshooting.md %}) — symptom-keyed reference for common errors.
