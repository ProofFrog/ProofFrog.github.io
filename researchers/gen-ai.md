---
title: "Gen AI & Proving"
layout: default
parent: For Researchers
nav_order: 4
---

# Gen AI & Proving
{: .no_toc }

It is possible to have an LLM-based coding agent, such as Claude Code, interact with ProofFrog to draft, debug, and iterate on ProofFrog proofs. 

If you are new to game-hopping proofs, please first focus on the [tutorial]({% link manual/tutorial/index.md %}) and [worked examples]({% link manual/worked-examples/index.md %}) and then try writing a proof on your own. Come back to this page once you have a baseline intuition for what a valid reduction looks like.

- TOC
{:toc}

---

## Setup

The key tool for a coding agent to interact with a tool like ProofFrog is an MCP (Model Context Protocol) server.

### Installing the MCP server

The MCP server ships as part of ProofFrog. Install ProofFrog with the MCP extra:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install proof_frog[mcp]
```

(The rest of this document assumes that you ran the above commands in the directory `/path/to/working/directory`)

To give the server a useful set of examples to draw on, clone the examples repository into the same working directory before continuing:

```
git clone https://github.com/ProofFrog/examples
```

Download the following guidance file from the ProofFrog repository into your working directory so that your coding agent can read it at the start of a session to get some hints on how to use the MCP server:

```
curl -O https://raw.githubusercontent.com/ProofFrog/ProofFrog/refs/heads/main/CLAUDE_MCP.md
```

### Configuring Claude Code

Next you need to register the ProofFrog MCP server with your coding agent.  For Claude Code:

```bash
claude mcp add prooffrog /path/to/working/directory/.venv/bin/python -- -m proof_frog mcp /path/to/working/directory/examples
```

Alternatively, add the server directly to `.claude/settings.json` in your working directory:

```json
{
  "mcpServers": {
    "prooffrog": {
      "command": "python",
      "args": ["-m", "proof_frog", "mcp", "/path/to/working/directory/examples/"],
      "cwd": "/path/to/working/directory"
    }
  }
}
```

After registering, type `/mcp` inside Claude Code to confirm the server appears as connected. If it does not appear, reload the window (in VS Code: `CMD-Shift-P`, then `Developer: Reload Window`).

### What the MCP server exposes

The MCP server exposes the main ProofFrog commands (`parse`, `check`, `prove`) to the coding agent, along with several extra commands that allow it to inspect the game hop canonicalization in greater detail to diagnose bugs.  The full list of commands is available in []`CLAUDE_MCP.md` in the ProofFrog repository](https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE_MCP.md). Some of the extra commands available include:

- **`get_step_detail`** -- returns the canonical (fully simplified) form of one proof step by index. This is the primary diagnostic tool for a failing hop: compare the canonical forms of two adjacent steps to see exactly what differs. Read the `canonical` field, not `output` (which contains mangled internal names).
- **`get_inlined_game`** -- returns the canonical form of an arbitrary game step expression without requiring the step to appear in the proof's `games:` list, and robust to stub reductions that would otherwise block verification. Use this when writing intermediate games: it shows exactly what a game looks like after inlining against the proof's `let:`/`assume:` context, so you can write a matching `Game` definition.
- **`get_canonicalization_trace`** -- returns a trace of which transforms fired at each fixed-point iteration. Use this to understand how the engine simplifies a specific step.
- **`get_step_after_transform`** -- returns the game AST after applying transforms up to a named transform. Useful for inspecting intermediate states in the canonicalization pipeline.

---

## What works well

Take a look at the [HACS 2026 demo](({% link researchers/publications/hacs-2026/vibe/index.md %})) to see an example: from an English language prompt outlining a basic scheme (symmetric encryption build from a PRG), Claude Code was able to produce a working scheme and proof in roughly five minutes of wall time. That is a useful data point, but the task was chosen to be representative of examples already in the repository -- not a stress test. 

With that context, here are some things that can work okay:

**Drafting primitives, schemes, and games from a natural-language specification.** A plain-English description of a scheme -- "encrypt by XOR with a keystream derived from a PRG applied to the key XOR'd with a fresh nonce" -- can produce a usable first draft in one request. The LLM can learn the FrogLang syntax well enough (from `CLAUDE_MCP.md` and the examples directory) to get the types, method signatures, and import paths approximately right. Its use of the MCP server to check its work lets it correct mistakes. Expect to correct minor issues (wrong field name, off-by-one slice boundary) but not to rewrite from scratch.

**Writing reductions when the game structure is explicit.** Tell the model which assumption to reduce to and what the intermediate game looks like -- "this reduction should compose with `OTPUniform(lambda)` and its `Eavesdrop` oracle should call `challenger.CTXT(r)` to get either `k + r` or a uniform string" -- and it can usually produce a syntactically valid reduction. Sometimes it can figure out the hops on its own, but the more concrete the description of the game hop, the better the output.

**Short iteration loops using `get_step_detail` and `get_inlined_game`.** The effective pattern is: ask the model to draft a game or reduction, call `prove` to check which steps fail, call `get_step_detail` (or `get_inlined_game` if the proof is not yet parseable) to retrieve the canonical form, feed that canonical form back into the conversation, and ask the model to adjust. Each iteration is fast, and the model is good at reading a canonical form and identifying what changed.

**Symmetric proofs.** The HACS 2026 proof has a left half and a right half that mirror each other. Once the left half is working, you can ask the model to mirror it for the right side.

---

## What does not

**The LLM will produce reductions that almost work.** Same structure, wrong detail -- a `mL` where there should be a `mR`, a missing oracle parameter, a slice with the wrong bounds. The model cannot tell whether a reduction is correct without running the engine. Do not accept a reduction as complete until `prove` returns `"success": true` for that step. The model may claim success based on the shape of the code without having run the engine; verify independently.

**Without iteration, the model drifts out of scope.** In a single long prompt with no intermediate engine feedback, the LLM may introduce primitives it was not asked for, invent security definitions that do not match the one specified, or write a proof structure that does not correspond to the game sequence described. Short requests with tight scope -- one game, one reduction at a time -- produce better results than large upfront requests.

**Hallucinated helper games.** The LLM may confidently cite `Games/Misc/BitStringSampling.game` or similar file paths for helper assumptions that do not exist in the current repository. Before accepting a proof that imports an unusual game file, verify the file is present using `list_files`. See the [Canonicalization]({% link manual/canonicalization.md %}) page for the current catalogue of helper games and statistical assumptions.

**The LLM will occasionally invoke the engine, see a failure, and announce success anyway.** This is the most dangerous failure mode. The model may misread the `hop_results` list from `prove`, report the wrong step as passing, or summarize a partial success as a full one. Always check the raw engine output the model is quoting. If you are running the session yourself, verify the final state by calling `prove` directly and reading `success` from the response, not from the model's summary of it.

---

## Soundness considerations

The observations in the [Soundness]({% link researchers/soundness.md %}) page apply to any proof that ProofFrog checks, regardless of whether the proof was developed manually or with generative AI tools.

In some sense, LLM-generated proofs warrant *more* manual inspection, because the author (the LLM) cannot explain its own reasoning when asked. A human who wrote a proof can describe what changed in each hop and why it is valid; an LLM that generated a proof can narrate the hop but does not have the same reasoning as a human.

When reviewing ProofFrog files generated by an LLM, pay extra attention to the scheme specification and the security properties.  Is this the scheme you actually wanted to analyze?  Is the security property actually the security property you care about?  If the LLM generated additional security assumptions to bridge a step, are those assumptions reasonable?

---

## Pointers

- [HACS 2026 vibe-coding demo]({% link researchers/publications/hacs-2026/vibe/index.md %}) -- the original event handout this page is derived from, including full configuration instructions and the recorded transcript.
  - [Prompt]({% link researchers/publications/hacs-2026/vibe/prompt.md %}) -- the exact prompt used in the HACS 2026 demo. The scheme is `FunkyPRGSymEnc`, a PRG-based symmetric encryption scheme with a nonce; the proof establishes `OneTimeSecrecy` using `PRG.Security` and `OTPUniform`. (Note that engine improvements since then have rendered the `OTPUniform` assumption unnecessary.)
  - [Generated scheme]({% link researchers/publications/hacs-2026/vibe/scheme.md %}) -- the scheme file the LLM produced.
  - [Generated proof]({% link researchers/publications/hacs-2026/vibe/proof.md %}) -- the proof file the LLM produced. Seven game hops; the proof is symmetric, with the left and right halves mirroring each other.
  - [Session transcript]({% link researchers/publications/hacs-2026/vibe/transcript.md %}) -- the full Claude Code session from the HACS 2026 demo.
- [`CLAUDE_MCP.md`](https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE_MCP.md) in the ProofFrog repository -- the current best-practice guides for LLM clients.