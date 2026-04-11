---
title: Proofs
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 6
---

# Proofs
{: .no_toc }

A `.proof` file is the central artifact in ProofFrog. It proves that a scheme satisfies a security property under stated assumptions by exhibiting a sequence of games that walks from one side of the theorem to the other. Every adjacent pair of games in the sequence must be either interchangeable (verified automatically by the ProofFrog engine) or justified by an assumed security property. The engine checks every hop and reports the result.

- TOC
{:toc}

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

Game G_Mid(params) {
    // state variables and oracle methods for an intermediate proof step
}

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

Helpers are only meaningful when referenced from the `games:` block. They do not affect the `let:`, `assume:`, or `theorem:` sections. Reductions are documented later on this page; intermediate games are described in the next subsection.

### Intermediate games

An intermediate game is a `Game` definition written directly in the `.proof` file's helpers section (above `proof:`), rather than imported from a `.game` file. Intermediate games represent explicit proof states that appear as steps in the `games:` sequence. They are useful when a transition between two games is too large for the engine to verify in a single hop, so you introduce one or more named waypoints that break the transition into smaller, verifiable steps.

Because an intermediate game is a standalone game (not a game pair), it is referenced in the `games:` block by name and parameters alone — there is no `.Side` suffix:

```prooffrog
IntermediateGame(params) against TheoremGame(params).Adversary;
```

Here is a simplified example. Suppose a proof needs to transition from a game that encrypts using a PRF to one that encrypts using a truly random function. An intermediate game makes the boundary explicit:

```prooffrog
// Helpers section: define the intermediate game
Game G_RF(PRF F, SymEnc se) {
    Map<F.inp, F.out> T;

    se.Ciphertext Enc(se.Message m) {
        se.Key k = F.inp.uniform();
        if (T[k] == bottom) {
            T[k] = F.out.uniform();
        }
        return se.Enc(T[k], m);
    }
}

proof:
// ...
games:
    INDCPA_MultiChal(S).Real against INDCPA_MultiChal(S).Adversary;
    G_RF(F, se) against INDCPA_MultiChal(S).Adversary;          // intermediate step
    INDCPA_MultiChal(S).Random against INDCPA_MultiChal(S).Adversary;
```

The engine checks that each adjacent pair of games is interchangeable or justified by an assumption, just as it would for any other game step.

Intermediate games can take parameters from the proof's `let:` block. Common naming conventions include `G_` prefixes (e.g., `G_RF`, `G_RandKey`), `Intermediate` names (e.g., `Intermediate1`, `Intermediate2`), or descriptive names like `Hyb`. For real-world examples, see [`SymEncPRF_INDOT$.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDOT%24.proof) (which defines `G0`, `G_RF`, and `G_Uniq`) and [`HybridPKEDEM_INDCPA_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HybridPKEDEM_INDCPA_MultiChal.proof) (which defines `Intermediate1` and `Intermediate2`).

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
// INDOT$_implies_INDOT.proof: abstract sets, then a primitive instance built from them
let:
    Set ProofMessageSpace;
    Set ProofCiphertextSpace;
    Set ProofKeySpace;
    SymEnc proofE = SymEnc(ProofMessageSpace, ProofCiphertextSpace, ProofKeySpace);
```

```prooffrog
// TriplingPRG_PRGSecurity.proof: one integer, two chained scheme instances
let:
    Int lambda;
    PRG G = PRG(lambda, lambda);
    TriplingPRG T = TriplingPRG(G);
```

Once `E = OTP(lambda)` is in `let:`, every subsequent reference to `E` — including `OneTimeSecrecy(E).Real`, `E.Key`, and so on — is resolved through that binding. Names introduced in `let:` are in scope for the entire proof block.

For a full description of FrogLang types, see the [Basics]({% link manual/language-reference/basics.md %}) language reference page.

---

## The `assume:` block

The `assume:` block lists the security properties that the proof takes as given. Each entry names a security game and instantiates it with parameters from `let:`:

```prooffrog
assume:
    PRFSecurity(F);
    UniqueSampling(BitString<F.in>);
```

An assumption `Prop(params)` means: the two sides of the game pair `Prop` are computationally indistinguishable when instantiated with `params`. The proof is valid *conditional on* all stated assumptions being true.

**Empty `assume:` blocks.** If the proof holds unconditionally (information-theoretically), the `assume:` block is left empty. The OTP one-time-secrecy proof is the canonical example:

```prooffrog
assume:
```

**Helper games from `Games/Helpers/`.** The [`Games/Helpers/`](https://github.com/ProofFrog/examples/tree/main/Games/Helpers) directory contains game pairs that capture simple probabilistic facts rather than cryptographic hardness assumptions — for example, [`UniqueSampling`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/UniqueSampling.game) (sampling uniformly from a set is indistinguishable from sampling with exclusion of a bookkeeping set) and [`Regularity`](https://github.com/ProofFrog/examples/blob/main/Games/Hash/Regularity.game) (applying a hash to a uniformly random input yields a uniform output). These hold unconditionally and can be listed in `assume:` freely to enable certain game hops.

An assumption entry can be used in the `games:` sequence as a hop justification as many times as needed.

---

## The `lemma:` block

The optional `lemma:` block appears between `assume:` and `theorem:`. Each entry references another `.proof` file and adds that proof's theorem to the pool of available assumptions:

```prooffrog
lemma:
    INDOT$_implies_INDOT(proofE) by 'path/to/INDOT$_implies_INDOT.proof';
```

The engine verifies the referenced proof file (recursively), checks that all of its `assume:` entries are satisfied by the current proof's own assumptions, and then treats the lemma's theorem as an additional assumption. This allows large proofs to be decomposed into smaller verified pieces.

{: .important }
**`--skip-lemmas` flag.** During iterative proof development, lemma verification can be slow. Pass `--skip-lemmas` to `proof_frog prove` to bypass lemma verification and treat lemma theorems as unverified assumptions. See the [CLI reference]({% link manual/cli-reference.md %}) page for details.

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

The engine inlines the OTP scheme into both games, canonicalizes the resulting code, and checks equivalence. Because XOR with a uniform random bit string that is used exactly once produces a uniform result, the two games canonicalize identically without any additional effort by the proof author.

---

### Game step syntax

Each entry in the `games:` block takes one of two forms.

**Direct step** — the game is used without a reduction:

```prooffrog
GameProperty(params).Side against GameProperty(params).Adversary;
```

Direct steps are used for the starting and ending games (which use the `.Side` suffix of a game pair) and for intermediate games defined in the helpers section (which are standalone games referenced by name alone, without a `.Side` suffix).

**Composed step** — the game is applied through a reduction:

```prooffrog
GameProperty(params).Side compose ReductionName(params)
    against TheoremGameProperty(params).Adversary;
```

In a composed step, `GameProperty(params).Side` is the assumed game (the challenger the adversary inside the reduction talks to), and `ReductionName(params)` is a `Reduction` defined in the helpers section. The adversary in `against ...` is the adversary for the theorem game.

The full six-step sequence from [`INDOT$_implies_INDOT.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/INDOT%24_implies_INDOT.proof) illustrates both forms:

```prooffrog
games:
    INDOT(proofE).Left against INDOT(proofE).Adversary;

    INDOT$(proofE).Real compose R1(proofE)
        against INDOT(proofE).Adversary;

    INDOT$(proofE).Random compose R1(proofE)
        against INDOT(proofE).Adversary;

    INDOT$(proofE).Random compose R2(proofE)
        against INDOT(proofE).Adversary;

    INDOT$(proofE).Real compose R2(proofE)
        against INDOT(proofE).Adversary;

    INDOT(proofE).Right against INDOT(proofE).Adversary;
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

Here is `R1` from [`INDOT$_implies_INDOT.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/INDOT%24_implies_INDOT.proof), a complete reduction:

```prooffrog
// R1 forwards the left message to the INDOT$ oracle
Reduction R1(SymEnc se) compose INDOT$(se)
    against INDOT(se).Adversary {
    se.Ciphertext Eavesdrop(se.Message mL, se.Message mR) {
        return challenger.CTXT(mL);
    }
}
```

`R1` receives two messages from the `INDOT` adversary (the `Eavesdrop` oracle), forwards only `mL` to the `INDOT$` challenger's `CTXT` oracle, and returns the result. When `INDOT$.Real` is composed with `R1`, the result is interchangeable with `INDOT.Left` (which encrypts `mL`). When `INDOT$.Random` is composed with `R1`, the result is interchangeable with `INDOT$.Random compose R2` (because neither `R1` nor `R2` uses the message when the ciphertext is random).

---

### The reduction parameter rule

{: .important }
> **A reduction's parameter list must include every parameter needed to instantiate the composed security game, even if that parameter is not referenced anywhere in the reduction body.**
>
> If a parameter required to instantiate `AssumedGame(params)` is missing from the reduction's parameter list, you will get a confusing instantiation error at the game step that uses the reduction — not at the reduction definition itself. The error message may not point clearly to the missing parameter.
>
> Example: a reduction that composes with `UniqueSampling(BitString<F.in>)` must take a parameter that exposes `F.in` (such as a `PRF F` instance), even if `F` is not otherwise referenced in the reduction body. See `R_Uniq` in [`SymEncPRF_INDCPA$_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDCPA%24_MultiChal.proof) for an example.

---

### The four-step reduction pattern

The standard way to invoke an assumption in a game-hopping proof is the four-step reduction pattern. Suppose the proof is at some game {% katex %}G_A{% endkatex %} and wants to transition to a game {% katex %}G_B{% endkatex %} by appealing to a security assumption on some underlying primitive `Security` (whose two sides are `Security.Real` and `Security.Random`), via a reduction `R`. The pattern occupies four consecutive entries in the `games:` list:

1. {% katex %}G_A{% endkatex %} — some starting game.
2. `Security.Real compose R` — the engine verifies, by code equivalence, that this is interchangeable with {% katex %}G_A{% endkatex %}.
3. `Security.Random compose R` — the **assumption hop**. The engine accepts this transition without checking equivalence because `Security` is in the proof's `assume:` block, so its `Real` and `Random` sides are indistinguishable by hypothesis.
4. {% katex %}G_B{% endkatex %} — the engine verifies, by code equivalence, that this is interchangeable with `Security.Random compose R`.

So the assumption hop (steps 2 → 3) is sandwiched between two engine-verified interchangeability hops (1 → 2 and 3 → 4). The role of `R` is to bridge between the "high-level" games {% katex %}G_A{% endkatex %} and {% katex %}G_B{% endkatex %} and the lower-level `Security` game whose assumption we want to use.

**Assumption hops are bidirectional.** A hop from `Side1` to `Side2` and a hop from `Side2` to `Side1` are both valid — indistinguishability is symmetric. In a symmetric proof, the forward half often uses `Real -> Random` hops and the reverse half uses `Random -> Real` hops.

**Merging adjacent patterns.** When two four-step patterns are chained — one assumption hop followed by another — {% katex %}G_B{% endkatex %} of the first pattern often doubles as {% katex %}G_A{% endkatex %} of the second, compressing eight steps down to seven (or fewer if additional boundary games coincide). The [`TriplingPRG_PRGSecurity.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRG_PRGSecurity.proof) example shows the four-step pattern applied twice (once per application of the underlying PRG), with the shared boundary compressed:

```
games:
    PRGSecurity(T).Real against PRGSecurity(T).Adversary;                    //  }
                                                                            //  } 1st four-step
    PRGSecurity(G).Real compose R1(G, T) against PRGSecurity(T).Adversary;   //  } pattern
    PRGSecurity(G).Random compose R1(G, T) against PRGSecurity(T).Adversary; //  }   ]
                                                                             //  }   ]
    PRGSecurity(G).Real compose R3(G, T) against PRGSecurity(T).Adversary;   //  }   ] 2nd
    PRGSecurity(G).Random compose R3(G, T) against PRGSecurity(T).Adversary; //      ] four-step
                                                                             //      ] pattern
    PRGSecurity(T).Random against PRGSecurity(T).Adversary;                  //      ]
```

For a detailed walkthrough of the four-step pattern applied to a concrete proof, see the [Chained Encryption worked example]({% link manual/worked-examples/chained-encryption.md %}).

---

## Induction (hybrid arguments)

Many cryptographic proofs use a *hybrid argument*: a sequence of games {% katex %}G_0, G_1, \ldots, G_q{% endkatex %} where each adjacent pair differs in the treatment of a single oracle call, and the total number of steps {% katex %}q{% endkatex %} depends on the adversary's query budget. FrogLang supports this pattern with the `induction` construct, `calls <= q` query bounds, and `assume` step assumptions.

### Query bounds

A proof can declare a bound on the number of oracle calls the adversary makes by adding a `calls <= expr;` declaration in the `assume:` block:

```prooffrog
assume:
    PRFSecurity(F);
    calls <= q;
```

The variable `q` must be an `Int` declared in `let:`. This tells the engine that the adversary makes at most `q` calls to each oracle method per game execution. The bound is used during induction verification: the engine treats `q` as a symbolic integer and reasons about game equivalence under that constraint.

### The `induction` block

The `induction` block replaces a linear sequence of game hops with a parameterized loop. Its syntax is:

```prooffrog
induction(i from start to end) {
    // game steps parameterized by i
}
```

Here `i` is an `Int` variable (scoped to the block) that ranges from `start` to `end` (both expressions of type `Int`, typically `1` and `q`). The body contains game steps — the same syntax as the `games:` block — that are parameterized by `i`.

The engine verifies an induction block in two phases:

1. **Internal hops.** Each adjacent pair of steps inside the block is checked for interchangeability or assumption validity, treating `i` as a symbolic integer.
2. **Rollover.** The engine checks that the last step of iteration `i` is interchangeable with the first step of iteration `i + 1` (substituting `i + 1` for `i` in the first step). This ensures the iterations chain together correctly.

The step immediately before the `induction` block is checked against the first step of the block (at `i = start`), and the step immediately after is checked against the last step (at `i = end`).

### Step assumptions (`assume`)

Some hops inside an induction block (or adjacent to it) require facts about game state that the engine cannot derive structurally — typically bounds on a counter variable. The `assume expr;` directive asserts that `expr` holds at that point in the game sequence, making it available to the engine's Z3-based comparison:

```prooffrog
assume R_Hybrid(F, 1).count >= 1;

induction(i from 1 to q) {
    PRFSecurity(F).Real compose R_Hybrid(F, i) against PRFSecurity_MultiKey(F).Adversary;
    PRFSecurity(F).Random compose R_Hybrid(F, i) against PRFSecurity_MultiKey(F).Adversary;
}

assume R_Hybrid(F, q).count < q + 1;

PRFSecurity_MultiKey(F).Random against PRFSecurity_MultiKey(F).Adversary;
```

The expression in `assume` can reference game or reduction fields using dot notation (e.g., `R_Hybrid(F, 1).count`). The engine resolves these field references against the games in the adjacent hop and passes the assertion to Z3 as an additional constraint. Step assumptions placed immediately before an `induction` block apply to the entry hop; those placed at the end of the block (after the last game step) apply to the rollover check.

{: .important }
Step assumptions are **not verified** by the engine — they are trusted assertions that the proof author provides. Using an incorrect step assumption can make an invalid proof appear to verify. Use them only for facts that follow from the query bound and the structure of the reduction (such as counter range constraints).

### Example: multi-key PRF security

The proof that multi-key PRF security follows from single-key PRF security ([`PRFSecurity_implies_PRFSecurity_MultiKey.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRF/PRFSecurity_implies_PRFSecurity_MultiKey.proof)) is a clean example of induction. The reduction `R_Hybrid` uses a counter to select the `i`-th call for delegation to the PRF challenger:

```prooffrog
games:
    PRFSecurity_MultiKey(F).Real against PRFSecurity_MultiKey(F).Adversary;

    assume R_Hybrid(F, 1).count >= 1;

    induction(i from 1 to q) {
        PRFSecurity(F).Real compose R_Hybrid(F, i)
            against PRFSecurity_MultiKey(F).Adversary;
        PRFSecurity(F).Random compose R_Hybrid(F, i)
            against PRFSecurity_MultiKey(F).Adversary;
    }

    assume R_Hybrid(F, q).count < q + 1;

    PRFSecurity_MultiKey(F).Random against PRFSecurity_MultiKey(F).Adversary;
```

Each iteration replaces one PRF call with a random output via the standard assumption hop pattern. The rollover check ensures that iteration `i`'s final game (where calls `1` through `i` are random) matches iteration `i + 1`'s first game (where calls `1` through `i` are also random).

For a more complex example with intermediate games inside the induction body, see [`CounterPRG_PRGSecurity.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/CounterPRG_PRGSecurity.proof).

---

## Verification and development workflow

ProofFrog offers two ways to verify proofs: the command-line interface (CLI) and the browser-based web editor. Both use the same underlying engine; choose whichever fits your workflow.

### CLI workflow

To verify a proof from the terminal:

```bash
proof_frog prove examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof
```

Use `-v` for verbose output showing canonical forms of each game, or `-vv` for very verbose output including detailed canonicalization information:

```bash
proof_frog prove -v examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof
```

The engine reports each hop as `ok` or failing and prints the step type (`equivalence` or `assumption`). When a hop fails, the verbose output shows the canonical form of both sides so you can see where they diverge.

You can also type-check a proof file without running the full proof verification:

```bash
proof_frog check examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof
```

See the [CLI reference]({% link manual/cli-reference.md %}) for the full set of commands.

### Web editor workflow

Start the web editor with `proof_frog web [directory]` and open a `.proof` file from the file tree. The toolbar provides **Parse**, **Type Check**, and **Run Proof** buttons that correspond to the CLI's `parse`, `check`, and `prove` commands. A verbosity selector next to the **Run Proof** button lets you choose Quiet, Verbose, or Very Verbose output (matching the CLI's no-flag, `-v`, and `-vv` modes).

When a proof runs, the **Game Hops** panel in the left sidebar lists each step of the `games:` block, color-coded by result. Clicking a step opens a detail view showing the canonical forms of the games on each side of the hop — this is the fastest way to diagnose why a hop succeeds or fails.

See the [Web Editor]({% link manual/web-editor.md %}) page for details on layout, editing features, and limitations.

### Recommended incremental approach

Regardless of which environment you use:

1. Write the `let:`, `assume:`, and `theorem:` blocks first.
2. Add only the first and last game steps (the two sides of the theorem).
3. **Sketch the proof with intermediate games.** Before writing any reductions, it can be helpful to define intermediate games in the helpers section that represent the key waypoints in your proof strategy. Even before these games are connected by verified hops, writing them out forces you to be precise about what each step of the proof looks like and gives you a concrete target for each reduction.
4. Write one reduction and add its corresponding four-step pattern to `games:`.
5. Verify after each addition — run `proof_frog prove` on the CLI or click **Run Proof** in the web editor. Address failures one hop at a time before adding more steps.

For a guided walkthrough of writing a complete proof from scratch, see [Tutorial Part 2]({% link manual/tutorial/otp-ots.md %}).
