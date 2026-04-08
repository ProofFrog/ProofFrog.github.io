---
title: Tutorial Part 1 — Hello Frog
layout: default
parent: Manual
nav_order: 2
---

# Tutorial Part 1 — Hello Frog

In this tutorial you will run your first ProofFrog proof, break it on purpose to see what a failing proof looks like, and fix it again. You will not write any FrogLang yourself — the goal is simply to get comfortable with the tool before writing anything from scratch.

## Prerequisites

You have finished [Installation]({% link manual/installation.md %}). That's it.

## Get the examples

Clone the ProofFrog examples repository:

```bash
git clone https://github.com/ProofFrog/examples
```

This creates an `examples/` directory containing primitives, schemes, games, and proofs from introductory cryptography. The rest of this tutorial assumes you cloned it in your current working directory, so that the path `examples/joy/` exists.

{: .note }
If you do not have git, GitHub's **Code** button on the [examples repository page](https://github.com/ProofFrog/examples) also offers **Download ZIP**.

## Launch the web editor

Start the web editor pointed at the `joy` example set:

```bash
proof_frog web examples/joy
```

ProofFrog starts a local server on port 5173 and opens your browser automatically. You should see a file tree on the left and an editor pane on the right.

<!-- TODO screenshot: web editor on launch -->

## Run a successful proof

In the file tree, open `Proofs/Ch2/OTPSecure.proof`. Click the **Prove** button in the toolbar. After a moment the output panel should turn green and report that the proof succeeded.

<!-- TODO screenshot: green proof output -->

{: .note }
**CLI alternative.** You can prove the same file from the command line:
```bash
proof_frog prove examples/joy/Proofs/Ch2/OTPSecure.proof
```
The web editor and the CLI call the same underlying engine; the two paths produce identical results.

## Break it on purpose

Open `Proofs/Ch2/OTPSecure.proof` in the editor. In the `games:` block, comment out the second line — the one that reads:

```
OneTimeSecrecy(E).Random against OneTimeSecrecy(E).Adversary;
```

Add a `//` at the start so it becomes:

```
// OneTimeSecrecy(E).Random against OneTimeSecrecy(E).Adversary;
```

Click **Prove** again. This time the status badge in the output panel turns red and shows **✗ Failed**, while the body text reports something like:

```
Proof Succeeded, but is incomplete: first and last steps use the same side (Real)
```

ProofFrog is telling you that both endpoints of the game sequence are on the `Real` side of the security property, which means the proof never actually reaches the `Random` side — the chain is broken. (The word "Succeeded" in the message means that all individual hops the engine *did* check passed; "incomplete" is the engine's term for a game sequence that does not connect the two sides of the theorem. The red **✗ Failed** badge is the signal that something is wrong, not the body text.)

<!-- TODO screenshot: red diagnostic -->

## Fix it

Remove the `//` to restore the line, then click **Prove** one more time. The output turns green again. A proof that breaks cleanly under a targeted change and passes once the change is undone is behaving exactly as it should.

## What just happened

ProofFrog checked that each adjacent pair of games in the `games:` sequence is interchangeable — meaning the two games are equivalent under the semantics of FrogLang, as verified by the engine's canonicalization and equivalence-checking machinery. The proof of `OTPSecure` succeeds because the single hop from `Real` to `Random` is one such equivalence: encrypting with OTP produces a uniformly random ciphertext, so the real and random games are indistinguishable. In Part 2 you will write this exact proof from scratch.

## Next

Tutorial Part 2: OTP has one-time secrecy (coming soon).
