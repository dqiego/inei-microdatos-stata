*! _inei_find_data_dir.ado — Encontrar directorio de datos del paquete
*! version 1.0.4  2026-04-02
*! Los CSV se instalan junto a los .ado (no en subdirectorio data/)

program define _inei_find_data_dir, sclass

    * Estrategia 1: buscar junto al .ado instalado (mismo directorio)
    capture findfile inei_catalog.csv
    if _rc == 0 {
        local found "`r(fn)'"
        mata: _inei_get_parent_dir("`found'")
        local dir "${__inei_pdir}"
        macro drop __inei_pdir
        sreturn local datadir "`dir'"
        exit
    }

    capture findfile inei_catalog.dta
    if _rc == 0 {
        local found "`r(fn)'"
        mata: _inei_get_parent_dir("`found'")
        local dir "${__inei_pdir}"
        macro drop __inei_pdir
        sreturn local datadir "`dir'"
        exit
    }

    * Estrategia 2: buscar en subdirectorio data/ junto al .ado
    capture findfile inei.ado
    if _rc == 0 {
        local ado_path "`r(fn)'"
        mata: _inei_get_parent_dir("`ado_path'")
        local ado_dir "${__inei_pdir}"
        macro drop __inei_pdir

        foreach subdir in "" "/data" {
            local trydir "`ado_dir'`subdir'"
            capture confirm file "`trydir'/inei_catalog.csv"
            if _rc == 0 {
                sreturn local datadir "`trydir'"
                exit
            }
            capture confirm file "`trydir'/inei_catalog.dta"
            if _rc == 0 {
                sreturn local datadir "`trydir'"
                exit
            }
        }
    }

    * Estrategia 3: directorio actual
    capture confirm file "inei_catalog.csv"
    if _rc == 0 {
        sreturn local datadir "."
        exit
    }
    capture confirm file "data/inei_catalog.csv"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }

    * No encontrado
    sreturn local datadir "."
end

mata:
void _inei_get_parent_dir(string scalar filepath)
{
    string scalar dir
    real scalar i, last_sep

    dir = subinstr(filepath, "\", "/")

    last_sep = 0
    for (i = strlen(dir); i >= 1; i--) {
        if (substr(dir, i, 1) == "/") {
            last_sep = i
            break
        }
    }

    if (last_sep > 1) {
        dir = substr(dir, 1, last_sep - 1)
    }

    st_global("__inei_pdir", dir)
}
end
