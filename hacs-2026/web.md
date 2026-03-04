---
title: Web interface
parent: HACS 2026 Updates
layout: default
nav_order: 2
---

# Web interface

A recent new feature in ProofFrog is a web interface. 

The web interface lets you edit ProofFrog files with syntax highlighting, validate proofs from the web editor, and explore the game state at each hop.

To run the web interface:

```txt
proof_frog web [directory]
```

This starts a local web server (default port 5173) and opens the editor in your browser. The `[directory]` argument specifies the working directory for proof files; it defaults to the current directory.

The web interface is a work in progress, and there are many features we would like to add.

![ProofFrog web interface](../../assets/screenshot-web.png)
