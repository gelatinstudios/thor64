
package thor64

import "core:fmt"

main :: proc() {
    tokenizer := &Tokenizer{}
    init(tokenizer, #load("../example.thor64", string))

    for peek_token(tokenizer).kind != .EOF {
        fmt.println(get_token(tokenizer))
    }
}
