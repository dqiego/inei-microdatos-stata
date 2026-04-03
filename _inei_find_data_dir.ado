*! _inei_find_data_dir.ado — Encontrar directorio de datos del paquete
*! version 1.0.1  2026-04-02

program define _inei_find_data_dir, sclass
    * Buscar en adopath junto al .ado
    capture findfile inei.ado
    if _rc == 0 {
        local ado_path "`r(fn)'"
        local datadir = subinstr("`ado_path'", "inei.ado", "data", 1)

        capture confirm file "`datadir'/inei_catalog.dta"
        if _rc == 0 {
            sreturn local datadir "`datadir'"
            exit
        }
        capture confirm file "`datadir'/inei_catalog.csv"
        if _rc == 0 {
            sreturn local datadir "`datadir'"
            exit
        }
    }

    * Fallback: directorio actual
    capture confirm file "data/inei_catalog.dta"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }
    capture confirm file "data/inei_catalog.csv"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }

    * Fallback: directorio de usuario
    local userdir "~/.inei-microdatos"
    capture confirm file "`userdir'/inei_catalog.dta"
    if _rc == 0 {
        sreturn local datadir "`userdir'"
        exit
    }

    * No encontrado — devolver default
    sreturn local datadir "data"
end
