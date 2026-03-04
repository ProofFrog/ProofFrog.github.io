// ── Prism.js language grammar for ProofFrog's FrogLang ──────────────────────
// Defines Prism.languages.prooffrog for syntax highlighting FrogLang files
// (.primitive, .scheme, .game, .proof).

(function (Prism) {
    Prism.languages.prooffrog = {
        // Line comments: // to end of line
        "comment": /\/\/.*/,

        // Import path strings: single-quoted
        "string": /'[^']*'/,

        // Numbers: binary (0b...) and decimal
        "number": /\b0b[01]+\b|\b\d+\b/,

        // Built-in type names
        "builtin": /\b(?:Bool|Void|Int|BitString|Set|Map|Array)\b/,

        // Boolean literals
        "boolean": /\b(?:true|false)\b/,

        // None literal
        "constant": /\bNone\b/,

        // Declaration keywords (top-level construct introducers)
        "class-name": /\b(?:Primitive|Scheme|Game|Reduction|Phase)\b/,

        // Keywords
        "keyword": /\b(?:import|export|as|extends|compose|against|requires|if|else|for|return|in|to|union|subsets|induction|from|calls|Adversary|oracles|proof|let|assume|theorem|games)\b/,

        // Operators (longest match first via alternation order)
        "operator": /<-|[=!<>]=|&&|\|\||[+\-*\/\\|!<>=]/,

        // Punctuation
        "punctuation": /[{}[\]();:,.?]/,
    };

    // Register for all FrogLang file extensions
    Prism.languages.primitive = Prism.languages.prooffrog;
    Prism.languages.scheme = Prism.languages.prooffrog;
    Prism.languages.game = Prism.languages.prooffrog;
    Prism.languages.proof = Prism.languages.prooffrog;
})(Prism);
