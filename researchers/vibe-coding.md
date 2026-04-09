---
title: Vibe-Coding
layout: default
parent: For Researchers
nav_order: 4
---

# Vibe-Coding

## Read this first

**Vibe-coding** is using an LLM-based coding assistant to draft, debug, and iterate on ProofFrog proofs. This page is in the For Researchers section because it is a research-and-experimentation tool, not a recommended workflow for students learning provable security. If you are new to game-hopping proofs, learn to write them by hand first: start with [Tutorial Part 1]({% link manual/tutorial/hello-frog.md %}), work through the [language reference]({% link manual/language-reference/index.md %}), and then try writing a proof on your own. Come back to this page once you have a baseline intuition for what a valid reduction looks like.

The rest of this page covers: how to configure the ProofFrog MCP server and Claude Code, what kinds of tasks the LLM handles well, where it fails, and what vibe-coding does and does not change about the soundness of a proof. Pointers to the original HACS 2026 demo artifacts appear at the end.

---

## Setup

### Installing the MCP server

The MCP server ships as part of ProofFrog. Install ProofFrog with the MCP extra:

```
python3 -m venv .venv
source .venv/bin/activate
pip install proof_frog[mcp]
```

Once installed, `proof_frog mcp` launches the server. It takes one argument: the directory of ProofFrog files (primitives, games, schemes, and examples) that the server should have access to. The server process communicates over stdio and is designed to be registered with an MCP-capable client.

To give the server a useful set of examples to draw on, clone the examples repository into the same working directory before launching:

```
git clone https://github.com/ProofFrog/examples
```

The [Engine Internals]({% link researchers/engine-internals.md %}) page covers the server architecture in more detail. The source is in `proof_frog/mcp_server.py` in the ProofFrog repository.

### Configuring Claude Code

The configuration used for the HACS 2026 demo registers the MCP server with Claude Code's `claude mcp add` command:

```
claude mcp add prooffrog /path/to/.venv/bin/python -- -m proof_frog mcp /path/to/examples
```

Alternatively, add the server directly to `.claude/settings.json` in your working directory:

```json
{
  "mcpServers": {
    "prooffrog": {
      "command": "python",
      "args": ["-m", "proof_frog", "mcp", "examples/"],
      "cwd": "/path/to/working/directory"
    }
  }
}
```

After registering, type `/mcp` inside Claude Code to confirm the server appears as connected. If it does not appear, reload the window (in VS Code: `CMD-Shift-P`, then `Developer: Reload Window`).

Download the two guidance files from the ProofFrog repository into your working directory so Claude Code can read them at the start of a session:

```
curl -O https://raw.githubusercontent.com/ProofFrog/ProofFrog/refs/heads/main/CLAUDE.md
curl -O https://raw.githubusercontent.com/ProofFrog/ProofFrog/refs/heads/main/CLAUDE_MCP.md
```

See the [HACS 2026 vibe-coding demo]({% link researchers/presentations/hacs-2026/vibe/index.md %}) for the full step-by-step configuration guide used at the workshop.

### What the MCP server exposes

The server provides the following tools. The authoritative description is in `CLAUDE_MCP.md` in the ProofFrog repository (the file is written for the LLM, not for humans, but it is accurate and complete).

- **`version`** -- returns the installed ProofFrog version.
- **`list_files`** -- lists the ProofFrog files (`.primitive`, `.scheme`, `.game`, `.proof`) in a directory tree.
- **`read_file`** -- reads a ProofFrog file by path.
- **`write_file`** -- creates or overwrites a ProofFrog file.
- **`describe`** -- returns a concise interface summary (exported name, parameters, fields, method signatures) for a `.primitive`, `.scheme`, `.game`, or `.proof` file, without method bodies. Shorter than reading the raw file; useful for quickly checking what a primitive provides.
- **`parse`** -- parses a ProofFrog file and returns the AST. Checks syntax only.
- **`check`** -- runs semantic type-checking. Catches type mismatches, undefined names, and signature mismatches that parse alone does not catch.
- **`prove`** -- runs full proof verification on a `.proof` file. Returns per-hop results, including a `failure_detail` field for each failing step.
- **`get_step_detail`** -- returns the canonical (fully simplified) form of one proof step by index. This is the primary diagnostic tool for a failing hop: compare the canonical forms of two adjacent steps to see exactly what differs. Read the `canonical` field, not `output` (which contains mangled internal names).
- **`get_inlined_game`** -- returns the canonical form of an arbitrary game step expression without requiring the step to appear in the proof's `games:` list, and robust to stub reductions that would otherwise block verification. Use this when writing intermediate games: it shows exactly what a game looks like after inlining against the proof's `let:`/`assume:` context, so you can write a matching `Game` definition.
- **`get_canonicalization_trace`** -- returns a trace of which transforms fired at each fixed-point iteration. Use this to understand how the engine simplifies a specific step.
- **`get_step_after_transform`** -- returns the game AST after applying transforms up to a named transform. Useful for inspecting intermediate states in the canonicalization pipeline.

---

## What works well

The HACS 2026 demo (see the [session transcript]({% link researchers/presentations/hacs-2026/vibe/transcript.md %})) produced a working scheme and proof in roughly five minutes of wall time. That is a useful data point, but the task was chosen to be representative of examples already in the repository -- not an adversarial stress test. With that context, here is what works reliably.

**Drafting primitives, schemes, and games from a natural-language specification.** A plain-English description of a scheme -- "encrypt by XOR with a keystream derived from a PRG applied to the key XOR'd with a fresh nonce" -- can produce a usable first draft in one request. The LLM knows the FrogLang syntax well enough (from `CLAUDE.md` and the examples it can list via `list_files`) to get the types, method signatures, and import paths approximately right. Expect to correct minor issues (wrong field name, off-by-one slice boundary) but not to rewrite from scratch.

**Writing reductions when the game structure is explicit.** Tell the model which assumption to reduce to and what the intermediate game looks like -- "this reduction should compose with `OTPUniform(lambda)` and its `Eavesdrop` oracle should call `challenger.CTXT(r)` to get either `k + r` or a uniform string" -- and it can usually produce a syntactically valid reduction. The more concrete the description of the game hop, the better the output.

**Short iteration loops using `get_step_detail` and `get_inlined_game`.** The effective pattern is: ask the model to draft a game or reduction, call `prove` to check which steps fail, call `get_step_detail` (or `get_inlined_game` if the proof is not yet parseable) to retrieve the canonical form, feed that canonical form back into the conversation, and ask the model to adjust. Each iteration is fast, and the model is good at reading a canonical form and identifying what changed. Three to five iterations is typical for a moderately complex hop.

**Symmetric proofs.** The HACS 2026 proof has a left half and a right half that mirror each other. Once the left half is working, asking the model to mirror it for the right side works well and is faster than the initial construction.

---

## What does not

**The LLM will produce reductions that almost work.** Same structure, wrong detail -- a `mL` where there should be a `mR`, a missing oracle parameter, a slice with the wrong bounds. The model cannot tell whether a reduction is correct without running the engine. Do not accept a reduction as complete until `prove` returns `"success": true` for that step. The model may claim success based on the shape of the code without having run the engine; verify independently.

**Without iteration, the model drifts out of scope.** In a single long prompt with no intermediate engine feedback, the LLM may introduce primitives it was not asked for, invent security definitions that do not match the one specified, or write a proof structure that does not correspond to the game sequence described. Short requests with tight scope -- one game, one reduction at a time -- produce better results than large upfront requests.

**Hallucinated helper games.** The LLM may confidently cite `Games/Misc/BitStringSampling.game` or similar file paths for helper assumptions that do not exist in the current repository. Before accepting a proof that imports an unusual game file, verify the file is present using `list_files`. See the [Canonicalization]({% link manual/canonicalization.md %}) page for the current catalogue of helper games and statistical assumptions.

**The LLM will occasionally invoke the engine, see a failure, and announce success anyway.** This is the most dangerous failure mode. The model may misread the `hop_results` list from `prove`, report the wrong step as passing, or summarize a partial success as a full one. Always check the raw engine output the model is quoting. If you are running the session yourself, verify the final state by calling `prove` directly and reading `success` from the response, not from the model's summary of it.

---

## Soundness considerations

Vibe-coding does not lower the trust requirements on a proof. An LLM-generated proof that the engine accepts is exactly as trustworthy as a hand-written proof that the engine accepts -- and exactly as untrustworthy. The [Soundness]({% link researchers/soundness.md %}) page applies without modification. In particular, ProofFrog has no formal soundness proof, so a vibe-coded validation is evidence of correctness, not a certificate. If anything, LLM-generated proofs warrant *more* manual inspection, because the author (the LLM) cannot explain its own reasoning when asked. A human who wrote a proof can describe what changed in each hop and why it is valid; an LLM that generated a proof can narrate the hop but cannot reliably distinguish between a hop that works because the reduction is correct and a hop that works because the engine failed to find a counterexample.

---

## Pointers

- [HACS 2026 vibe-coding demo]({% link researchers/presentations/hacs-2026/vibe/index.md %}) -- the original event handout this page is derived from, including full configuration instructions and the recorded transcript.
- [Prompt]({% link researchers/presentations/hacs-2026/vibe/prompt.md %}) -- the exact prompt used in the HACS 2026 demo. The scheme is `FunkyPRGSymEnc`, a PRG-based symmetric encryption scheme with a nonce; the proof establishes `OneTimeSecrecy` using `PRG.Security` and `OTPUniform`.
- [Generated scheme]({% link researchers/presentations/hacs-2026/vibe/scheme.md %}) -- the scheme file the LLM produced.
- [Generated proof]({% link researchers/presentations/hacs-2026/vibe/proof.md %}) -- the proof file the LLM produced. Seven game hops; the proof is symmetric, with the left and right halves mirroring each other.
- [Session transcript]({% link researchers/presentations/hacs-2026/vibe/transcript.md %}) -- the full Claude Code session from the HACS 2026 demo.
- `CLAUDE.md` and `CLAUDE_MCP.md` in the ProofFrog repository -- the current best-practice guides for LLM clients. `CLAUDE.md` covers ProofFrog architecture, FrogLang conventions, and proof-writing discipline. `CLAUDE_MCP.md` is written for the LLM and documents each MCP tool with examples. These are not Jekyll pages; access them directly from the repository at `https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE.md` and `https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE_MCP.md`, or download them locally as described in the Setup section above.
