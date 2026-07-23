---
title: Advantage Bounds
layout: default
parent: Manual
nav_order: 45
---

# Advantage Bounds
{: .no_toc }

A ProofFrog proof establishes that a security property follows from a list of assumptions. Since version 0.6.0 it also says *how much* security it establishes: after a proof verifies, the engine synthesizes the concrete advantage bound the hop sequence proves, prints it, and — if the proof author states the bound they believe the proof establishes — checks that claim against the synthesized one.

- TOC
{:toc}

---

## Overview

There are three layers, each building on the one before:

| Layer | What it does | Where it lives |
|---|---|---|
| **Synthesis** | Folds a verified proof's hops into a triangle-inequality sum over the assumptions used, and prints it | Automatic; no syntax needed |
| **Statistical helper bounds** | Replaces the opaque advantage term of a statistical helper game with a concrete expression | `advantage <= ...;` clause in a `.game` file |
| **Checking a claim** | Decides whether a bound the author claims is a valid upper bound on the synthesized one | `bound:` clause in a `.proof` file |

The first layer costs nothing: every proof that verifies now prints a bound. The second and third are opt-in.

---

## Synthesized bounds

When `proof_frog prove` succeeds, it prints one extra line after the hop summary table:

```
Advantage bound: Adv^PRGSecurity(T)(A) <= Adv^PRGSecurity(G)(B1) + Adv^PRGSecurity(G)(B2)
```

The left-hand side is the distinguishing advantage of an adversary {% katex %}A{% endkatex %} against the theorem's security property. The right-hand side is the sum the proof's hop sequence establishes, by the triangle inequality.

The fold is mechanical:

- An **interchangeability hop** contributes nothing. The two games induce identical output distributions, so the hop costs zero advantage.
- An **assumption hop** (or a lemma hop) contributes one term: the advantage of the reduction constructed at that hop, against the assumed security property.

Each distinct reduction becomes its own numbered adversary — `B1`, `B2`, and so on. Repeated uses of the *same* assumption through the *same* reduction collapse into a multiple: three such hops print as `3 * Adv^X(B1)` rather than three separate terms.

The example above is [`TriplingPRG_PRGSecurity.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRG_PRGSecurity.proof), which applies PRG security twice through two different reductions (`R1` and `R3`), so the bound has two terms.

{: .note }
Proofs that use the [`induction` construct]({% link manual/language-reference/proofs.md %}#induction-hybrid-arguments) are not yet supported by bound synthesis. Such a proof still verifies; instead of a bound, `prove` prints `Advantage bound: Adv^X(A) <= (not synthesized: inductive proofs are not yet supported)`.

---

## Declaring a bound on a helper game

A synthesized bound is only as informative as its terms. A hop that reduces to a genuine cryptographic assumption — PRG security, DDH — should stay symbolic, because that is exactly the quantity the proof is reducing to. But a hop that reduces to a *statistical* [helper game]({% link manual/language-reference/games.md %}#helper-games-as-a-special-case) is different: there the loss is a concrete probability, typically a birthday or guessing bound, and leaving it as an opaque symbol hides the number the reader actually wants.

A `.game` file may therefore declare that number, in an optional [`advantage <= ...;` clause]({% link manual/language-reference/games.md %}#the-advantage-clause) placed between the two `Game` blocks and the `export as` line:

```prooffrog
Game Replacement(Set S) {
    S Samp() {
        S val <- S;
        return val;
    }
}

Game NoReplacement(Set S) {
    Set<S> seen;

    S Samp() {
        S val <-uniq[seen] S;
        return val;
    }
}

// Birthday bound: over count_Samp uniform draws from S, the two games differ
// only on a collision.
advantage <= count_Samp * (count_Samp - 1) / (2 * |S|);

export as DistinctSampling;
```

### What may appear in the expression

The clause is numeric arithmetic — `+`, `-`, `*`, `/`, `^`, parentheses, and integer literals — over:

- **the games' shared parameters** (here, the `Set S`);
- **cardinalities** `|T|` of a type or parameter;
- **per-oracle query counts**, written `count_<Oracle>`, where `<Oracle>` names one of the games' methods other than `Initialize`.

Both games in the file take the same parameter list and expose the same oracles, so the clause is unambiguous about what it quantifies over.

### How query counts are resolved

`count_Samp` in the clause above is a placeholder: it means "the number of times the thing playing this game calls `Samp`". When the helper is used in an assumption hop, the thing playing it is the proof's reduction, so the engine derives each count by statically counting the reduction's calls to that oracle:

- a call in the reduction's `Initialize` body counts **once**, since `Initialize` runs once per execution;
- a call in any other reduction method counts `count_<method>` times — that method is an oracle of the *theorem* game, so the adversary may call it as often as it likes;
- a loop multiplies its body's count by the loop's trip count, and the branches of an `if` are summed, giving an upper bound.

The result is that the statistical term arrives stated in the theorem game's own query counts, rather than in symbols the reader has to chase back through the reduction. For [`DDH_implies_CDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDH_implies_CDH.proof), which hops through the `RandomTargetGuessing` helper, the printed bound is:

```
Advantage bound: Adv^CDH(G)(A) <= Adv^DDH(G)(B1) + count_Solve/|GroupElem<G>|
```

`Solve` is an oracle of the `CDH` theorem game, so `count_Solve` is a quantity the reader of the theorem statement already understands.

If the proof declares an integer query bound in its `assume:` block (`calls <= 64;`), the surviving counts are pinned to that number instead. This is sound because these statistical bounds are monotone in the query counts.

{: .important }
An `advantage <= ...;` clause is a **declared, unconditional fact**. The semantic checker validates only that it is well-formed — that its free names are real parameters and real oracles. It does not prove the bound. The clause is trusted exactly as the helper game itself is trusted, and it inherits the same caveat: it is up to the author and the reader to confirm that the stated probability is correct. Only put a clause on a game that encodes a statistical fact; genuine cryptographic assumptions should carry none, so that their contribution stays visible as a symbolic term.

Six of the random-oracle helper games in the [CFRG hybrid KEM case study](https://github.com/ProofFrog/examples/tree/main/applications/cfrg-hybrid-kems) carry such a clause, and each now ships alongside a hand-written EasyCrypt proof of the bound it declares, so those particular numbers are checked by a second tool rather than taken on trust.

---

## Claiming a bound in a proof

A `.proof` file may state the bound its author believes the proof establishes, in an optional [`bound:` clause]({% link manual/language-reference/proofs.md %}#the-bound-block) between `theorem:` and `games:`:

```prooffrog
theorem:
    KEM_INDCCA_ROM(hybrid, BitString<hybrid.Nin>, BitString<hybrid.Nss>, H);

bound:
      advantage(PRGSec(G) compose R_PRG_L)
    + advantage(KeyGenEquiv(KEM_PQ) compose R_KG_L)
    + advantage(RandomScalarDist(NG) compose R_Dist_Real)
    + advantage(SDH_SS(NG) compose R_Combined)
    + advantage(RandomScalarDist(NG) compose R_Dist_Random)
    + advantage(KeyGenEquiv(KEM_PQ) compose R_KG_R)
    + advantage(PRGSec(G) compose R_PRG_R);

games:
    // ...
```

### Syntax

A claimed bound is numeric arithmetic over:

| Form | Meaning |
|---|---|
| `advantage(Notion(args) compose R(args))` | The advantage against `Notion`, of the adversary built by composing the proof's reduction `R` with the theorem adversary |
| `advantage(Notion(args))` | The advantage against `Notion` for a hop played directly, with no reduction |
| `count_<Oracle>` | The number of adversary queries to `<Oracle>` of the *theorem* game |
| <code>&#124;T&#124;</code> | The cardinality of a type |
| any name from `let:` | A proof parameter, e.g. `lambda` |
| integer literals, `+ - * / ^`, parentheses | Ordinary arithmetic |

The reduction named after `compose` must be one the proof itself declares, and it must be the one that composes the named notion; `count_` must name a real oracle of the theorem game. These are checked when the file is type-checked, so a typo in a `bound:` clause is caught by `proof_frog check` rather than surfacing later as a mysterious mismatch.

A statistical term is written out directly. The corresponding clause for `CG_seedbased_LEAK_BIND_K_PK.proof` ends with a literal `2 ^ (1 - lambda)`:

```prooffrog
bound:
      advantage(KeyGenEquiv(KEM_PQ) compose R_KG_L)
    + advantage(LEAK_BIND_K_PK(KEM_PQ) compose R_PQ_Bind)
    + advantage(KDFCollisionResistance(H) compose R_KDF)
    + advantage(KeyGenEquiv(KEM_PQ) compose R_KG_R)
    + 2 ^ (1 - lambda);
```

### How the claim is checked

After the hop sequence verifies and the bound is synthesized, the engine matches each `advantage(...)` reference in the claim against the synthesized terms by exact identity of the pair (notion, reduction). A reference that matches nothing in the synthesized sum becomes fresh non-negative slack — it can only make the claim larger, so treating it this way is safe.

It then asks whether {% katex %}\text{claimed} - \text{synthesized} \geq 0{% endkatex %} holds everywhere in the region where all advantages, counts, and cardinalities are non-negative. SymPy settles the easy cases; anything harder goes to Z3 over the reals. (The real region is a superset of the integer domain the quantities actually live in, so a proof of non-negativity there is sound.)

The verdict is three-valued:

| Verdict | Output | Effect on `prove` |
|---|---|---|
| **verified** | `Claimed bound verified: claim is a valid upper bound on the synthesized bound.` | Proof succeeds |
| **not verified** | `Claimed bound NOT verified: claim is smaller than the synthesized bound on some nonnegative assignment`, with a witness assignment | Proof **fails** |
| **undecided** | `Claimed bound: could not decide the claim against the synthesized bound.` | Warning only; proof succeeds |

"Not verified" means the claim was proved to be *smaller* than what the proof establishes — the author has claimed more security than the hop sequence supports. That is a real error in the proof document, so it fails the run. Pass [`--skip-bound`]({% link manual/cli-reference.md %}#prove) to downgrade it to a warning while you work out which term is missing.

"Undecided" covers comparisons the engine could not settle: symbolic exponents, a Z3 `unknown`, a timeout. The claim is neither confirmed nor refuted, and the run only warns.

{: .important }
A **verified** claim means the claimed expression is a valid upper bound on the bound this proof establishes. It does not mean the claim is *tight* — a claim looser than the synthesized bound verifies happily. And it is not an independent security proof: everything the synthesized bound rests on, including any trusted `advantage <= ...;` clauses and every assumption in `assume:`, it still rests on.

---

## Working with bounds

**Start without a `bound:` clause.** Get the proof verifying first, read the bound the engine prints, and only then write it down as a claim. The synthesized bound tells you exactly which terms exist and how they are named, which makes the claim easy to write correctly.

**Use the claim as a regression check.** Once a `bound:` clause is in place, any later edit that adds a hop, changes a reduction, or drops an assumption will change the synthesized bound — and `prove` will fail if the change made the proof weaker than the recorded claim. This catches a class of silent regression that the pass/fail result alone does not.

**Round for readability.** Because a looser claim still verifies, a `bound:` clause can state the bound in the form you would put in a paper — collecting terms, rounding a fiddly statistical expression up to a cleaner one — while the engine confirms the rounding went the safe way.

---

## Related pages

- [Games]({% link manual/language-reference/games.md %}#the-advantage-clause) — the `advantage <= ...;` clause in the language reference.
- [Proofs]({% link manual/language-reference/proofs.md %}#the-bound-block) — the `bound:` clause in the language reference.
- [CLI Reference]({% link manual/cli-reference.md %}#prove) — the `--skip-bound` flag.
- [Soundness]({% link researchers/soundness.md %}) — what a bound printed by ProofFrog does and does not certify.
