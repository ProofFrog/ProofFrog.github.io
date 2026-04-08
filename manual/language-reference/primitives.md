---
title: Primitives
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 3
---

# Primitives

## Overview

A `.primitive` file defines an *abstract cryptographic interface*: the named sets and method signatures that characterize a cryptographic operation, with no implementations. Primitives capture what a scheme *is* — its types and its calling contract — but say nothing about how it works internally. Concrete instantiations are provided by schemes (covered on the Schemes page). For the full type system available in primitives, see the [Basics]({% link manual/language-reference/basics.md %}) page. For an explanation of how oracle calls made to primitive methods behave at runtime during game evaluation, see the [Execution Model]({% link manual/language-reference/execution-model.md %}) page.

---

## The `Primitive` block

A primitive is declared with the `Primitive` keyword, a name, a parameter list, and a body containing field declarations and method signatures:

```prooffrog
Primitive Name(param1, param2, ...) {
    // Field declarations (type aliases exposed to the outside world)
    Set FieldName = paramOrExpr;
    Int intField = paramOrExpr;

    // Method signatures (no bodies)
    ReturnType MethodName(ParamType param, ...);
    deterministic ReturnType DetMethod(ParamType param, ...);
    deterministic injective ReturnType InjMethod(ParamType param, ...);
}
```

The parameter list specifies what must be provided to instantiate the primitive. The body consists of field declarations (which bind names to types or values) and method signatures (which declare what methods exist and their types, without any implementation). Method bodies are absent by design: a primitive is an interface, not code.

---

## Parameter forms

A primitive's parameter list may contain any combination of the following:

**`Int name`** — an integer parameter, used for security parameters, key lengths, or output lengths.

```prooffrog
Primitive PRG(Int lambda, Int stretch) { ... }
```

Here `lambda` is the seed length and `stretch` is the additional output length.

**`Set name`** — an abstract set parameter, used for message spaces, key spaces, ciphertext spaces, or any other abstract type that schemes will later make concrete.

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) { ... }
```

**`Group name`** — a finite cyclic group parameter, used by primitives that operate over a group (e.g., a Diffie–Hellman key-exchange or ElGamal-style construction). Once a `Group G` parameter is in scope, the primitive can refer to `G.order`, `G.generator`, and `G.identity`, and to the element type `GroupElem<G>`. See [Basics]({% link manual/language-reference/basics.md %}) for the full group accessor list.

```prooffrog
Primitive DH(Group G) { ... }
```

Multiple parameters of any of these kinds may be combined in a single comma-separated list. Schemes and games that instantiate the primitive supply concrete arguments in the same order.

---

## Set field declarations

Inside a primitive body, a `Set` field declaration binds a name to one of the abstract set parameters (or a derived type expression). The declared name becomes a *type alias* that the rest of the file system can use to refer to that type through the primitive instance.

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;

    ...
}
```

Once an instance `E` of `SymEnc` is in scope (in a game or proof), you can write `E.Message`, `E.Ciphertext`, and `E.Key` as type names. This indirection is what lets a security game be written generically — the game refers to `E.Message` rather than to a specific bitstring length, so it works for any scheme that instantiates the primitive.

`Int` fields work the same way for integer constants:

```prooffrog
Primitive PRG(Int lambda, Int stretch) {
    Int lambda = lambda;
    Int stretch = stretch;

    ...
}
```

After this, a game or scheme holding an instance `G` of `PRG` can write `G.lambda` and `G.stretch` wherever an integer expression is expected.

---

## Method signatures

Method signatures in a primitive declare the return type, method name, and parameter types — but no body. The return type may be:

- Any concrete or parameterized type: `Key`, `BitString<out>`, `Bool`
- An optional type `T?` when the method may fail to produce a value (e.g., decryption returning `Message?` to signal a decryption failure)
- A tuple type `[T1, T2]` when the method returns multiple values

Parameters follow the same type rules.

**Unparameterized `BitString`** is a special placeholder available in primitive signatures for methods whose input or output length is not determined by the primitive itself. The `Hash` primitive illustrates this: the input length is not fixed by the primitive, so it appears as bare `BitString`:

```prooffrog
deterministic BitString<outputLen> evaluate(BitString<lambda> seed, BitString input);
```

A scheme extending this primitive will supply a concrete type for that parameter.

Primitives do not contain method bodies. Any method declared in a primitive must be fully implemented by every scheme that `extends` the primitive.

---

## The `deterministic` and `injective` modifiers

Primitive method signatures may carry one or both of two modifiers that communicate behavioral guarantees to the ProofFrog engine.

### `deterministic`

A method marked `deterministic` always returns the same output when called on the same inputs. Without this annotation, the engine treats every method call as potentially non-deterministic — two calls with identical arguments might return different values, and the engine will not assume otherwise.

Marking a method `deterministic` enables several engine optimizations during proof verification: it may deduplicate calls to the same method with identical arguments, propagate value aliases across method calls, hoist repeated calls out of contexts where they appear multiple times, and fold tuples through the call. These transformations are sound only when the method is genuinely deterministic, which is why the annotation must be explicitly provided rather than inferred.

### `injective`

A method marked `injective` maps distinct inputs to distinct outputs. The engine uses this to see through encoding wrappers when applying certain transforms — for instance, the `ChallengeExclusionRFToUniform` transform can recognize that sampling distinct preimages under an injective function yields distinct images, enabling simplifications that would not be sound otherwise.

### Combining the modifiers

The two modifiers may appear together:

```prooffrog
deterministic injective BitString<blen> evaluate(BitString<lambda> seed, BitString<blen> input);
```

Both claims must hold: the method is deterministic (same inputs give the same output) and injective (distinct inputs give distinct outputs). The PRP primitive uses both, since a pseudorandom permutation is a keyed bijection.

For details on exactly which engine transforms are unlocked by each modifier, see the [Canonicalization]({% link manual/canonicalization.md %}) page.

### Matching-modifier rule

When a scheme `extends` a primitive, the typechecker requires that the scheme's implementation of each method carries *exactly* the same `deterministic` and `injective` modifiers as the primitive's declaration. Omitting a modifier or adding an extra one is a type error. This rule ensures that the engine's assumptions about modifier semantics are consistent across the interface boundary.

---

## Examples

The following examples are drawn directly from `examples/Primitives/` in the ProofFrog repository.

### PRG — Pseudorandom Generator

```prooffrog
Primitive PRG(Int lambda, Int stretch) {
    Int lambda = lambda;
    Int stretch = stretch;

    deterministic BitString<lambda + stretch> evaluate(BitString<lambda> x);
}
```

Takes a seed of `lambda` bits and stretches it to `lambda + stretch` bits. The `evaluate` method is `deterministic` because a PRG is a keyed function: same seed always yields the same output. Integer fields expose `lambda` and `stretch` for use in game and scheme code.

### PRF — Pseudorandom Function

```prooffrog
Primitive PRF(Int lambda, Int in, Int out) {
    Int lambda = lambda;
    Int in = in;
    Int out = out;

    deterministic BitString<out> evaluate(BitString<lambda> seed, BitString<in> input);
}
```

A keyed function mapping `in`-bit inputs to `out`-bit outputs under a `lambda`-bit key. Like the PRG, `evaluate` is `deterministic` because the same key and input always produce the same output.

### SymEnc — Symmetric Encryption

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;

    Key KeyGen();
    Ciphertext Enc(Key k, Message m);
    deterministic Message? Dec(Key k, Ciphertext c);
}
```

An encryption scheme over abstract message, ciphertext, and key spaces. `KeyGen` and `Enc` are non-deterministic by default (key generation and encryption may use randomness). `Dec` is `deterministic` because decryption is a pure function of the key and ciphertext. The return type `Message?` captures that decryption can fail (returning `None` for an invalid ciphertext).

### MAC — Message Authentication Code

```prooffrog
Primitive MAC(Set MessageSpace, Set TagSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Tag = TagSpace;
    Set Key = KeySpace;

    Key KeyGen();

    deterministic Tag MAC(Key k, Message m);
}
```

A tagging scheme over abstract message, tag, and key spaces. Tag computation is `deterministic`: given a fixed key and message, the tag is always the same value. Key generation is non-deterministic.

### PRP — Pseudorandom Permutation

```prooffrog
Primitive PRP(Int lambda, Int blen) {
    Int lambda = lambda;
    Int blen = blen;

    deterministic injective BitString<blen> evaluate(BitString<lambda> seed, BitString<blen> input);

    deterministic injective BitString<blen> evaluateInverse(BitString<lambda> seed, BitString<blen> input);
}
```

A keyed permutation on `blen`-bit strings with a `lambda`-bit key. Both the forward evaluation and its inverse are `deterministic` and `injective`: a permutation is by definition a bijection, so distinct inputs always yield distinct outputs. The inverse method allows schemes to implement block-cipher-based constructions that require decryption.
