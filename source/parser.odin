
package thor64

import "core:fmt"

Ast_Base :: struct {
    using first_token: Token,
}

Ast_Node :: union {
    File,
    Declaration,
    Identifier,
}

File :: struct {
    using base: Ast_Base,
    declarations: []Declaration
}

Identifier :: struct {
    using base: Ast_Base,
}

Type :: struct {
    using base: Ast_Base,
    // byte
}

Declaration :: struct {
    using base: Ast_Base,
    
    identifier: Identifier,
    type: Type,
    is_const: bool,
}

Error :: struct {
    node: Ast_Node,
    message: string,
}

error :: proc(node: Ast_Node, fmt_str: string, args: ..any) -> Error {
    result: Error
    result.node = node
    result.message = fmt.aprintf(fmt_str, ..args)
    return result
}

Parser :: struct {
    tokenizer: Tokenizer,
    errors: [dynamic]Error,
}

parse_identifier :: proc(using parser: ^Parser) -> (Identifier, bool) {
    token := get_token(&tokenizer)
    
    result: Identifier
    result.first_token = token

    if token.kind != .Identifier {
        append(&errors, error(result, "Expected identifier"))
        for {
            token := peek_token(&tokenizer)
            if is_punct(token, ";") {
                advance_token(&tokenizer)
                break
            }
            if is_punct(token, "{") {
                parse_block(parser)
                break
            }
            advance_token(&tokenizer)
        }
        
        return result, false
    }
    return result, true
}

parse_declaration :: proc(using parser: ^Parser) -> Declaration {
    result: Declaration
    identifier, ok := parse_identifier(parser)
    result.identifier = identifier
    if !ok do return result

    expect_punct(parser, ":")
    
    result.type := parse_type(parser)
    
    return result
}

parse_file :: proc(using parser: ^Parser) -> File {
    declarations := make([dynamic]Declaration)

    result: File
    result.first_token = peek_token(&tokenizer)
    
    for peek_token(&tokenizer).kind != .EOF {
        append(&declarations, parse_declaration(parser))
    }

    result.declarations = declarations[:]

    return result
}
