---
title: "Input: Prompt"
layout: default
parent: Vibe-coding a proof
nav_order: 1
redirect_from:
  - /hacs-2026/vibe/prompt
  - /hacs-2026/vibe/prompt.html
---

# Input: Prompt

Here is the prompt that was input to Claude Code (Opus 4.6):

```txt
Create a scheme file for a symmetric encryption scheme called 
FunkyPRGSymEnc where the messages are bitstrings of length 
2 * lambda, the key is a bitstring of length lambda, G is a PRG, 
and the encryption function is:
    sample r <- bitstrings of length lambda, 
    compute z = G(k + r), 
    return r || (z + m)

Create a proof for a theorem that FunkyPRGSymEnc satisfies the 
OneTimeSecrecy security property. The only security assumptions 
we should need to use are the PRG security assumption and the 
OTPUniform assumption. The outline of the proof is as follows:

- Hop to a game in which the Eavesdrop oracle evaluates G on k, 
  not k + r. This hop should work because k + r is effectively 
  a one-time pad encryption of r, so it looks uniform.
- Hop to a game in which the Eavesdrop oracle returns 
  r || (z + mL), where z is a randomly sampled bitstring. This 
  hop should be based on a reduction to security of the PRG.
- Hop to a game where the Eavesdrop oracle returns r || z, 
  where z is a randomly sampled bitstring, again based on 
  one-time pad.
- The second half of the proof is a mirror of the first half, 
  gradually reintroducing mR and G.
```

> This is a bit of a silly scheme, in the sense that the nonce r is pointless. The reason this example was used was to do an example roughly on the same level of difficulty as examples already in the examples directory, but technically distinct from the worked examples that are already in the repository.
{: .note }
