---
title: Execution Model
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 2
---

# Execution Model

[Basics]({% link manual/language-reference/basics.md %}) covers what FrogLang syntax looks like: types, operators, statements, and sampling syntax. This page covers what it *means* to execute a game: how state is initialized and persisted, what an adversary can observe, how sampling and non-determinism are modeled, and how games are composed with schemes and reductions. The four file-type pages (Primitives, Schemes, Games, Proofs) cover what is syntactically and semantically legal in each file kind.

---

## The adversary model

An **adversary** in FrogLang is an implicit, computationally bounded external entity. It is not written in FrogLang — it is the abstract party that the game is designed to challenge. The adversary:

- Has access to the game's oracle methods (all methods other than `Initialize`, or in phased games, the oracles listed for the current phase).
- May call any available oracle in any order, any number of times (including zero times).
- May choose arguments to each oracle call *adaptively* — that is, based on all values returned by prior oracle calls.
- Has no direct access to the game's internal state (its fields). The only information the adversary can obtain is what the game explicitly returns through oracle responses.
- Eventually halts and produces an output value. In most security definitions, this output is a single bit ("guess").

The security model is **left/right indistinguishability**: a scheme is considered secure if no efficient adversary can distinguish between interacting with the left-side game and the right-side game with more than negligible probability. FrogLang uses this formulation exclusively; win/lose games (such as unforgeability) can be reformulated as left/right games when needed.

---

## Game execution model

One execution of a game `G` with an adversary `A` proceeds in three stages:

1. **Field initialization.** All state fields are set up. Fields declared with an explicit initializer (`Type x = expr;`) are assigned the value of `expr`. Fields declared without an initializer (`Type x;`) are left in an undefined state until the first assignment.

2. **`Initialize` call.** If the game defines an `Initialize` method, it is called exactly once before the adversary sees any oracle. This is where games typically perform setup: sampling cryptographic keys, setting counters, preparing tables. In most games `Initialize` has return type `Void`. The first phase of a phased game (see below) is also always `Void`; only the `Initialize` methods of *subsequent* phases may return a value that is delivered to the adversary as part of the phase transition.

3. **Oracle interaction phase.** The adversary calls the game's oracles freely, in any order, any number of times. Each call executes the oracle's body, which may read and write state fields, sample fresh randomness, and return a value. The adversary observes only the return values.

4. **Adversary output.** The adversary halts and produces its output.

**Phased games** are used when a security definition requires the adversary to pass through distinct stages — for example, CCA security, where the adversary first queries a decryption oracle, then receives a challenge ciphertext, and then queries a *restricted* decryption oracle. In a phased game, each phase has its own `Initialize` method and oracle list:

```prooffrog
Phase {
    Void Initialize() {
        k = E.KeyGen();
    }
    oracles: [Enc, Dec];
}

Phase {
    E.Ciphertext Initialize(E.Message mL, E.Message mR) {
        cStar = E.Enc(k, mL);
        return cStar;
    }
    oracles: [Enc, restrainedDec];
}
```

The adversary interacts with Phase 1's oracles after the first `Initialize` runs, then triggers Phase 2 by calling Phase 2's `Initialize`, then interacts with Phase 2's oracles. State fields are shared across all phases.

---

## State semantics

**Persistence within an execution.** A game's state fields persist across all oracle calls within a single execution. If an oracle writes to a field, subsequent oracle calls in the same execution see the updated value. This is how games track state like "which messages have been queried" or "what key was generated."

**Isolation across executions.** Each execution is independent. There is no leakage of state from one execution to another. When the engine checks whether two games are interchangeable, it considers all adversaries, each of which interacts in a single fresh execution.

**Local variable scope.** Local variables declared inside an oracle method are scoped to that single invocation. Each call to the same oracle gets fresh local variables; there is no implicit sharing between calls except through the game's state fields.

---

## Non-determinism and the `deterministic`/`injective` annotations

{: .important }
**Scheme method calls are non-deterministic by default.** When a game or scheme calls `F.evaluate(k, x)`, the engine does not assume this call is a pure function. Two calls with identical arguments may, in principle, return different values. The engine is conservative: unless told otherwise, it treats every scheme method call as potentially non-deterministic.

This default exists because FrogLang does not look inside a primitive's method bodies — primitives declare *interface*, not behavior. The engine cannot tell, without explicit annotation, whether a primitive method does internal sampling, maintains hidden state, or is a pure computation.

Two annotations on primitive method declarations override the default:

| Annotation | Meaning |
|---|---|
| `deterministic` | This method always returns the same output for the same inputs. Every call with identical arguments is equivalent to the first call. |
| `injective` | This method maps distinct inputs to distinct outputs. |

Example:

```prooffrog
deterministic injective BitString<n> Encode(GroupElem<G> g);
```

The `deterministic` annotation enables the engine to:
- Treat calls as pure expressions (safe to inline, alias, hoist, and deduplicate).
- Replace a duplicate call `[F.eval(k, x), F.eval(k, x)]` with `v = F.eval(k, x); [v, v]`.
- Propagate a field initialized with a deterministic call into later oracles that make the same call.

The `injective` annotation allows the engine to see through encoding wrappers when deciding whether two random function inputs are structurally distinct.

Both annotations are *semantic claims*. The typechecker enforces that when a scheme extends a primitive, the scheme's implementation of each method carries exactly the same `deterministic`/`injective` modifiers as the primitive declared. The engine uses these claims to enable certain canonicalization transforms — see the Transformations page for details.

---

## Sampling, randomness, and freshness

FrogLang uses the `<-` operator for all explicit randomness. Every sampling statement produces an **independent**, **uniform** draw from the specified domain.

**Basic uniform sampling.** Each statement like

```prooffrog
BitString<n> r <- BitString<n>;
```

draws a value uniformly at random from the full domain. Crucially, each such statement is independent of every other sampling statement — including other executions of the *same* statement in different oracle calls.

**Unique (rejection) sampling.** The statement

```prooffrog
BitString<n> x <-uniq[S] BitString<n>;
```

samples uniformly from `BitString<n> \ S`, where `S` is a set expression. Semantically this is rejection sampling: draw from `BitString<n>`, repeat if the result is already in `S`. The result is guaranteed to be fresh with respect to `S`. This is used when a nonce or challenge must be distinct from previously used values.

**Sampling into a map entry.** The statement `M[k] <- BitString<n>;` samples a fresh value into the entry of map `M` at key `k`. This is the imperative analogue of the random-function lazy evaluation described next: a `Map` together with `M[k] <-` sampling on the first query to each key implements exactly the same lazily-evaluated truly random function semantics that `Function<D, R>` makes a primitive type.

**Random functions (the random oracle model).** The statement

```prooffrog
Function<D, R> H <- Function<D, R>;
```

instantiates a *truly random function*. Its semantics:

- Calling `H(x)` returns a value drawn uniformly from `R`.
- Repeated calls to `H` on the *same* input `x` always return the *same* value (consistency).
- Calls on *distinct* inputs are independent.
- The function is evaluated lazily: the first query to a new input draws a fresh uniform value; later queries on that input return the stored result.

This is the standard formal model for a random oracle. It arises on the "Random" side of PRF security games and in proofs that use the random oracle methodology.

{: .important }
**Declared vs. sampled `Function<D, R>` values have different semantics.** In a proof's `let:` block, writing `Function<D, R> H;` (no `<-`) declares a *known deterministic function in the standard model*. The adversary can compute it; calls to `H(x)` are treated as deterministic (same input, same output, always). Writing `Function<D, R> H <- Function<D, R>;` places the proof in the random oracle model, where `H` is chosen uniformly at random from all functions `D -> R`. The engine applies random-function simplifications only to *sampled* `Function` values. Confusing the two forms is a common source of subtle proof errors.

---

## Composition

### Game composed with a scheme

Games are parameterized over primitives. For example, `Game Left(SymEnc E)` accepts any scheme that extends `SymEnc`. When a proof's `let:` block instantiates a scheme (e.g., `SymEnc E = OTP(lambda)`) and uses it in a game step, the scheme's method bodies become callable from the game's oracles.

During proof verification, the engine **inlines** these calls: each call `E.Enc(k, m)` in the game's body is replaced by the body of `OTP.Enc`, with formal parameters substituted for actual arguments. Local variables in the inlined body are renamed to avoid collisions. Inlining repeats in a fixed-point loop until all calls have been expanded (recursion is not allowed in FrogLang, so this always terminates).

The result is a flat, self-contained game body with no remaining calls to scheme methods. This flat form is what the engine canonicalizes and compares. For the full details of the canonicalization pipeline, see the Transformations page.

### Game composed with a reduction

`compose` produces a new game from a security game and a reduction. The composition syntax appears as a *game step* inside the `games:` block of a `.proof` file (it is not a free-standing expression you can write elsewhere). For example, a single line in a `games:` block might read:

```prooffrog
// inside a games: block of a .proof file
Security(G).Real compose R(G, T) against Security(T).Adversary;
```

This produces a composed game where:
- The adversary calls `R`'s oracle methods (which implement the interface of `Security(T)`).
- Inside `R`'s methods, the keyword `challenger` refers to `Security(G).Real`'s oracles; `challenger.Query()` calls that game's `Query` oracle.
- The combined state includes both `R`'s fields and `Security(G).Real`'s fields.

The `Initialize` methods are merged: if both the reduction and the composed game define `Initialize`, the reduction's `Initialize` may call `challenger.Initialize()` to trigger the composed game's initialization. Both run as part of the single initialization step of the composed game.

After composition, the engine inlines the reduction's calls to `challenger.*` just as it inlines scheme method calls — everything is flattened before canonicalization.

---

## Interchangeability — the central question

Two games are **interchangeable** if for every adversary `A`:

```
Pr[A interacting with Game1 outputs 1] = Pr[A interacting with Game2 outputs 1]
```

The probability distributions over adversary outputs are identical. This means no adversary can gain any advantage by seeing one game versus the other. This is the mathematical claim that each interchangeability hop in a game-hopping proof asserts.

The ProofFrog engine verifies interchangeability by canonicalizing both games and comparing their canonical forms. Canonicalization is a deterministic, semantics-preserving rewrite pipeline: inlining, algebraic simplification (XOR cancellation, group identities), dead code elimination, sampling normalization (sample merge, sample split, uniform + XOR simplification), and others. If the two canonical forms are structurally identical (up to variable renaming), the games are interchangeable. If the canonical forms differ only in the conditions of `if` statements, the engine uses an SMT solver (Z3) to check logical equivalence of those conditions.

For the full list of transforms and the rules governing when each fires, see the Transformations page.

---

## What is not on this page

- **Algebraic identities and other semantic equivalences** — XOR cancellation, group element identities, sample merge and split, uniform masking, and other transforms the engine applies during canonicalization are described on the Transformations page.

- **File-type rules** — what is syntactically and semantically legal in each kind of file (`.primitive`, `.scheme`, `.game`, `.proof`) is covered on the Primitives, Schemes, Games, and Proofs pages respectively.

- **What FrogLang does not model** — computational complexity (the engine works with exact equality, not asymptotic bounds), side channels, concurrency, and abort semantics are outside the scope of FrogLang's model. See the Limitations page for a full list of out-of-scope concerns and known engine gaps.
