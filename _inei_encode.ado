*! _inei_encode.ado — JS-style URL encoding para portal INEI
*! El portal INEI espera encoding Latin-1 (Windows-1252), NO UTF-8
*! version 1.0.3  2026-04-03

program define _inei_encode, sclass
    version 14.0
    syntax anything(name=input_str)

    local input_str `input_str'

    mata: _inei_js_escape(st_local("input_str"))

    sreturn local encoded "${_inei_encoded}"
    macro drop _inei_encoded
end

mata:
void _inei_js_escape(string scalar s)
{
    string scalar result, hex, ch
    real scalar i, n, b1, b2, b3, cp

    result = ""
    n = strlen(s)
    i = 1

    while (i <= n) {
        b1 = ascii(substr(s, i, 1))

        // ASCII printable safe chars pass through
        if ((b1 >= 65 & b1 <= 90) |   /* A-Z */
            (b1 >= 97 & b1 <= 122) |  /* a-z */
            (b1 >= 48 & b1 <= 57) |   /* 0-9 */
            b1 == 64 |  /* @ */
            b1 == 42 |  /* * */
            b1 == 95 |  /* _ */
            b1 == 43 |  /* + */
            b1 == 45 |  /* - */
            b1 == 46 |  /* . */
            b1 == 47)   /* / */ {
            result = result + substr(s, i, 1)
            i++
        }
        else if (b1 == 32) {
            // Space -> %20
            result = result + "%20"
            i++
        }
        else if (b1 < 128) {
            // Other ASCII -> %XX
            hex = strupper(inbase(16, b1))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i++
        }
        else if (b1 >= 192 & b1 <= 223 & i + 1 <= n) {
            // UTF-8 2-byte sequence -> decode to codepoint -> Latin-1 %XX
            b2 = ascii(substr(s, i + 1, 1))
            cp = (b1 - 192) * 64 + (b2 - 128)
            if (cp <= 255) {
                hex = strupper(inbase(16, cp))
                if (strlen(hex) == 1) hex = "0" + hex
                result = result + "%" + hex
            }
            i = i + 2
        }
        else if (b1 >= 224 & b1 <= 239 & i + 2 <= n) {
            // UTF-8 3-byte sequence -> decode to codepoint -> %uXXXX
            b2 = ascii(substr(s, i + 1, 1))
            b3 = ascii(substr(s, i + 2, 1))
            cp = (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128)
            if (cp <= 255) {
                hex = strupper(inbase(16, cp))
                if (strlen(hex) == 1) hex = "0" + hex
                result = result + "%" + hex
            }
            else {
                hex = strupper(inbase(16, cp))
                while (strlen(hex) < 4) hex = "0" + hex
                result = result + "%u" + hex
            }
            i = i + 3
        }
        else {
            // Single high byte (already Latin-1) -> %XX
            hex = strupper(inbase(16, b1))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i++
        }
    }

    st_global("_inei_encoded", result)
}
end
