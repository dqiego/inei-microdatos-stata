*! _inei_mkdir_p.ado — Crear directorios recursivamente (mkdir -p)
*! version 1.0.1  2026-04-02

program define _inei_mkdir_p
    args path

    local path = subinstr("`path'", "\", "/", .)

    local current ""
    tokenize "`path'", parse("/")
    while "`1'" != "" {
        if "`1'" != "/" {
            if "`current'" == "" {
                local current "`1'"
            }
            else {
                local current "`current'/`1'"
            }
            capture mkdir "`current'"
        }
        macro shift
    }
end
