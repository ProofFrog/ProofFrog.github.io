---
title: Proof Files
layout: default
parent: Files
nav_order: 4
---

# Proof Files

Proof files allow the user to specify any reductions or intermediate games that may be used in the proof, after which the user must define statements in four sections: the `let` section, the `assume` section, the `theorem` section, and a sequence of games.
The `let` section details the variables, primitives, and schemes to be used in the assumptions, theorem, and proof.
The `assume` section allows the user to specify indistinguishability assumptions for schemes defined in the `let` section.
The `theorem` section states which security definition is going to be proved for which scheme.
Finally, the `games` section lists a sequence of games, starting with one of the games from the pair specified in the theorem and ending with the other game.
Each game in the sequence is checked to be either interchangeable with the next game, or to be indistinguishable with the next game.
Indistinguishability only occurs if the author writes a reduction to utilize a previously specified indistinguishability assumption.
An example proof file is shown below, which ProofFrog can verify to show that CPA$ security for a symmetric encryption scheme implies CPA security.

```
import 'examples/Primitives/SymEnc.primitive';
import 'examples/Games/SymEnc/CPA.game';
import 'examples/Games/SymEnc/CPA$.game';

Reduction R1(SymEnc E) compose CPA$(E) against CPA(E).Adversary {
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        return challenger.CTXT(mL);
    }
}

Reduction R2(SymEnc E) compose CPA$(E) against CPA(E).Adversary {
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        return challenger.CTXT(mR);
    }
}

proof:

let:
    Set MessageSpace;
    Set CiphertextSpace;
    Set KeySpace;
    SymEnc E = SymEnc(MessageSpace, CiphertextSpace, KeySpace);

assume:
    CPA$(E);

theorem:
    CPA(E);

games:
    CPA(E).Left against CPA(E).Adversary;
    CPA$(E).Real compose R1(E) against CPA(E).Adversary;
    CPA$(E).Random compose R1(E) against CPA(E).Adversary;
    CPA$(E).Random compose R2(E) against CPA(E).Adversary;
    CPA$(E).Real compose R2(E) against CPA(E).Adversary;
    CPA(E).Right against CPA(E).Adversary;
```
