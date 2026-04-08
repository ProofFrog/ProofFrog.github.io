---
title: Language Reference
layout: default
parent: Manual
nav_order: 30
has_children: true
permalink: /manual/language-reference/
redirect_from:
  - /guide/
  - /guide.html
---

# Language Reference

FrogLang has four file types — primitives, schemes, games, and proofs — and a shared syntactic and semantic layer beneath them. This section is organized to match that structure.

- [Basics]({% link manual/language-reference/basics.md %}) covers the syntactic layer that every file type uses: types, expressions and operators, sampling, statements, and imports.
- [Execution Model]({% link manual/language-reference/execution-model.md %}) covers the operational layer — what it means for an adversary to interact with a game, how state persists, what interchangeability means formally, and how composition works.
- The four file-type pages below cover what is specific to each kind of file.

If you are not yet comfortable writing a small proof from scratch, work through [Tutorial Part 2]({% link manual/tutorial/otp-ots.md %}) first and come back here for lookups.

## Cheat sheet

| Page | What it covers |
|---|---|
| [Basics]({% link manual/language-reference/basics.md %}) | Types, operators, sampling forms, statements, imports |
| [Execution Model]({% link manual/language-reference/execution-model.md %}) | Adversary model, game lifecycle, state, non-determinism, composition, interchangeability |
| [Primitives]({% link manual/language-reference/primitives.md %}) | The `.primitive` file type: `Primitive` block, parameters, set fields, method signatures, `deterministic`/`injective` modifiers |
| [Schemes]({% link manual/language-reference/schemes.md %}) | The `.scheme` file type: `extends`, parameter forms, `requires`, field assignments, method bodies, the `this` keyword, matching-modifier rule |
| [Games]({% link manual/language-reference/games.md %}) | The `.game` file type: two-game requirement, `Initialize` and state, oracle methods, `export as`, phases, helper games |
| [Proofs]({% link manual/language-reference/proofs.md %}) | The `.proof` file type: `let:`, `assume:`, `lemma:`, `theorem:`, `games:` blocks, reductions, the reduction parameter rule, the four-step reduction pattern |
