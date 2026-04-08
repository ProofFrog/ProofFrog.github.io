---
title: Vibe-coding a proof
layout: default
parent: HACS 2026 Updates
has_children: true
has_toc: false
nav_order: 1
redirect_from:
  - /hacs-2026/vibe
  - /hacs-2026/vibe/
  - /hacs-2026/vibe/index.html
---

# Vibe-coding a proof

Claude Code (Opus 4.6) was able to construct a valid ProofFrog scheme file and proof from a natural language input describing the scheme and the idea of each game hop. The runtime was about 5 minutes.

**Input:** 
- [Prompt](prompt.html)

**Outputs:**

- [Scheme](scheme.html)
- [Proof](proof.html)
- [Transcript of Claude's session](transcript/index.html){:target="_blank"}

## MCP server

ProofFrog now provides a [Model Context Protocol](https://en.wikipedia.org/wiki/Model_Context_Protocol){:target="_blank"} server, which enables large language models to interact with external tools. The ProofFrog MCP allows the agent to interact with the proof engine in a structured way, and obtain details about each step of the proof.

See [CLAUDE_MCP.md](https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE_MCP.md) for the description of the MCP server. (Note that the target audience of the file is the LLM.)

If you would like to use the MCP server to help you write a proof in ProofFrog, here is a rough guide to doing so with Claude Code in VS Code (that at least worked on my macOS computer):

1. Install ProofFrog with the MCP option: 
   
   ```txt
   cd /path/to/working/directory # whatever directory you choose
   python3 -m venv .venv
   source .venv/bin/activate
   pip install proof_frog[mcp]
   ```

2. Clone the examples repository so that the ProofFrog MCP server has some good examples to feed to Claude:

   ```txt
   cd /path/to/working/directory
   git clone https://github.com/ProofFrog/examples
   ```

3. Load the ProofFrog MCP server into the Claude command-line interface:

   ```txt
   # You need to have `claude` available in your command-line environment
   # To install on macOS with brew: `brew install claude-code`
   claude mcp add prooffrog /path/to/working/directory/.venv/bin/python -- -m proof_frog mcp /path/to/working/directory/examples
   ```

4. Download the following two files to help Claude understand ProofFrog and how to use the MCP server:

   ```txt
   curl -O https://raw.githubusercontent.com/ProofFrog/ProofFrog/refs/heads/main/CLAUDE.md
   curl -O https://raw.githubusercontent.com/ProofFrog/ProofFrog/refs/heads/main/CLAUDE_MCP.md
   ```

5. In Claude Code inside VS Code, type `/mcp` and you should see "prooffrog: Connected". If it does not appear, try restarting VS Code or reloading the window by typing `CMD-Shift-P` then `Developer: Reload Window`.

You should now be able to get Claude Code to help write ProofFrog files, and it will use the MCP interface to help itself write and check things.
