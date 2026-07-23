---
title: LaTeX Export
layout: default
parent: Manual
nav_order: 75
---

# LaTeX Export
{: .no_toc }

ProofFrog can render a FrogLang file as typeset pseudocode, so that a scheme, a game definition, or a whole game-hopping proof can go straight into a paper. The [`export-latex`]({% link manual/cli-reference.md %}#export-latex) command does this using the [`cryptocode`](https://www.ctan.org/pkg/cryptocode) package.

- TOC
{:toc}

{: .warning }
LaTeX export is **preliminary**. Expect to hand-adjust the output before publishing it, and expect the output style to change in future versions. Treat a generated `.tex` file as a first draft you will edit, not as a build artifact you can regenerate over your edits.

---

## What it produces

```bash
proof_frog export-latex examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof
# Wrote examples/Proofs/PRG/TriplingPRG_PRGSecurity.tex
```

All four file types are accepted. A `.primitive`, `.scheme`, or `.game` renders as one or more `cryptocode` procedure blocks; a `.proof` renders as a complete proof document, described [below](#proof-documents).

By default the output is a self-contained `\documentclass{article}` document that compiles on its own — useful for checking the rendering in isolation. Pass `--no-standalone` to emit a fragment instead, with no preamble and no `document` environment, suitable for `\input`-ing into a larger LaTeX file.

---

## The macro preamble

Every algorithm, scheme, game, and property name the exporter encounters becomes a LaTeX macro, declared in the preamble with `\providecommand`:

```latex
\providecommand{\Enc}{\ensuremath{\mathsf{Enc}}}
\providecommand{\PRGSecurity}{\ensuremath{\mathsf{PRGSecurity}}}
```

The body of the document then uses `\Enc` rather than `\mathsf{Enc}` directly. This exists so you can change how a name renders without editing the generated file.

**Overriding a macro.** Because `\providecommand` is a no-op when the command already exists, defining the name *before* you `\input` the generated file wins:

```latex
\newcommand{\Enc}{\mathsf{Encrypt}}
\input{my-proof.tex}
```

**Name collisions.** A few FrogLang names would clobber a LaTeX builtin if declared directly — `\Pr`, `\log`, `\det`. These are emitted with a `Frog` prefix instead: `\FrogPr`. If you are overriding such a name, override the prefixed form.

---

## Proof documents

Exporting a `.proof` file produces a document in three parts: the definitions and construction, a `theorem` environment stating the result, and an `amsthm` `proof` environment walking the game sequence.

**The theorem statement includes the synthesized bound.** The [advantage bound]({% link manual/advantage-bounds.md %}) the engine derives for the proof is typeset as part of the theorem, so the exported statement is concrete rather than merely qualitative:

```latex
\begin{theorem}
If indistinguishability holds for $\PRGSecurity(\G)$, then indistinguishability holds
for $\PRGSecurity(\T)$. Concretely, for every adversary $\mathcal{A}$,
\begin{align*}
\Adv{\PRGSecurity(\T)}{\mathcal{A}} &\le \Adv{\PRGSecurity(\G)}{\mathcal{B}_{1}} \\
&\quad + \Adv{\PRGSecurity(\G)}{\mathcal{B}_{2}}
\end{align*}
where each of $\mathcal{B}_{1}$, $\mathcal{B}_{2}$ runs in approximately the time of
$\mathcal{A}$.
\end{theorem}
```

**The game sequence renders in reading order.** The games appear as non-floating blocks in the order the proof visits them, rather than as floating figures that LaTeX may relocate.

**Each hop is stated as prose.** Between two games, the exporter writes the relation it established — either the probability equality, for an interchangeability hop, or the assumption and the advantage term it costs, for an assumption hop:

```latex
Games $G_{0}$ and $G_{1}$ are perfectly indistinguishable: $\Pr[G_{0} = 1] = \Pr[G_{1} = 1]$.
% commentary (author): explain the intuition for the G_0 -> G_1 hop
```

The invisible `% commentary (author): ...` comment following each hop is a placeholder for you to fill in. The exporter can state *what* changed; it cannot state *why*, and a proof that a reader can follow needs that narrative. Filling these in is the main hand-editing the output is designed to invite.

**Adjacent games highlight what changed.** By default each game's lines that differ from the previous game's are wrapped in a soft gray box, so a reader can see at a glance what a hop touched. Use `--diff-style color` for colored text instead, or `--no-diff` to turn the highlighting off. The highlight macro is itself overridable — it is emitted as `\providecommand{\pfhighlight}[1]{...}`.

### Symbolic versus inlined composition

`--composition` controls how a step that composes a challenger with a reduction renders:

| Value | Rendering |
|---|---|
| `symbolic` (default) | The step is shown as `Notion.Side ∘ R(args)`, with the reduction's own code displayed once. An assumption hop's two steps share a reduction, so the second points back at the first rather than repeating it. |
| `inlined` | The step is shown as the fully inlined game — the reduction composed with the challenger, flattened into a single procedure. |

Symbolic output is closer to how a game-hopping proof is written on paper and is usually what you want in a paper. Inlined output is bulkier but shows the actual code the engine compared, which is useful when you are explaining *why* a hop validates.

---

## Known gaps in this version

- **One backend.** Only `cryptocode` is available. The exporter is structured around a `Backend` protocol so other pseudocode packages can be added, but none are implemented yet.
- **XOR renders as `+`.** In exported proof bodies, XOR between two `BitString` operands renders as `+` rather than `\oplus`. The expression renderer knows how to make this distinction when it is given a type map, but the proof orchestrator does not yet populate one from semantic analysis. In the meantime, this is a straightforward find-and-replace in the generated file.
- **The proof document is a scaffold.** As noted above, the narrative commentary is left blank by design, and the surrounding text ("where each of $\mathcal{B}_i$ runs in approximately the time of $\mathcal{A}$") is boilerplate that you should check against what your reduction actually does — ProofFrog [does not model running time]({% link manual/limitations.md %}).

---

## Related pages

- [CLI Reference]({% link manual/cli-reference.md %}#export-latex) — the full option list.
- [Advantage Bounds]({% link manual/advantage-bounds.md %}) — where the bound in the theorem statement comes from.
