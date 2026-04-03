*! _inei_cat_load.ado — Cargar catalogo .dta o importar desde CSV
*! version 1.0.1  2026-04-02

program define _inei_cat_load
    syntax , [CATALOG(string)]

    if "`catalog'" == "" {
        _inei_find_data_dir
        local datadir "`s(datadir)'"
        local catalog "`datadir'/inei_catalog.dta"
    }

    * Si existe .dta, cargar directamente
    capture confirm file "`catalog'"
    if _rc == 0 {
        use "`catalog'", clear
        exit
    }

    * Si no existe .dta, buscar CSV e importar
    local csv_path = subinstr("`catalog'", ".dta", ".csv", 1)
    capture confirm file "`csv_path'"
    if _rc == 0 {
        di as text "Importando catalogo desde CSV (primera vez)..."
        import delimited using "`csv_path'", clear encoding("utf-8") ///
            stringcols(_all)
        destring year, replace
        compress
        save "`catalog'", replace
        di as text "Catalogo guardado como .dta para futuras cargas"
        exit
    }

    di as error "No se encontro catalogo. Ejecute: inei crawl"
    exit 601
end
