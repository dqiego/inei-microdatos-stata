*! _inei_encode.ado — JS-style URL encoding para portal INEI
*! El portal INEI usa JavaScript escape() encoding, NO percent-encoding UTF-8
*! Caracteres <= 0xFF → %XX, caracteres > 0xFF → %uXXXX
*! version 1.0.0  2026-04-02

program define _inei_encode, sclass
    version 14.0
    syntax anything(name=input_str)

    * Quitar comillas externas si las hay
    local input_str = `input_str'

    mata: _inei_js_escape(`"`input_str'"')

    sreturn local encoded "${_inei_encoded}"
    macro drop _inei_encoded
end

/*
    Mata implementation of JavaScript-style escape()
    - Alphanumeric + @*_+-./ and space → pass through
    - Characters with codepoint <= 0xFF → %XX
    - Characters with codepoint > 0xFF → %uXXXX
*/
mata:
void _inei_js_escape(string scalar s)
{
    string scalar result, ch, hex
    real scalar i, n, cp

    result = ""
    n = ustrlen(s)

    for (i = 1; i <= n; i++) {
        ch = usubstr(s, i, 1)
        cp = ustrtoascii(ch, 1)

        // Alphanumeric and safe chars pass through
        if ((cp >= 65 & cp <= 90) |   /* A-Z */
            (cp >= 97 & cp <= 122) |  /* a-z */
            (cp >= 48 & cp <= 57) |   /* 0-9 */
            cp == 64 |  /* @ */
            cp == 42 |  /* * */
            cp == 95 |  /* _ */
            cp == 43 |  /* + */
            cp == 45 |  /* - */
            cp == 46 |  /* . */
            cp == 47 |  /* / */
            cp == 32)   /* space */ {
            result = result + ch
        }
        else if (cp <= 255) {
            // %XX format for chars <= 0xFF
            hex = strupper(inbase(16, cp))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
        }
        else {
            // %uXXXX format for chars > 0xFF
            hex = strupper(inbase(16, cp))
            while (strlen(hex) < 4) hex = "0" + hex
            result = result + "%u" + hex
        }
    }

    st_global("_inei_encoded", result)
}
end
