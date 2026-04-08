---
title: Proofs
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 6
---

# Proofs

A `.proof` file is the central artifact in ProofFrog. It proves that a scheme satisfies a security property under stated assumptions by exhibiting a sequence of games that walks from one side of the theorem to the other. Every adjacent pair of games in the sequence must be either interchangeable (verified automatically by the ProofFrog engine) or justified by an assumed security property. The engine checks every hop and reports the result.

---

## File structure

A `.proof` file has two parts separated by the `proof:` keyword.

**Helpers** (above `proof:`): zero or more `Reduction` definitions and intermediate `Game` definitions. These are used inside the `games:` block below.

**Proof block** (below `proof:`): four sections in order:

| Section | Required | Purpose |
|---|---|---|
| `let:` | yes | Declares sets, integers, primitive instances, and scheme instantiations |
| `assume:` | yes (may be empty) | Lists security properties assumed to hold for underlying primitives or schemes |
| `lemma:` | no | References other proof files whose theorems become available as assumptions |
| `theorem:` | yes | The security property to be proved |
| `games:` | yes | The ordered sequence of game steps |

The overall skeleton of a `.proof` file is:

```prooffrog
import 'relative/path/to/Scheme.scheme';
import 'relative/path/to/Security.game';

// Helpers: Reduction and intermediate Game definitions

Reduction R(params) compose AssumedGame(params) against TheoremGame(params).Adversary {
    // oracle implementations
}

proof:

let:
    Int lambda;
    MyScheme S = MyScheme(lambda);

assume:
    AssumedGame(someParam);

theorem:
    TheoremGame(S);

games:
    TheoremGame(S).Side1 against TheoremGame(S).Adversary;
    // ... intermediate steps ...
    TheoremGame(S).Side2 against TheoremGame(S).Adversary;
```

---

## Helpers section

The region above `proof:` (after any `import` statements) holds:

- **`Reduction` definitions** — adapters that translate between the theorem game's adversary interface and an assumed security game's interface. Detailed in the Reductions section below.
- **Intermediate `Game` definitions** — explicit game definitions that appear as steps in the `games:` sequence but are not already defined in an imported `.game` file.

Helpers are only meaningful when referenced from the `games:` block. They do not affect the `let:`, `assume:`, or `theorem:` sections. Intermediate games are documented in the games file-type reference; reductions are documented later on this page.

---

## The `let:` block

The `let:` block declares the mathematical objects used throughout the proof. Declarations can be:

- **`Int name;`** — a free integer variable (e.g., a security parameter). The proof holds for all values.
- **`Set name;`** — an abstract set (no internal structure).
- **`PrimitiveType name = PrimitiveType(params);`** — a primitive instance.
- **`SchemeType name = SchemeConstructor(params);`** — a scheme instance.

Examples drawn from real proofs:

```prooffrog
// OTPSecure.proof: a single integer parameter, one scheme instance
let:
    Int lambda;
    OTP E = OTP(lambda);
```

```prooffrog
// OTUCimpliesOTS.proof: abstract sets, then a primitive instance built from them
let:
    Set ProofMessageSpace;
    Set ProofCiphertextSpace;
    Set ProofKeySpace;
    SymEnc proofE = SymEnc(ProofMessageSpace, ProofCiphertextSpace, ProofKeySpace);
```

```prooffrog
// TriplingPRGSecure.proof: one integer, two chained scheme instances
let:
    Int lambda;
    PRG G = PRG(lambda, lambda);
    TriplingPRG T = TriplingPRG(G);
```

Once `E = OTP(lambda)` is in `let:`, every subsequent reference to `E` — including `OneTimeSecrecy(E).Real`, `E.Key`, and so on — is resolved through that binding. Names introduced in `let:` are in scope for the entire proof block.

For a full description of FrogLang types, see the Basics language reference page.

---

## The `assume:` block

The `assume:` block lists the security properties that the proof takes as given. Each entry names a security game and instantiates it with parameters from `let:`:

```prooffrog
assume:
    Security(G);
    BitStringSampling(lambda, lambda);
    BitStringSampling(lambda, 2 * lambda);
```

An assumption `Prop(params)` means: the two sides of the game pair `Prop` are computationally indistinguishable when instantiated with `params`. The proof is valid *conditional on* all stated assumptions being true.

**Empty `assume:` blocks.** If the proof holds unconditionally (information-theoretically), the `assume:` block is left empty. The OTP one-time-secrecy proof is the canonical example:

```prooffrog
assume:
```

**Helper games from `Games/Misc/`.** The `Games/Misc/` directory contains game pairs that capture simple probabilistic facts rather than cryptographic hardness assumptions — for example, `BitStringSampling` (concatenating two independent uniform samples equals one longer uniform sample) and `OTPUniform` (XOR with a uniform key produces a uniform ciphertext). These hold unconditionally and can be listed in `assume:` freely to enable certain game hops.

An assumption entry can appear in the `games:` sequence as a hop justification as many times as needed.

---

## The `lemma:` block

The optional `lemma:` block appears between `assume:` and `theorem:`. Each entry references another `.proof` file and adds that proof's theorem to the pool of available assumptions:

```prooffrog
lemma:
    OTUCimpliesOTS(proofE) by 'path/to/OTUCimpliesOTS.proof';
```

The engine verifies the referenced proof file (recursively), checks that all of its `assume:` entries are satisfied by the current proof's own assumptions, and then treats the lemma's theorem as an additional assumption. This allows large proofs to be decomposed into smaller verified pieces.

{: .important }
**`--skip-lemmas` flag.** During iterative proof development, lemma verification can be slow. Pass `--skip-lemmas` to `proof_frog prove` to bypass lemma verification and treat lemma theorems as unverified assumptions. See the CLI reference page for details.

---

## The `theorem:` block

The `theorem:` block states the single security property being proved:

```prooffrog
theorem:
    OneTimeSecrecy(E);
```

The parameter to the theorem must be a scheme instance declared in `let:` that satisfies the primitive expected by the security game. The engine checks at the start of proof verification that the first game step is one side of this theorem and the last game step is the other side.

---

## The `games:` block

The `games:` block is the sequence of game steps that constitutes the proof. Adjacent steps must be justified as either interchangeable (code-equivalent, checked automatically) or an assumption hop (justified by an entry in `assume:` or `lemma:`).

**Constraints:**
- The first step must be one side of the theorem's security property instantiated with the scheme from `let:`.
- The last step must be the other side.
- Every intermediate transition must be justifiable.

The sequence for the OTP proof has a single hop:

```prooffrog
games:
    OneTimeSecrecy(E).Real against OneTimeSecrecy(E).Adversary;

    OneTimeSecrecy(E).Random against OneTimeSecrecy(E).Adversary;
```

The engine inlines the OTP scheme into both games, canonicalizes the resulting code, and checks equivalence. Because XOR with a uniform random bit string that is used exactly once produces a uniform result, the two games canonicalize identically.

---

## Game step syntax

Each entry in the `games:` block takes one of two forms.

**Direct step** — the game is used without a reduction:

```prooffrog
GameProperty(params).Side against GameProperty(params).Adversary;
```

**Composed step** — the game is applied through a reduction:

```prooffrog
GameProperty(params).Side compose ReductionName(params)
    against TheoremGameProperty(params).Adversary;
```

In a composed step, `GameProperty(params).Side` is the assumed game (the challenger the adversary inside the reduction talks to), and `ReductionName(params)` is a `Reduction` defined in the helpers section. The adversary in `against ...` is the adversary for the theorem game.

The full six-step sequence from `OTUCimpliesOTS.proof` illustrates both forms:

```prooffrog
games:
    OneTimeSecrecy(proofE).Left against OneTimeSecrecy(proofE).Adversary;

    OneTimeUniformCiphertexts(proofE).Real compose R1(proofE)
        against OneTimeSecrecy(proofE).Adversary;

    OneTimeUniformCiphertexts(proofE).Random compose R1(proofE)
        against OneTimeSecrecy(proofE).Adversary;

    OneTimeUniformCiphertexts(proofE).Random compose R2(proofE)
        against OneTimeSecrecy(proofE).Adversary;

    OneTimeUniformCiphertexts(proofE).Real compose R2(proofE)
        against OneTimeSecrecy(proofE).Adversary;

    OneTimeSecrecy(proofE).Right against OneTimeSecrecy(proofE).Adversary;
```

Steps 1 and 6 are direct; steps 2 through 5 are composed with reductions `R1` and `R2`.

---

## Reductions in detail

A `Reduction` is a wrapper that adapts the theorem game's adversary interface to an assumed security game's interface. Syntactically:

```prooffrog
Reduction R(params) compose AssumedGame(params) against TheoremGame(params).Adversary {
    // method bodies
}
```

Inside a reduction body:

- **`challenger`** refers to the composed assumed game. Calling `challenger.Method(args)` invokes an oracle of `AssumedGame`.
- The reduction must **implement the oracle interface of the theorem game** — the same method names, parameter types, and return types that the theorem game's adversary expects.
- The two games' `Initialize` methods are merged during inlining: if either game has an `Initialize` method, the engine combines their state setup automatically.

The reduction acts as a simulator: from the theorem-game adversary's point of view, it is interacting with the theorem game; in reality, it is forwarding calls to the assumed game and translating inputs and outputs as needed.

Here is `R1` from `OTUCimpliesOTS.proof`, a complete reduction:

```prooffrog
// R1 forwards the left message to the OTUC oracle
Reduction R1(SymEnc se) compose OneTimeUniformCiphertexts(se)
    against OneTimeSecrecy(se).Adversary {
    se.Ciphertext Eavesdrop(se.Message mL, se.Message mR) {
        return challenger.CTXT(mL);
    }
}
```

`R1` receives two messages from the `OneTimeSecrecy` adversary (the `Eavesdrop` oracle), forwards only `mL` to the `OTUC` challenger's `CTXT` oracle, and returns the result. When `OTUC.Real` is composed with `R1`, the result is interchangeable with `OneTimeSecrecy.Left` (which encrypts `mL`). When `OTUC.Random` is composed with `R1`, the result is interchangeable with `OTUC.Random compose R2` (because neither `R1` nor `R2` uses the message when the ciphertext is random).

---

## The reduction parameter rule

{: .important }
> **A reduction's parameter list must include every parameter needed to instantiate the composed security game, even if that parameter is not referenced anywhere in the reduction body.**
>
> If a parameter required to instantiate `AssumedGame(params)` is missing from the reduction's parameter list, you will get a confusing instantiation error at the game step that uses the reduction — not at the reduction definition itself. The error message may not point clearly to the missing parameter.
>
> Example: a reduction that composes with `BitStringSampling(lambda, lambda)` must take `Int lambda` as a parameter (or take a scheme instance whose fields expose `lambda`), even if `lambda` does not appear in the reduction body. See `R2` in `TriplingPRGSecure.proof` for an example of an `Int lambda` parameter that is present solely to satisfy this rule.

---

## The four-step reduction pattern

Each use of a reduction in the `games:` sequence follows a standard four-step pattern. Every reduction hop occupies four consecutive entries — two interchangeability hops flanking one assumption hop:

{: .important }
```
G_A against Adversary;                          // interchangeability with Security.Side1 compose R
Security.Side1 compose R against Adversary;      // interchangeability
Security.Side2 compose R against Adversary;      // by assumption (Side1 -> Side2)
G_B against Adversary;                          // interchangeability with Security.Side2 compose R
```

Reading the four steps:

1. **Step 1 (direct game `G_A`)**: This game is equivalent to `Security.Side1 compose R`. The engine verifies this by inlining both and checking code equivalence.
2. **Step 2 (`Security.Side1 compose R`)**: The assumed game on its `Side1`, composed with the reduction.
3. **Step 3 (`Security.Side2 compose R`)**: The assumed game switches from `Side1` to `Side2`. This hop is justified by the assumption entry `Security(params)` in the `assume:` block, not by code equivalence.
4. **Step 4 (direct game `G_B`)**: This game is equivalent to `Security.Side2 compose R`. Again verified by code equivalence.

**Transitions 1-2 and 3-4** are interchangeability hops, checked by the engine.
**Transition 2-3** is the assumption hop, justified by an entry in `assume:`.

**Assumption hops are bidirectional.** A hop from `Side1` to `Side2` and a hop from `Side2` to `Side1` are both valid — indistinguishability is symmetric. In a symmetric proof, the forward half often uses `Real -> Random` hops and the reverse half uses `Random -> Real` hops.

The `TriplingPRGSecure.proof` example shows the four-step pattern applied twice (once per application of the underlying PRG):

```prooffrog
games:
    Security(T).Real against Security(T).Adversary;

    // Four-step pattern for the first PRG application:
    Security(G).Real compose R1(G, T) against Security(T).Adversary;   // step 2
    Security(G).Random compose R1(G, T) against Security(T).Adversary; // step 3: assumption hop

    // Four-step pattern for the second PRG application:
    Security(G).Real compose R3(G, T) against Security(T).Adversary;   // step 2
    Security(G).Random compose R3(G, T) against Security(T).Adversary; // step 3: assumption hop

    Security(T).Random against Security(T).Adversary;
```

`Security(T).Real` acts as `G_A` for the first pattern, and the interchangeability between it and `Security(G).Real compose R1(G, T)` is verified automatically. The `G_B` step of the first pattern is merged with the `G_A` step of the second pattern (they are both the transition between the two PRG hops), compressing the sequence.

---

## Verification and development workflow

To verify a proof:

```bash
proof_frog prove examples/Proofs/PRG/TriplingPRGSecure.proof
```

Use `-v` for verbose output showing canonical forms of each game:

```bash
proof_frog prove -v examples/Proofs/PRG/TriplingPRGSecure.proof
```

The engine reports each hop as `ok` or failing and prints the step type (`equivalence` or `assumption`). When a hop fails, the verbose output shows the canonical form of both sides so you can see where they diverge.

**Recommended incremental approach:**

1. Write the `let:`, `assume:`, and `theorem:` blocks first.
2. Add only the first and last game steps (the two sides of the theorem).
3. Write one reduction and add its corresponding four-step pattern to `games:`.
4. Run `proof_frog prove` after each addition. Address failures one hop at a time before adding more steps.

For a guided walkthrough of writing a complete proof from scratch, see Tutorial Part 2 ({% link manual/tutorial-2-otp-ots.md %}).
