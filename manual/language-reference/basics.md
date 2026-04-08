---
title: Basics
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 1
---

# FrogLang Basics

This page describes the syntactic and semantic foundations shared by all FrogLang file types: lexical conventions, types, expressions and operators, sampling, statements, and imports.

---

## Lexical

**Character set.** FrogLang files must be ASCII only. Non-ASCII characters (including Unicode letters, accents, and non-breaking spaces) are rejected by the parser.

**Comments.** Only line comments are supported: `//` begins a comment that runs to the end of the line. There are no block comments.

**Identifiers.** An identifier is a sequence of letters, digits, and underscores that does not begin with a digit. Identifiers are case-sensitive.

**Reserved keywords.** The following words are reserved and may not be used as identifiers:

```
Primitive   Scheme      Game        Reduction   proof
let         assume      lemma       theorem     games
compose     against     import      export      as
if          else        for         to          in
return      extends     requires    this        challenger
deterministic  injective  None      true        false
```

**File extensions.**

| Extension | File type |
|---|---|
| `.primitive` | Cryptographic primitive |
| `.scheme` | Cryptographic scheme |
| `.game` | Security game (pair) |
| `.proof` | Game-hopping proof |

---

## Types

### Primitive types

| Type | Description |
|---|---|
| `Int` | Unbounded integer. Used for security parameters, lengths, loop bounds, and arithmetic. |
| `Bool` | Boolean. Literals: `true`, `false`. |
| `Void` | Unit type. Only valid as a method return type (typically for `Initialize`). |

### Parameterized types

**`BitString<n>`** — the set of all bit strings of length `n`, where `n` is an `Int` expression. Cardinality: `2^n`. An unparameterized `BitString` (no angle brackets) may appear in primitive signatures as a placeholder to be resolved when the primitive is instantiated.

**`ModInt<q>`** — integers modulo `q`, i.e., the set `{0, 1, ..., q-1}`. Cardinality: `q`. Arithmetic on `ModInt<q>` is performed mod `q`.

**`Group`** — a declaration type used to introduce a group parameter. The model is a finite cyclic group; all finite cyclic groups are abelian, so the group operation is commutative. A group identifier `G` provides three built-in accessors:

| Accessor | Type | Description |
|---|---|---|
| `G.order` | `Int` | Number of elements in the group |
| `G.generator` | `GroupElem<G>` | A designated generator whose powers enumerate every group element |
| `G.identity` | `GroupElem<G>` | Identity element; `G.generator ^ 0 == G.identity` |

**`GroupElem<G>`** — the set of elements of group `G`. Parameterized by group identifier, not order, so elements from different groups are type-incompatible even when the groups have the same order. Cardinality: `G.order`.

### Collection types

**`Array<T, n>`** — fixed-size array of `n` elements of type `T`, indexed from `0` to `n-1`.

**`Map<K, V>`** — finite partial function from keys of type `K` to values of type `V`. A map starts empty (no keys are mapped). Accessing a key not in the map's domain is undefined behavior.

**`Set<T>`** — finite set of elements of type `T`. An unparameterized `Set` in a primitive signature is an abstract placeholder.

### `Function<D, R>`

The type of a function from domain `D` to range `R`. Its meaning depends on how it is introduced:

- **Declared** (`Function<D, R> H;`): a known deterministic function in the standard model. The adversary can compute it; the engine treats calls to it as deterministic.
- **Sampled** (`Function<D, R> H <- Function<D, R>;`): a truly random function (random oracle model). Each distinct input maps independently to a uniform random output; repeated queries on the same input return the same result.

Only sampled `Function` values receive random-function simplifications during proof verification. This distinction matters: declaring `H` without sampling gives the adversary free access to a fixed function, not a random one.

### Optional type

**`T?`** — either a value of type `T` or `None`. Commonly used for operations that may fail, such as decryption (`Message? Dec(Key k, Ciphertext c);`).

### Tuple types

**`[T1, T2, ..., Tn]`** — ordered heterogeneous collection. Tuple literals are written `[e1, e2, ..., en]` and elements are accessed by **constant** integer index: `t[0]`, `t[1]`, etc. The index must be a compile-time constant, not a runtime expression.

Note: the current syntax for tuple types uses bracket notation `[A, B]`. An older product-type notation `A * B` is not accepted by the current engine.

### Type aliases

Primitives and schemes declare named `Set` fields that become type aliases:

```prooffrog
Set Key = BitString<lambda>;
```

From another file, after importing, a scheme or primitive instance `E` exposes this as `E.Key`. When a scheme is instantiated in a proof's `let:` block, the alias resolves to its concrete type.

---

## Expressions and Operators

### Literals

| Form | Type | Description |
|---|---|---|
| `0`, `42` | `Int` | Integer literal |
| `0b101` | `BitString<3>` | Binary literal; length equals digit count after `0b` |
| `0^n` | `BitString<n>` | All-zeros bitstring of length `n` |
| `1^n` | `BitString<n>` | All-ones bitstring of length `n` |
| `true`, `false` | `Bool` | Boolean literals |
| `None` | `T?` | Null optional |
| `{e1, e2}`, `{}` | `Set<T>` | Set literals |
| `[e1, e2]`, `[]` | `[T1, T2]` | Tuple literals |

### Operator table

| Operator | Operand types | Result | Notes |
|---|---|---|---|
| `+` | `Int`, `Int` | `Int` | Addition |
| `+` | `ModInt<q>`, `ModInt<q>` | `ModInt<q>` | Addition mod `q` |
| `+` | `BitString<n>`, `BitString<n>` | `BitString<n>` | **XOR** — not addition |
| `-` | `Int`, `Int` | `Int` | Subtraction |
| `-` | `ModInt<q>`, `ModInt<q>` | `ModInt<q>` | Subtraction mod `q` |
| `*` | `Int`, `Int` | `Int` | Multiplication |
| `*` | `ModInt<q>`, `ModInt<q>` | `ModInt<q>` | Multiplication mod `q` |
| `*` | `GroupElem<G>`, `GroupElem<G>` | `GroupElem<G>` | Group operation (abelian) |
| `/` | `Int`, `Int` | `Int` | Integer division |
| `/` | `ModInt<q>`, `ModInt<q>` | `ModInt<q>` | Modular division |
| `/` | `GroupElem<G>`, `GroupElem<G>` | `GroupElem<G>` | `a * b^(-1)` |
| `^` | `Int`, `Int` | `Int` | Exponentiation (right-associative) |
| `^` | `ModInt<q>`, `Int` | `ModInt<q>` | Modular exponentiation (right-associative) |
| `^` | `GroupElem<G>`, `ModInt<G.order>` or `Int` | `GroupElem<G>` | Scalar power (right-associative) |
| `-` (unary) | `Int` | `Int` | Negation |
| `\|\|` | `Bool`, `Bool` | `Bool` | Logical OR |
| `\|\|` | `BitString<n>`, `BitString<m>` | `BitString<n+m>` | Concatenation |
| `&&` | `Bool`, `Bool` | `Bool` | Logical AND |
| `!` | `Bool` | `Bool` | Logical NOT |
| `==`, `!=` | any comparable | `Bool` | Equality / inequality |
| `<`, `>`, `<=`, `>=` | `Int`, `ModInt<q>` | `Bool` | Ordered comparison |
| `in` | `T`, `Set<T>` | `Bool` | Membership test |
| `subsets` | `Set<T>`, `Set<T>` | `Bool` | Subset test |
| `union` | `Set<T>`, `Set<T>` | `Set<T>` | Set union |
| `\` | `Set<T>`, `Set<T>` | `Set<T>` | Set difference |
| `\|x\|` | `Set<T>`, `Map<K,V>`, `BitString<n>`, `Array<T,n>` | `Int` | Cardinality / length |
| `a[i]` | `Array<T,n>`, index `Int` | `T` | Array element at index `i` |
| `a[i]` | `BitString<n>`, index `Int` | single bit | Bit at position `i` |
| `a[i : j]` | `BitString<n>` | `BitString<j-i>` | Slice from `i` (inclusive) to `j` (exclusive) |

**Key gotchas:**

- `+` on `BitString<n>` is **XOR**, not arithmetic addition. This is the most common source of confusion: `k + m` in FrogLang XORs `k` and `m` when both are bitstrings. The OTP encryption `return k + m;` is XOR.
- `||` is overloaded: logical OR on `Bool` and concatenation on `BitString`. The type of both operands determines which operation is performed.
- `^` is **right-associative** exponentiation, not XOR. XOR is `+`.
- Bitstring slice bounds: `a[i : j]` is **inclusive on the left, exclusive on the right**, yielding `BitString<j - i>`.

### Operator precedence

Precedence from highest (binds tightest) to lowest:

| Level | Operators |
|---|---|
| 1 (highest) | `^` (right-associative) |
| 2 | `*`, `/` |
| 3 | `+`, `-` |
| 4 | `==`, `!=`, `<`, `>`, `<=`, `>=`, `in`, `subsets` |
| 5 | `&&` |
| 6 (lowest) | `\|\|`, `union`, `\` |

### Algebraic properties

| Operator | Types | Commutative | Associative | Identity |
|---|---|---|---|---|
| `+` | `Int`, `ModInt<q>` | Yes | Yes | `0` |
| `+` | `BitString<n>` | Yes | Yes | `0^n` |
| `*` | `Int`, `ModInt<q>` | Yes | Yes | `1` |
| `*` | `GroupElem<G>` | Yes | Yes | `G.identity` |
| `&&` | `Bool` | Yes | Yes | `true` |
| `\|\|` | `Bool` | Yes | Yes | `false` |
| `-` | any | No | No | — |
| `/` | any | No | No | — |
| `^` | any | No | No | — |
| `\|\|` | `BitString` | No | Yes | — |

---

## Sampling

FrogLang uses the `<-` operator for uniform random sampling.

**Uniform sample from a type:**

```prooffrog
BitString<n> r <- BitString<n>;
ModInt<q> x <- ModInt<q>;
GroupElem<G> u <- GroupElem<G>;
```

Draws a value uniformly at random from the full domain of the named type.

**Unique sampling (rejection sampling):**

```prooffrog
BitString<n> x <-uniq[S] BitString<n>;
```

Samples uniformly from `BitString<n> \ S`, where `S` is a set expression. Semantically equivalent to repeated sampling until the result is not in `S`. Used when freshness is required (for example, ensuring a nonce was not previously used).

**Sample into a map entry:**

```prooffrog
M[k] <- BitString<n>;
```

Samples a value uniformly at random and stores it at key `k` of map `M`.

**Sample a random function (ROM):**

```prooffrog
Function<D, R> H <- Function<D, R>;
```

Instantiates a fresh random function. Each distinct input independently maps to a uniform random output in `R`; repeated queries on the same input return the same value. This is the standard way to model a random oracle.

**Non-determinism by default.** Scheme method calls such as `F.evaluate(k, x)` are **non-deterministic by default**: each invocation may return a different value even with the same arguments, unless the primitive method is declared with the `deterministic` modifier. The engine is conservative and will not assume two calls with the same inputs produce the same result unless determinism is annotated. For more on how the engine uses this annotation, see the [Execution Model]({% link manual/language-reference/execution-model.md %}) page.

---

## Statements

### Declaration

```prooffrog
Type x;            // declare uninitialized
Type x = expr;     // declare and initialize
```

An uninitialized variable has an undefined value until assigned. It is valid to declare a variable and assign it in a later statement.

### Assignment

```prooffrog
x = expr;          // assign to a variable
a[i] = expr;       // assign to an array or map element
```

### Sampling

Sampling is a statement form (see the Sampling section above):

```prooffrog
Type x <- Type;
Type x <-uniq[S] Type;
M[k] <- Type;
```

### Conditional

```prooffrog
if (condition) {
    ...
}

if (condition) {
    ...
} else {
    ...
}
```

The condition must be a `Bool` expression. `else if` chains are supported.

### Numeric for loop

```prooffrog
for (Int i = start to end) {
    ...
}
```

Iterates `i` from `start` (inclusive) to `end` (exclusive), incrementing by 1 each iteration. The loop body executes `end - start` times when `end > start`; zero times otherwise.

### Iteration for loop

```prooffrog
for (Type x in collection) {
    ...
}
```

Iterates over all elements of a `Set<T>`, all elements of an `Array<T, n>`, or the keys of a `Map<K, V>`. For sets, the iteration order is unspecified.

### Return

```prooffrog
return expr;
```

Exits the current method and returns `expr`. The type of `expr` must match the method's declared return type.

---

## Imports

Files import other files using a relative path:

```prooffrog
import 'relative/path/to/File.primitive';
```

**Paths are file-relative**: the path is resolved relative to the directory containing the importing file, not relative to the directory where the CLI is invoked.

**Example.** The proof `examples/Proofs/SymEnc/OTUCimpliesOTS.proof` imports:

```prooffrog
import '../../Primitives/SymEnc.primitive';
import '../../Games/SymEnc/OneTimeSecrecy.game';
import '../../Games/SymEnc/OneTimeUniformCiphertexts.game';
```

From `examples/Proofs/SymEnc/`, `../..` navigates up to `examples/`, and the paths then descend into `Primitives/` and `Games/SymEnc/`.

Any file type (`.primitive`, `.scheme`, `.game`, `.proof`) can be imported.
