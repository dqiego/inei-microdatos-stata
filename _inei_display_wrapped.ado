*! _inei_display_wrapped.ado — Mostrar texto con word-wrap
*! version 1.0.0  2026-04-02

program define _inei_display_wrapped
    args prefix text maxwidth

    if "`maxwidth'" == "" local maxwidth 70

    local prefix_len = strlen("`prefix'")
    local line_len = `maxwidth' - `prefix_len'

    if `line_len' < 20 local line_len 20

    * Si cabe en una linea, mostrar directo
    if strlen("`text'") <= `line_len' {
        di as text "`prefix'`text'"
        exit
    }

    * Word-wrap: partir en lineas
    local remaining "`text'"
    local first 1

    while strlen("`remaining'") > 0 {
        if strlen("`remaining'") <= `line_len' {
            if `first' {
                di as text "`prefix'`remaining'"
            }
            else {
                di as text "`prefix'`remaining'"
            }
            local remaining ""
        }
        else {
            * Buscar ultimo espacio antes del limite
            local chunk = substr("`remaining'", 1, `line_len')
            local break_pos = `line_len'

            * Buscar ultimo espacio en el chunk
            forvalues j = `line_len'(-1)1 {
                if substr("`chunk'", `j', 1) == " " {
                    local break_pos = `j'
                    continue, break
                }
            }

            local line = substr("`remaining'", 1, `break_pos')
            local remaining = strtrim(substr("`remaining'", `break_pos' + 1, .))

            di as text "`prefix'`line'"
        }
        local first 0
    }
end
