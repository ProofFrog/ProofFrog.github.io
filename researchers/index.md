---
title: For Researchers
layout: default
nav_order: 4
has_children: true
permalink: /researchers/
---

# For Researchers

This area of the site is for people who want to *understand* ProofFrog's design, primaril from a scientific perspective.

If you are learning provable security or are new to ProofFrog, we recommend starting with the [manual]({% link manual/index.md %}).

- [Scientific Background]({% link researchers/scientific-background.md %}) — motivation, the three tasks of a game-hopping proof, design choices, positioning relative to other tools, and what ProofFrog is and isn't.
- [Engine Internals]({% link researchers/engine-internals.md %}) — high-level architecture, core modules, the transformation pipeline by category, diagnostics and near-miss matching, the engine-introspection CLI commands, and the LSP and MCP servers.
- [Soundness]({% link researchers/soundness.md %}) — what ProofFrog claims, what is in the trust base, what is *not* claimed, mitigations a careful user can apply, and the comparison framing relative to EasyCrypt and CryptoVerif.
- [GenAI & Proving]({% link researchers/gen-ai.md %}) — using LLM-based coding assistants to draft and iterate on proofs (a research-and-experimentation tool, not a recommended student workflow).
- [External Uses]({% link researchers/external-uses.md %}) — curated case studies of external projects using ProofFrog.
- [Publications]({% link researchers/publications/index.md %}) — papers, theses, talks, and how to cite ProofFrog.

## Lineage

ProofFrog was built by Ross Evans, Matthew McKague, and Douglas Stebila at the University of Waterloo, building on the earlier `pygamehop` tool by Douglas Stebila and Matthew McKague at Queensland University of Technology. Full bibliographic details are on the [Publications]({% link researchers/publications/index.md %}) page. Development is supported by the Natural Sciences and Engineering Research Council of Canada (NSERC) Discovery grant RGPIN-2022-03187.
