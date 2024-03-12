---
title: Scheme Files
layout: default
parent: Files
nav_order: 2
---

# Scheme Files

One can think of schemes as concrete classes from object oriented programming.
Each scheme file provides one scheme which "extends" from a primitive.
A scheme must define the same fields as the primitive it extends, and provide definitions for each primitive method signature.
An example of a scheme for a symmetric encryption scheme composed from two other symmeteric encryption schemes is shown below.

```
import 'examples/Primitives/SymEnc.primitive';

Scheme DoubleSymEnc(SymEnc S, SymEnc T) extends SymEnc {
    requires S.Ciphertext == T.Message;

    Set Message = S.Message;
    Set Ciphertext = T.Ciphertext;
    Set Key = S.Key * T.Key;

    Key KeyGen() {
        S.Key key1 = S.KeyGen();
        T.Key key2 = T.KeyGen();
        return [key1, key2];
    }

    Ciphertext Enc(Key k, Message m) {
        S.Ciphertext c1 = S.Enc(k[0], m);
        T.Ciphertext c2 = T.Enc(k[1], c1);
        return c2;
    }

    Message Dec(Ciphertext c) {
    	S.Ciphertext c2 = T.Dec(k[1], c);
    	S.Message m = S.Dec(k[0], c2);
    	return m;
    }
}
```

The SymEnc primitive is referenced via the import statement.
Schemes may also use a `requires` syntax to place bounds on the parameterization via some boolean expression.
We can see that we define the fields as appropriate for this scheme and also define method definitions for `KeyGen`, `Enc`, and `Dec` that just compose the previous two method definitions.
