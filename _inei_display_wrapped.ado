*! _inei_display_wrapped.ado — Mostrar texto con word-wrap
*! Uso: global __inei_wrap_text "texto largo aqui"
*!      _inei_display_wrapped "      " 72
*! version 1.0.3  2026-04-02

program define _inei_display_wrapped
    args prefix maxwidth

    if "`maxwidth'" == "" local maxwidth 72

    local text "${__inei_wrap_text}"
    macro drop __inei_wrap_text

    if `"`text'"' == "" exit

    local prefix_len = strlen("`prefix'")
    local line_len = `maxwidth' - `prefix_len'
    if `line_len' < 20 local line_len 20

    * Word-wrap en Stata puro
    local remaining `"`text'"'

    while `"`remaining'"' != "" {
        if strlen(`"`remaining'"') <= `line_len' {
            di as text `"`prefix'`remaining'"'
            local remaining ""
        }
        else {
            * Tomar chunk del largo maximo
            local chunk = substr(`"`remaining'"', 1, `line_len')

            * Buscar ultimo espacio
            local break_pos = `line_len'
            forvalues j = `line_len'(-1)1 {
                if substr("`chunk'", `j', 1) == " " {
                    local break_pos = `j'
                    continue, break
                }
            }

            local line = substr(`"`remaining'"', 1, `break_pos')
            local remaining = strtrim(substr(`"`remaining'"', `break_pos' + 1, .))

            di as text `"`prefix'`line'"'
        }
    }
end
