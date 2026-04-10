---
title: Schemes
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 4
---

# Schemes
{: .no_toc }

A `.scheme` file defines a *concrete instantiation* of a primitive: it provides implementations for every method declared in the primitive, with matching signatures. Where a [primitive]({% link manual/language-reference/primitives.md %}) is an abstract interface — declaring types and method signatures with no code — a scheme fills in the method bodies and binds abstract sets to concrete types. Schemes can themselves be parameterized over other primitives, which is how generic constructions such as KEMDEM, EncryptThenMAC, and TriplingPRG are expressed. For the full type system and statement forms available in scheme bodies, see the [Basics]({% link manual/language-reference/basics.md %}) page.

- TOC
{:toc}

---

## The `Scheme ... extends` block

A scheme is declared with the `Scheme` keyword, a name, a parameter list, the `extends` keyword naming the primitive it instantiates, and a body:

```prooffrog
import 'relative/path/to/Primitive.primitive';

Scheme Name(parameters) extends PrimitiveName {
    requires expression;             // optional precondition

    Set Field = SomeType;            // type alias (concrete set)
    Int field = expression;          // integer field

    ReturnType MethodName(ParamType param, ...) {
        // method body
    }
}
```

`extends PrimitiveName` links the scheme to the primitive it implements. The scheme must provide a method body for every method declared in that primitive. The `requires` clause and field assignments are optional, and method bodies use the same statement forms described on the [Basics]({% link manual/language-reference/basics.md %}) page.

Imports use paths relative to the directory of the importing file.

---

## Parameter forms

A scheme's parameter list accepts three kinds of parameters, which may be mixed freely in a comma-separated list.

**`Int name`** — an integer parameter, such as a security parameter or bitstring length.

```prooffrog
Scheme OTP(Int lambda) extends SymEnc { ... }
```

**`Set name`** — an abstract set parameter, used when the scheme should remain generic over some type space.

```prooffrog
Scheme SomeScheme(Set MessageSpace) extends SomeInterface { ... }
```

**A primitive instance** — the most powerful form. A scheme can take another primitive as a parameter and call methods on it inside its own method bodies. This is how generic constructions are written.

```prooffrog
Scheme TriplingPRG(PRG G) extends PRG { ... }
```

Here `TriplingPRG` takes a PRG named `G` and itself extends PRG, meaning it is a new PRG built from an underlying one. Inside the scheme's method bodies, calls like `G.evaluate(s)` invoke the underlying PRG. The parameter name (`G`) acts as the instance through which the underlying primitive's methods and fields are accessed.

Multiple parameters of any combination may appear together:

```prooffrog
Scheme KEMDEM(KEM K, SymEnc E) extends PubKeyEnc { ... }
Scheme EncryptThenMAC(SymEnc E, MAC M) extends SymEnc { ... }
```

---

## `requires` clauses

A `requires` clause states a precondition that must hold among the scheme's parameters. It appears immediately after the opening brace, before any field or method declarations:

```prooffrog
Scheme TriplingPRG(PRG G) extends PRG {
    requires G.lambda == G.stretch;
    ...
}
```

The expression may reference any integer fields exposed by the parameter primitives. In the example above, `G.lambda` and `G.stretch` come from the PRG primitive's integer field declarations; the clause asserts that the underlying PRG has equal seed length and stretch length, which the TriplingPRG construction requires in order to apply the underlying PRG twice as intended.

A scheme may have zero or more `requires` clauses. Each clause is checked when the scheme is instantiated in a proof's `let:` block: if the condition does not hold for the supplied parameter values, the proof is rejected at type-checking time.

---

## Field assignments

Inside the scheme body, field declarations bind names to concrete types or integer expressions. These are the same field forms that appear in primitives, but here they are assigned concrete values rather than abstract parameters.

**Set type aliases** bind an abstract set name from the primitive's interface to a concrete type:

```prooffrog
Set Key = BitString<lambda>;
Set Message = BitString<lambda>;
Set Ciphertext = BitString<lambda>;
```

Once defined, `Key`, `Message`, and `Ciphertext` can be used as type names inside the scheme's method bodies. Games and proofs that hold an instance `S` of the scheme can access these as `S.Key`, `S.Message`, and `S.Ciphertext`.

**Integer fields** expose computed quantities derived from parameters:

```prooffrog
Int lambda = G.lambda;
Int stretch = 2 * G.lambda;
```

These are accessible from outside the scheme as `S.lambda` and `S.stretch`, making it possible for games and proofs to reference the scheme's numeric properties without hard-coding them.

For the full range of types available for field assignments (bitstrings, tuples, optional types, and more), see the [Basics]({% link manual/language-reference/basics.md %}) page.

---

## Method bodies

A scheme must implement every method declared in the primitive it extends. Method bodies use ordinary FrogLang statements: variable declarations and assignments, uniform random sampling, conditionals, return statements, and calls to other primitives or other methods on the same scheme. See the [Basics]({% link manual/language-reference/basics.md %}) page for the complete statement reference.

### Calling primitive parameters

Methods on primitive parameters are called with dot notation:

```prooffrog
BitString<2 * lambda> r = G.evaluate(s);
K.SharedSecret ks = K.Encaps(pk)[0];
```

### The `this` keyword

A scheme can call its own other methods using `this.MethodName(args)`. This is useful when one method's implementation builds on another method of the same scheme:

```prooffrog
Scheme Example(Int lambda) extends SomePrimitive {
    SomeType Helper(SomeType x) { ... }

    SomeType Main(SomeType input) {
        SomeType intermediate = this.Helper(input);
        return intermediate;
    }
}
```

During proof verification, `this` references are automatically rewritten to the scheme's instance name (for example, `S.Helper(...)` when the scheme is instantiated as `S` in a proof), so the inliner can resolve the call correctly. You do not need to handle this rewriting manually; it is performed transparently by the engine. The [Canonicalization]({% link manual/canonicalization.md %}) page describes the inlining process in more detail.

---

## The matching-modifier rule

{: .important }
When a scheme `extends` a primitive, the typechecker requires that each method implementation carries *exactly* the same `deterministic` and `injective` modifiers as the corresponding method declaration in the primitive. Adding a modifier that the primitive does not declare, or omitting one that the primitive does declare, is a type error. Return types must also match exactly: `T?` is not accepted in place of `T` or vice versa.

This is a common source of type errors when writing schemes. If the primitive declares:

```prooffrog
deterministic Message? Dec(Key k, Ciphertext c);
```

then the scheme must declare:

```prooffrog
deterministic Message? Dec(Key k, Ciphertext c) { ... }
```

Writing `Message? Dec(...)` (missing `deterministic`) or `deterministic Message Dec(...)` (missing `?`) are both type errors, even though the difference may seem minor. The reason is that the engine relies on these annotations to determine which proof-verification transforms it may apply; a mismatch would make the scheme's behavior inconsistent with what the security games assume about the primitive interface.

See the [Primitives]({% link manual/language-reference/primitives.md %}) page for a full description of the `deterministic` and `injective` modifiers.

---

## Examples

The following examples are drawn from the [Schemes](https://github.com/ProofFrog/examples/tree/main/Schemes) directory in the ProofFrog examples repository.

### OTP — One-Time Pad

[`Schemes/SymEnc/OTP.scheme`](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/OTP.scheme) — the simplest possible symmetric encryption scheme: all three spaces are `BitString<lambda>`, key generation samples a uniform random key, and encryption and decryption are both XOR.

```prooffrog
import '../../Primitives/SymEnc.primitive';

Scheme OTP(Int lambda) extends SymEnc {
    Set Key = BitString<lambda>;
    Set Message = BitString<lambda>;
    Set Ciphertext = BitString<lambda>;

    Key KeyGen() {
        Key k <- Key;
        return k;
    }

    Ciphertext Enc(Key k, Message m) {
        return k + m;
    }

    deterministic Message? Dec(Key k, Ciphertext c) {
        return k + c;
    }
}
```

Note that `Dec` carries the `deterministic` modifier and returns `Message?`, matching the SymEnc primitive's declaration exactly.

### TriplingPRG — Generic PRG Construction

[`Schemes/PRG/TriplingPRG.scheme`](https://github.com/ProofFrog/examples/blob/main/Schemes/PRG/TriplingPRG.scheme) — a generic construction that takes a PRG as a parameter and produces a PRG with twice the stretch. It uses a `requires` clause, integer field assignments, and calls the underlying PRG twice.

```prooffrog
import '../../Primitives/PRG.primitive';

Scheme TriplingPRG(PRG G) extends PRG {
    requires G.lambda == G.stretch;

    Int lambda = G.lambda;
    Int stretch = 2 * G.lambda;

    deterministic BitString<lambda + stretch> evaluate(BitString<lambda> s) {
        BitString<2 * lambda> result1 = G.evaluate(s);
        BitString<lambda> x = result1[0 : lambda];
        BitString<lambda> y = result1[lambda : 2*lambda];
        BitString<2 * lambda> result2 = G.evaluate(y);

        return x || result2;
    }
}
```

The `requires` clause enforces that the underlying PRG's seed length equals its stretch, which the construction relies on to feed the second half of the first PRG output back as a seed to the second PRG call. Integer fields `lambda` and `stretch` expose the new PRG's parameters so that games and proofs can reference `T.lambda` and `T.stretch` for a `TriplingPRG` instance `T`.

### EncryptThenMAC — Two-Primitive Generic Construction

[`Schemes/SymEnc/EncryptThenMAC.scheme`](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/EncryptThenMAC.scheme) — a generic authenticated encryption scheme that takes a symmetric encryption scheme and a MAC as parameters. It shows a `requires` clause relating sets from two different primitive parameters, tuple types for key and ciphertext, and method bodies that call into two distinct primitive instances.

```prooffrog
import '../../Primitives/SymEnc.primitive';
import '../../Primitives/MAC.primitive';

Scheme EncryptThenMAC(SymEnc E, MAC M) extends SymEnc {
    requires E.Ciphertext subsets M.Message;

    Set Key = [E.Key, M.Key];
    Set Message = E.Message;
    Set Ciphertext = [E.Ciphertext, M.Tag];

    Key KeyGen() {
        E.Key ke = E.KeyGen();
        M.Key me = M.KeyGen();
        return [ke, me];
    }

    Ciphertext Enc(Key k, Message m) {
        E.Ciphertext c = E.Enc(k[0], m);
        M.Tag t = M.MAC(k[1], c);
        return [c, t];
    }

    deterministic Message? Dec(Key k, Ciphertext c) {
        if (c[1] != M.MAC(k[1], c[0])) {
            return None;
        }
        return E.Dec(k[0], c[0]);
    }
}
```

The key is a tuple `[E.Key, M.Key]` and the ciphertext is a tuple `[E.Ciphertext, M.Tag]`. The `requires` clause ensures that the symmetric ciphertext space is a subset of the MAC message space, as required by the Encrypt-then-MAC construction. Tuple element access (`k[0]`, `k[1]`, `c[0]`, `c[1]`) is used throughout to unpack the compound types.

### KEM-DEM — Hybrid Public-Key Encryption

[`Schemes/PubEnc/KEMDEM.scheme`](https://github.com/ProofFrog/examples/blob/main/Schemes/PubEnc/KEMDEM.scheme) — a hybrid public-key encryption scheme that combines a key encapsulation mechanism with a symmetric encryption scheme.

```prooffrog
import '../../Primitives/KEM.primitive';
import '../../Primitives/NonNullableSymEnc.primitive';
import '../../Primitives/PubKeyEnc.primitive';

Scheme KEMDEM(KEM K, SymEnc E) extends PubKeyEnc {
    requires K.SharedSecret subsets E.Key;

    Set Message = E.Message;
    Set Ciphertext = [K.Ciphertext, E.Ciphertext];
    Set PublicKey = K.PublicKey;
    Set SecretKey = K.SecretKey;

    [PublicKey, SecretKey] KeyGen() {
        return K.KeyGen();
    }

    Ciphertext Enc(PublicKey pk, Message m) {
        [K.SharedSecret, K.Ciphertext] x = K.Encaps(pk);
        E.Key k_sym = x[0];
        K.Ciphertext c_kem = x[1];
        E.Ciphertext c_sym = E.Enc(k_sym, m);
        return [c_kem, c_sym];
    }

    deterministic Message? Dec(SecretKey sk, Ciphertext c) {
        K.Ciphertext c_kem = c[0];
        E.Ciphertext c_sym = c[1];
        K.SharedSecret k_sym = K.Decaps(sk, c_kem);
        return E.Dec(k_sym, c_sym);
    }
}
```

The `requires` clause checks that the KEM's shared secret space is a subset of the symmetric encryption key space, ensuring the shared secret can be used directly as a symmetric key. The `KeyGen` method simply delegates to the KEM's key generation. `Enc` calls `K.Encaps` to obtain a shared secret and a KEM ciphertext, then uses the shared secret as the symmetric key to encrypt the message.
