---
title: Publications
layout: default
parent: For Researchers
nav_order: 6
---

# Publications

Papers, theses, and event material related to ProofFrog. For curated case studies of external projects using ProofFrog, see [External Uses]({% link researchers/external-uses.md %}).

## Papers and theses

- **Ross Evans.** *ProofFrog: A Tool for Verifying Game-Hopping Cryptographic Proofs.* Master's thesis, University of Waterloo, 2024. [UWSpace record](https://hdl.handle.net/10012/20441) ([PDF](https://uwspace.uwaterloo.ca/bitstream/handle/10012/20441/Evans_Ross.pdf)).

- **Ross Evans, Matthew McKague, Douglas Stebila.** *ProofFrog: A Tool For Verifying Transitions in Game-Hopping Proofs.* Cryptology ePrint Archive, Paper 2025/418, 2025. [eprint.iacr.org/2025/418](https://eprint.iacr.org/2025/418).

## Talks and workshops

- **HACS 2024** — High Assurance Cryptographic Software workshop. See [HACS 2024 page]({% link researchers/presentations/hacs-2024.md %}) for slides and notes.
- **CAPS 2025** — Computer-Aided Proofs of Security workshop. See [CAPS 2025 page]({% link researchers/presentations/caps-2025.md %}).
- **HACS 2026** — High Assurance Cryptographic Software workshop, including a vibe-coding demo with Claude Code. See [HACS 2026 page]({% link researchers/presentations/hacs-2026/index.md %}) and the [vibe-coding writeup]({% link researchers/vibe-coding.md %}).

## How to cite ProofFrog

Until a peer-reviewed venue version appears, the recommended form is to cite the eprint:

{% raw %}
```bibtex
@misc{cryptoeprint:2025/418,
    author = {Ross Evans and Matthew McKague and Douglas Stebila},
    title  = {{ProofFrog}: A Tool For Verifying Transitions in Game-Hopping Proofs},
    howpublished = {Cryptology {ePrint} Archive, Paper 2025/418},
    year = {2025},
    url  = {https://eprint.iacr.org/2025/418}
}
```
{% endraw %}

The Evans thesis can be cited as:

{% raw %}
```bibtex
@phdthesis{evans2024prooffrog,
    author = {Ross Evans},
    title  = {{ProofFrog}: A Tool for Verifying Game-Hopping Cryptographic Proofs},
    school = {University of Waterloo},
    year   = {2024},
    type   = {Master's thesis},
    url    = {https://hdl.handle.net/10012/20441}
}
```
{% endraw %}

When citing the implementation directly, also link the GitHub repository: `https://github.com/ProofFrog/ProofFrog`.
