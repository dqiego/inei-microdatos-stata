*! _inei_display_wrapped.ado — Mostrar texto con word-wrap
*! Uso: global __inei_wrap_text "texto largo aqui"
*!      _inei_display_wrapped "      " 72
*! version 1.0.2  2026-04-02

program define _inei_display_wrapped
    args prefix maxwidth

    if "`maxwidth'" == "" local maxwidth 72

    * Leer texto de la global
    local text "${__inei_wrap_text}"
    macro drop __inei_wrap_text

    if "`text'" == "" exit

    local prefix_len = strlen("`prefix'")
    local line_len = `maxwidth' - `prefix_len'
    if `line_len' < 20 local line_len 20

    * Si cabe en una linea
    if strlen(`"`text'"') <= `line_len' {
        di as text `"`prefix'`text'"'
        exit
    }

    * Word-wrap con Mata (mas robusto para strings largos)
    mata: _inei_do_wrap(st_local("prefix"), st_local("text"), ///
        strtoreal(st_local("line_len")))
end

mata:
void _inei_do_wrap(string scalar prefix, string scalar text,
                   real scalar line_len)
{
    string scalar remaining, chunk, line
    real scalar break_pos, i

    remaining = text

    while (strlen(remaining) > 0) {
        if (strlen(remaining) <= line_len) {
            printf("{txt}%s%s\n", prefix, remaining)
            remaining = ""
        }
        else {
            chunk = substr(remaining, 1, line_len)

            // Buscar ultimo espacio
            break_pos = line_len
            for (i = line_len; i >= 1; i--) {
                if (substr(chunk, i, 1) == " ") {
                    break_pos = i
                    break
                }
            }

            line = substr(remaining, 1, break_pos)
            remaining = strtrim(substr(remaining, break_pos + 1, .))

            printf("{txt}%s%s\n", prefix, line)
        }
    }
}
end
