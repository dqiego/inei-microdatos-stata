*! _inei_load_variables.ado — Cargar indice de variables (.dta o CSV)
*! Si no existe localmente, lo descarga desde GitHub
*! version 1.0.3  2026-04-02

program define _inei_load_variables
    * Buscar donde estan los demas archivos de datos
    _inei_find_data_dir
    local datadir "`s(datadir)'"

    * Intentar .dta primero (mas rapido)
    capture confirm file "`datadir'/inei_variables.dta"
    if _rc == 0 {
        use "`datadir'/inei_variables.dta", clear
        exit
    }

    * Intentar CSV local
    capture confirm file "`datadir'/inei_variables.csv"
    if _rc == 0 {
        di as text "Importando indice de variables (primera vez, esto tomara un momento)..."
        import delimited using "`datadir'/inei_variables.csv", clear ///
            encoding("utf-8") stringcols(_all)
        compress
        di as text "Guardando como .dta para futuras busquedas..."
        save "`datadir'/inei_variables.dta", replace
        di as text "Listo."
        exit
    }

    * No existe localmente — descargar desde GitHub
    di as text ""
    di as text "El indice de variables (525,000+) no esta instalado."
    di as text "Descargando desde GitHub (98 MB, puede tomar unos minutos)..."
    di as text ""

    local url "https://raw.githubusercontent.com/dqiego/inei-microdatos-stata/master/inei_variables.csv"
    local dest_csv "`datadir'/inei_variables.csv"

    * Intentar con copy de Stata
    capture copy "`url'" "`dest_csv'", replace
    if _rc != 0 {
        * Fallback a curl
        di as text "Intentando con curl..."
        quietly ! curl -s -k -L --max-time 300 -o "`dest_csv'" "`url'"
    }

    capture confirm file "`dest_csv'"
    if _rc != 0 {
        di as error "Error: no se pudo descargar el indice de variables"
        di as error "Descargue manualmente desde:"
        di as error "  `url'"
        di as error "y copie a: `datadir'/"
        exit 601
    }

    * Verificar que no esta vacio
    qui checksum "`dest_csv'"
    if r(filelen) < 1000 {
        di as error "Error: archivo descargado parece estar vacio o corrupto"
        capture erase "`dest_csv'"
        exit 601
    }

    di as text "Descarga completa. Importando..."
    import delimited using "`dest_csv'", clear encoding("utf-8") stringcols(_all)
    compress
    di as text "Guardando como .dta para futuras busquedas..."
    save "`datadir'/inei_variables.dta", replace
    di as text "Listo. Indice de variables instalado."
end
