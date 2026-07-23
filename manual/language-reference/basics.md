---
title: Basics
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 1
---

# FrogLang Basics
{: .no_toc }

This page describes the syntactic and semantic foundations shared by all FrogLang file types: lexical conventions, types, expressions and operators, sampling, statements, and imports.

- TOC
{:toc}

---

## Lexical

**Character set.** FrogLang files must be ASCII only. Non-ASCII characters (including Unicode letters, accents, and non-breaking spaces) are rejected by the parser.

**Comments.** `//` begins a comment that runs to the end of the line. Multi-line or block comments use `/* ... */`.

**Identifiers.** An identifier is a sequence of letters, digits, and underscores that does not begin with a digit. Identifiers are case-sensitive.

**Reserved keywords.** The following words are reserved and may not be used as identifiers:

```
Primitive      Scheme      Game        Reduction   proof
let            assume      lemma       theorem     games
compose        against     import      export      as
if             else        for         to          in
return         extends     requires    this        challenger
deterministic  injective   None        true        false
```

**File extensions**

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

**`Group`** — a declaration type used to introduce a group parameter. The model is a finite cyclic group; all finite cyclic groups are abelian, so the group operation is commutative. Groups may have prime or composite order.

A group identifier `G` provides three built-in accessors:

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

Every sampled `Function<D, R>` field automatically maintains an implicit **`.domain`** set that tracks which inputs have been queried. For example, if a game has a field `Function<BitString<n>, BitString<m>> RF`, then `RF.domain` is a `Set<BitString<n>>` containing every input on which `RF` has been evaluated. This set can be used as the bookkeeping set for `<-uniq` sampling (e.g., `r <-uniq[RF.domain] BitString<n>`) or passed to a helper game's `Samp` method (e.g., `challenger.Samp(RF.domain)`). See [Canonicalization]({% link manual/canonicalization.md %}#random-function-on-distinct-inputs) for how the engine uses this to simplify random-function calls on distinct inputs.

### Optional type

**`T?`** — either a value of type `T` or `None`. Commonly used for operations that may fail, such as decryption (`Message? Dec(Key k, Ciphertext c);`).

### Tuple types

**`[T1, T2, ..., Tn]`** — ordered heterogeneous collection. Tuple literals are written `[e1, e2, ..., en]` and elements are accessed by **constant** integer index: `t[0]`, `t[1]`, etc. The index must be a compile-time constant, not a runtime expression.

Note: the current syntax for tuple types uses bracket notation `[A, B]`. An older product-type notation `A * B` is not accepted by the current engine.

Note: `...` cannot be used in FrogLang tuples: when writing a tuple type or tuple literals in FrogLang, a concrete size must be used. In other words, you can write a 4-tuple `[T1, T2, T3, T4]` but not an `n`-tuple literal `[T1, T2, ..., Tn]`.

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
| `0^n` | `BitString<n>` | The all-zeros bitstring of length `n` |
| `1^n` | `BitString<n>` | The all-ones bitstring of length `n` |
| `true`, `false` | `Bool` | Boolean literals |
| `None` | `T?` | The null value, for methods with an optional return type |
| `{e1, e2}` | `Set<T>` | Set literals (no empty set notation needed; all sets are initialized to empty) |
| `[e1, e2]` | `[T1, T2]` | Tuple literal |

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
| `||` | `Bool`, `Bool` | `Bool` | Logical OR |
| `||` | `BitString<n>`, `BitString<m>` | `BitString<n+m>` | Concatenation |
| `&&` | `Bool`, `Bool` | `Bool` | Logical AND |
| `!` | `Bool` | `Bool` | Logical NOT |
| `==`, `!=` | any comparable | `Bool` | Equality / inequality |
| `<`, `>`, `<=`, `>=` | `Int`, `ModInt<q>` | `Bool` | Ordered comparison |
| `in` | `T`, `Set<T>` | `Bool` | Membership test |
| `subsets` | `Set<T>`, `Set<T>` | `Bool` | Subset test |
| `union` | `Set<T>`, `Set<T>` | `Set<T>` | Set union |
| `\` | `Set<T>`, `Set<T>` | `Set<T>` | Set difference |
| `a[i]` | `Array<T,n>`, index `Int` | `T` | Array element at index `i` |
| `a[i]` | `BitString<n>`, index `Int` | single bit | Bit at position `i` |
| `a[i : j]` | `BitString<n>` | `BitString<j-i>` | Slice from `i` (inclusive) to `j` (exclusive) |

**Highlights:**

- `+` on `BitString<n>` is **XOR**, not arithmetic addition. This is a common source of confusion: `k + m` in FrogLang XORs `k` and `m` when both are bitstrings. The OTP encryption `return k + m;` is XOR.
- `||` is overloaded: logical OR on `Bool` and concatenation on `BitString`. The type of both operands determines which operation is performed.
- `^` is **right-associative** exponentiation, not XOR. XOR is `+`.
- Bitstring slice bounds: `a[i : j]` is **inclusive on the left, exclusive on the right**, yielding a bitstring of length `j - i`.

### Operator precedence

Precedence from highest (binds tightest) to lowest:

| Level | Operators |
|---|---|
| 1 (highest) | `^` (right-associative) |
| 2 | `*`, `/` |
| 3 | `+`, `-` |
| 4 | `==`, `!=`, `<`, `>`, `<=`, `>=`, `in`, `subsets` |
| 5 | `&&` |
| 6 (lowest) | `||`, `union`, `\` |

### Algebraic properties

| Operator | Types | Commutative | Associative | Identity |
|---|---|---|---|---|
| `+` | `Int`, `ModInt<q>` | Yes | Yes | `0` |
| `+` | `BitString<n>` | Yes | Yes | `0^n` |
| `*` | `Int`, `ModInt<q>` | Yes | Yes | `1` |
| `*` | `GroupElem<G>` | Yes | Yes | `G.identity` |
| `&&` | `Bool` | Yes | Yes | `true` |
| `||` | `Bool` | Yes | Yes | `false` |
| `-` | any | No | No | — |
| `/` | any | No | No | — |
| `^` | any | No | No | — |
| `||` | `BitString` | No | Yes | — |

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

**Sampling with exclusions:**

```prooffrog
BitString<n> x <- BitString<n> \ S;
```

Samples `x` uniformly at random from the type on the left, **excluding** the elements of the set `S` on the right (i.e., from `BitString<n> \ S`). This is useful when a value must differ from previously-seen values — for example, sampling a challenge that is guaranteed not to collide with earlier ones. Unlike `<-uniq` below, this form does *not* automatically update any bookkeeping set; you manage `S` yourself.

**Unique sampling (rejection sampling):**

```prooffrog
BitString<n> x <-uniq[S] BitString<n>;
```

This is shorthand notation for sampling uniformly without replacement, with bookkeeping handled by the set `S`.  In other words, it's equivalent to initializing `S = {}`, sampling `x <- BitString<n> \ S`, and then updating `S <- S union {x}`. While the expanded form is also valid FrogLang, using the shorthand notation enables the ProofFrog engine to recognize this pattern and apply certain transformations.

A common pattern is to use a random function's implicit `.domain` set as the bookkeeping set: `r <-uniq[RF.domain] BitString<n>` ensures `r` is distinct from all inputs on which `RF` has previously been evaluated. See [`Function<D, R>`](#functiond-r) for details on `.domain`.

**Sample into a map entry:**

```prooffrog
M[k] <- BitString<n>;
```

Samples a value uniformly at random and stores it at key `k` of map `M`.

**Sample a tuple and bind its components:**

```prooffrog
[BitString<n>, BitString<m>] [u, v] <- [BitString<n>, BitString<m>];
[BitString<n>, BitString<m>] [u, v] <- [BitString<n>, BitString<m>] \ S;
```

Samples a tuple-typed value (optionally excluding the elements of a set `S`) and binds each component to its own name, rather than binding the whole tuple and indexing it afterwards. See [Tuple-destructuring bindings](#tuple-destructuring-bindings) under Statements.

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
Type x <- Type;         // sample variable x uniformly at random from set Type
Type x <- Type \ S;     // sample variable x uniformly at random from Type \ S
                        // (no automatic bookkeeping)
Type x <-uniq[S] Type;  // sample variable x uniformly at random from Type \ S 
                        // and implicitly update bookkeeping set S
M[k] <- Type;           // sample uniformly at random and assign to a map value
```

### Tuple-destructuring bindings

A statement may bind the components of a tuple to separate names in one go, instead of binding the tuple and then reading it back by index. There are two forms:

```prooffrog
[T1, T2] [a, b] = expr;              // bind components of a tuple-valued expression
[T1, T2] [u, v] <- [T1, T2] \ S;     // sample a tuple excluding the elements of S,
                                     // and bind its components
```

In each case the type on the left must be a tuple type, and there must be two or more names. The names bind positionally: `a` gets component 0, `b` gets component 1. The most common use is a method that returns a pair:

```prooffrog
// Instead of:
[E.PublicKey, E.SecretKey] kp = E.KeyGen();
E.PublicKey pk = kp[0];
E.SecretKey sk = kp[1];

// Write:
[E.PublicKey, E.SecretKey] [pk, sk] = E.KeyGen();
```

{: .note }
This is pure syntactic sugar. The parser expands a destructuring binding into a temporary variable plus constant-index reads — exactly the longhand above — before semantic analysis runs. Canonicalization and the proof engine therefore never see a distinct construct, and a game written with destructuring canonicalizes identically to the same game written longhand. (The one component that opts out of the expansion is the [LaTeX exporter]({% link manual/latex-export.md %}), which renders the binding as written.)

{: .warning }
There is a third form in the grammar, `[T1, T2] [u, v] <- [T1, T2];` — sampling a tuple with no exclusion set — but it does not currently type-check: the right-hand side of a bare `<-` parses as a tuple *literal* rather than a tuple *type*, and the checker rejects it with `Right-hand side of '<-' must be a type`. The same is true of the non-destructuring `[T1, T2] t <- [T1, T2];`. Until this is fixed, sample the components separately, or use the exclusion form with an empty set.

### Conditional

```prooffrog
if (condition) {
    ...
}

if (condition1) {
    ...
} else if (condition2) {
    ...
} else {
    ...
}
```

Conditions must be `Bool` expressions.

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

Iterates over the elements of a collection. The `collection` may be:

- a `Set<T>` or an `Array<T, n>`, in which case `x` ranges over the elements (type `T`);
- a map's `.keys` (type `K`), `.values` (type `V`), or `.entries` of a `Map<K, V>`, where each entry is a `[K, V]` key/value tuple.

For sets and maps, the iteration order is unspecified.

```prooffrog
// Iterate over a map's key/value entries
for ([GroupElem<G>, BitString<n>] entry in HashTable.entries) {
    ...
}
```

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

**Example.** The proof `examples/Proofs/SymEnc/INDOT$_implies_INDOT.proof` imports:

```prooffrog
import '../../Primitives/SymEnc.primitive';
import '../../Games/SymEnc/INDOT.game';
import '../../Games/SymEnc/INDOT$.game';
```

From `examples/Proofs/SymEnc/`, `../..` navigates up to `examples/`, and the paths then descend into `Primitives/` and `Games/SymEnc/`.

Any file type (`.primitive`, `.scheme`, `.game`, `.proof`) can be imported.
