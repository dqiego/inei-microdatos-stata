*! _inei_display_wrapped.ado — Mostrar texto con word-wrap
*! Usa scalar strings para evitar problemas con caracteres especiales
*! Uso: global __inei_wrap_text "texto largo aqui"
*!      _inei_display_wrapped "      " 72
*! version 1.0.4  2026-04-02

program define _inei_display_wrapped
    args prefix maxwidth

    if "`maxwidth'" == "" local maxwidth 72

    * Leer texto de la global via scalar (evita problemas con chars especiales)
    scalar __inei_wtxt = "${__inei_wrap_text}"
    macro drop __inei_wrap_text

    if scalar(__inei_wtxt) == "" {
        scalar drop __inei_wtxt
        exit
    }

    local prefix_len = strlen("`prefix'")
    local line_len = `maxwidth' - `prefix_len'
    if `line_len' < 20 local line_len 20

    local total_len = strlen(scalar(__inei_wtxt))

    if `total_len' <= `line_len' {
        * Cabe en una linea — mostrar via scalar
        scalar __inei_wline = "`prefix'" + scalar(__inei_wtxt)
        di as text scalar(__inei_wline)
        scalar drop __inei_wtxt __inei_wline
        exit
    }

    * Word-wrap: partir en lineas
    local pos = 1
    while `pos' <= `total_len' {
        local chars_left = `total_len' - `pos' + 1

        if `chars_left' <= `line_len' {
            * Ultima linea
            scalar __inei_wline = "`prefix'" + substr(scalar(__inei_wtxt), `pos', .)
            di as text scalar(__inei_wline)
            local pos = `total_len' + 1
        }
        else {
            * Buscar ultimo espacio dentro del rango
            local break_pos = `line_len'
            forvalues j = `line_len'(-1)1 {
                local ch = substr(scalar(__inei_wtxt), `pos' + `j' - 1, 1)
                if "`ch'" == " " {
                    local break_pos = `j'
                    continue, break
                }
            }

            scalar __inei_wline = "`prefix'" + substr(scalar(__inei_wtxt), `pos', `break_pos')
            di as text scalar(__inei_wline)
            local pos = `pos' + `break_pos'

            * Saltar espacios al inicio de la siguiente linea
            while `pos' <= `total_len' {
                local ch = substr(scalar(__inei_wtxt), `pos', 1)
                if "`ch'" != " " {
                    continue, break
                }
                local pos = `pos' + 1
            }
        }
    }

    capture scalar drop __inei_wtxt
    capture scalar drop __inei_wline
end
