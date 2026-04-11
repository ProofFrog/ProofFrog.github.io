# Rouge lexer for FrogLang (the ProofFrog language).
#
# Registers the `prooffrog` tag (plus per-file-type aliases) so that fenced
# code blocks like ```prooffrog are syntax-highlighted server-side by Rouge
# at Jekyll build time. This replaces the previous client-side Prism setup.
#
# The token set mirrors the old Prism grammar in assets/js/prism-prooffrog.js.

require 'rouge'

module Rouge
  module Lexers
    class ProofFrog < Rouge::RegexLexer
      title 'ProofFrog'
      desc 'FrogLang, the language of the ProofFrog proof assistant'
      tag 'prooffrog'
      aliases 'froglang', 'primitive', 'scheme', 'game', 'proof'
      filenames '*.primitive', '*.scheme', '*.game', '*.proof'

      # Top-level construct introducers
      declarations = %w[Primitive Scheme Game Reduction Phase]

      # Built-in types
      builtins = %w[Bool Void Int BitString Set Map Array]

      # Reserved words
      keywords = %w[
        import export as extends compose against requires
        if else for return in to
        union subsets induction from calls
        Adversary oracles proof
        let assume theorem games
      ]

      state :root do
        rule %r(\s+), Text
        rule %r(//.*), Comment::Single

        # Single-quoted import path strings
        rule %r('[^']*'), Str::Single

        # Numbers: binary literals and decimal integers
        rule %r(\b0b[01]+\b), Num::Bin
        rule %r(\b\d+\b), Num::Integer

        # None / true / false
        rule %r(\bNone\b), Keyword::Constant
        rule %r(\b(?:true|false)\b), Keyword::Constant

        rule %r(\b(?:#{builtins.join('|')})\b), Name::Builtin
        rule %r(\b(?:#{declarations.join('|')})\b), Keyword::Declaration
        rule %r(\b(?:#{keywords.join('|')})\b), Keyword

        # Operators (longest match first)
        rule %r(<-|[=!<>]=|&&|\|\|), Operator
        rule %r([+\-*/\\|!<>=]), Operator

        rule %r([{}\[\]();:,.?]), Punctuation

        rule %r(\w+), Name
        rule %r(.), Text
      end
    end
  end
end
