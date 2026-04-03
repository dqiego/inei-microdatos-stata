*! _inei_find_data_dir.ado — Encontrar directorio de datos del paquete
*! version 1.0.3  2026-04-02

program define _inei_find_data_dir, sclass

    * Estrategia 1: buscar junto al .ado instalado
    capture findfile inei.ado
    if _rc == 0 {
        local ado_path "`r(fn)'"
        mata: _inei_get_parent_dir(st_local("ado_path"))
        local ado_dir "`__inei_pdir'"
        macro drop __inei_pdir

        local datadir "`ado_dir'/data"

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

    * Estrategia 2: buscar en PLUS/data/ subdirectories
    local plus_dir "`c(sysdir_plus)'"
    foreach subdir in "i/data" "data" "_i/data" {
        local trydir "`plus_dir'`subdir'"
        capture confirm file "`trydir'/inei_catalog.dta"
        if _rc == 0 {
            sreturn local datadir "`trydir'"
            exit
        }
        capture confirm file "`trydir'/inei_catalog.csv"
        if _rc == 0 {
            sreturn local datadir "`trydir'"
            exit
        }
    }

    * Estrategia 3: buscar con findfile directamente
    capture findfile inei_catalog.dta
    if _rc == 0 {
        mata: _inei_get_parent_dir("`r(fn)'")
        local found_dir "`__inei_pdir'"
        macro drop __inei_pdir
        sreturn local datadir "`found_dir'"
        exit
    }
    capture findfile inei_catalog.csv
    if _rc == 0 {
        mata: _inei_get_parent_dir("`r(fn)'")
        local found_dir "`__inei_pdir'"
        macro drop __inei_pdir
        sreturn local datadir "`found_dir'"
        exit
    }

    * Estrategia 4: directorio actual
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

    sreturn local datadir "data"
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
