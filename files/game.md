---
title: Game Files
layout: default
parent: Files
nav_order: 3
---

# Game Files

Game files allow the user to specify security definitions in the form of a pair of games that must be proved indistinguishable.
Each function listed in a game is provided implicitly to the adversary in the form of an oracle.
Games may also contain private state that is maintained between oracle calls.
Finally, each game has the option to specify an `Initialize` method which is assumed to be implicitly called before the adversary program starts.
`Initialize` also has the ability to return information to the adversary that they may use during the attack (for example, adversaries should be provided the public key when attacking public key encryption).
An example of a game file defining CPA security for symmetric encryption schemes is provided below.

```
import 'examples/Primitives/SymEnc.primitive';

Game Left(SymEnc E) {
    E.Key k;
    Void Initialize() {
        k = E.KeyGen();
    }
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        return E.Enc(k, mL);
    }
}

Game Right(SymEnc E) {
    E.Key k;
    Void Initialize() {
        k = E.KeyGen();
    }
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        return E.Enc(k, mR);
    }
}

export as CPA;
```
In a proof file, we can then reference these two games by writing `CPA(E).Left` and `CPA(E).Right`.
