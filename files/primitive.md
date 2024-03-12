---
title: Primitive Files
layout: default
parent: Files
nav_order: 1
---

# Primitive Files

One can think of primitives as abstract classes from object oriented programming.
A primitive file allows a user to describe the sets and functions that are associated with a particular mathematical object.
A primitive contains constant fields and method signatures.
An example of a primitive for an abstract symmetric encryption scheme is shown below.

```
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;

    Key KeyGen();
    Ciphertext Enc(Key k, Message m);
    Message Dec(Key k, Ciphertext c);
}
```

It is parameterized by three sets, and "stores" these sets as fields to be used in type-checking later on. It also defines method signatures for key generation, encryption, and decryption.
