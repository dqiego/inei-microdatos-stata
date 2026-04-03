*! inei_describe.ado — Ver variables de un modulo sin descargar
*! Usa el indice pre-construido de 525k+ variables
*! version 1.0.0  2026-04-03

program define inei_describe
    version 14.0
    syntax , SURVEY(string) YEAR(integer) MODULE(string)

    preserve

    _inei_load_variables

    * Filtrar por encuesta
    _inei_cat_resolve_alias `survey'
    local survey_resolved "`s(resolved)'"
    local sv_lower = strlower("`survey_resolved'")
    qui gen __smatch = strpos(strlower(survey), "`sv_lower'") > 0 | ///
                       strpos(strlower(category), "`sv_lower'") > 0
    qui keep if __smatch == 1
    qui drop __smatch

    * Filtrar por anio
    qui destring year, replace force
    qui keep if year == `year'

    * Filtrar por modulo
    local mod_lower = strlower("`module'")
    qui gen __mmatch = strlower(module_code) == "`mod_lower'" | ///
                       strpos(strlower(module_name), "`mod_lower'") > 0
    qui keep if __mmatch == 1
    qui drop __mmatch

    qui count
    local n_vars = r(N)

    if `n_vars' == 0 {
        di as text ""
        di as text "No se encontraron variables para: `survey' `year' modulo `module'"
        di as text ""
        di as text "Sugerencias:"
        di as text "  - Verifique el codigo de modulo con: inei list, survey(`survey') yearmin(`year') modules"
        di as text "  - El modulo puede no estar indexado"
        restore
        exit
    }

    * Obtener nombre del modulo
    local mod_name = module_name[1]

    sort var_name

    * Mostrar con Mata
    di as text ""
    di as text "{bf:`survey' `year' - `mod_name'}"
    di as text "  Variables: " as result "`n_vars'"
    di as text ""
    di as text "  {hline 65}"

    mata: _inei_show_describe()

    di as text "  {hline 65}"
    di as text ""
    di as text "  Cargar: {bf:inei use, survey(`survey') year(`year') module(`module') clear}"
    di as text ""

    restore
end

mata:
void _inei_show_describe()
{
    real scalar i, n
    string scalar vname, vlabel

    n = st_nobs()
    for (i = 1; i <= n; i++) {
        vname = st_sdata(i, "var_name")
        vlabel = st_sdata(i, "var_label")

        if (strlen(vlabel) > 50) {
            vlabel = substr(vlabel, 1, 47) + "..."
        }

        printf("  %-15s %s\n", vname, vlabel)
    }
}
end
