*! _inei_load_variables.ado — Cargar indice de variables (.dta o CSV)
*! version 1.0.1  2026-04-02

program define _inei_load_variables
    _inei_find_data_dir
    local datadir "`s(datadir)'"

    * Intentar .dta primero
    capture confirm file "`datadir'/inei_variables.dta"
    if _rc == 0 {
        use "`datadir'/inei_variables.dta", clear
        exit
    }

    * Importar CSV (primera vez, sera lento con 525k filas)
    local csv_path "`datadir'/inei_variables.csv"
    capture confirm file "`csv_path'"
    if _rc == 0 {
        di as text "Importando indice de variables (primera vez, esto tomara un momento)..."
        import delimited using "`csv_path'", clear encoding("utf-8") ///
            stringcols(_all)
        compress
        di as text "Guardando como .dta para futuras busquedas..."
        save "`datadir'/inei_variables.dta", replace
        di as text "Listo."
        exit
    }

    di as error "No se encontro indice de variables."
    di as error "Necesita los archivos de datos en: `datadir'/"
    exit 601
end
