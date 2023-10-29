
package thor64

import "core:reflect"
import "core:strings"
import "core:strconv"
import "core:unicode"
import "core:unicode/utf8"

Atom :: distinct u64

Keyword :: enum {
    Proc = 1,
}

Token_Kind :: enum {
    None,
    EOF,
    Keyword,
    Identifier,
    Integer_Literal,
    Punctuation,
}

Token :: struct {
    kind: Token_Kind,
    atom: Atom,
    raw: string,
    at: int,

    // usage of Maybe here is only for asserting that these are set correctly
    integer_value: Maybe(int),
    keyword: Maybe(Keyword),
    
}

is_punct :: proc(token: Token, s: string) -> bool {
    return token.kind == .Punctuation && token.raw == s
}

Tokenizer :: struct {
    source: string,
    at: int,

    atoms: map[string]Atom,
    current_atom: Atom,
    keywords: map[Atom]Keyword,
    
    current_rune: Maybe(rune),
    current_token: Maybe(Token),
}

atomize :: proc(using tokenizer: ^Tokenizer, s: string) -> Atom {
    if s in atoms do return atoms[s]
    atoms[s] = current_atom
    defer current_atom += 1
    return current_atom
}

init :: proc(using tokenizer: ^Tokenizer, source_: string) {
    tokenizer^ = Tokenizer{}
    tokenizer.source = source_
    tokenizer.atoms = make(map[string]Atom)
    tokenizer.current_atom = Atom(1)
    tokenizer.keywords = make(map[Atom]Keyword)
    
    for keyword in Keyword {
        s := reflect.enum_string(keyword)
        atom := atomize(tokenizer, strings.to_lower(s))
        keywords[atom] = keyword
    }
}

peek_rune :: proc(using tokenizer: ^Tokenizer) -> rune {
    r, ok := current_rune.(rune)
    if ok do return r
    if at >= len(source) do return 0
    r, _ = utf8.decode_rune(source[at:])
    current_rune = r
    return r
}

advance_rune :: proc(using tokenizer: ^Tokenizer) {
    at += utf8.rune_size(current_rune.(rune))
    current_rune = nil
}

get_rune :: proc(using tokenizer: ^Tokenizer) -> rune {
    defer advance_rune(tokenizer)
    return peek_rune(tokenizer)
}

skip_whitespace :: proc(using tokenizer: ^Tokenizer) {
    for unicode.is_white_space(peek_rune(tokenizer)) {
        advance_rune(tokenizer)
    }
}

peek_token :: proc(using tokenizer: ^Tokenizer) -> Token {
    t, ok := current_token.(Token)
    if ok do return t
    
    result: Token
    
    if at >= len(source) {
        result.kind = .EOF
        return result
    }

    skip_whitespace(tokenizer)

    result.at = at
    
    set_and_atomize :: proc(using tokenizer: ^Tokenizer, result: ^Token) {
        result.raw = source[result.at:at]
        result.atom = atomize(tokenizer, result.raw)
    }
    
    r := get_rune(tokenizer)
    if unicode.is_letter(r) || r == '_' {
        result.kind = .Identifier // assume identifier
        for {
            r = peek_rune(tokenizer)
            if !(unicode.is_letter(r) ||
                 r == '_' ||
                 unicode.is_digit(r))
            {
                break
            }
            advance_rune(tokenizer)
        }
        set_and_atomize(tokenizer, &result)
        if result.atom in keywords {
            result.kind = .Keyword
            result.keyword = keywords[result.atom]
        }
    } else if unicode.is_digit(r) {
        result.kind = .Integer_Literal
        for unicode.is_digit(peek_rune(tokenizer)) {
            advance_rune(tokenizer)
        }
        set_and_atomize(tokenizer, &result)
        v, ok := strconv.parse_int(result.raw)
        assert(ok) // probably shouldn't ever fail???
        result.integer_value = v
    } else {
        result.kind = .Punctuation
        set_and_atomize(tokenizer, &result)
    }

    current_token = result

    skip_whitespace(tokenizer)
    
    return result
}

advance_token :: proc(using tokenizer: ^Tokenizer) {
    current_token = nil
}

get_token :: proc(using tokenizer: ^Tokenizer) -> Token {
    defer advance_token(tokenizer)
    return peek_token(tokenizer)
}
