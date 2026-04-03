*! inei_cite.ado — Generar cita bibliografica para datos INEI
*! version 1.0.0  2026-04-03

program define inei_cite
    version 14.0
    syntax , SURVEY(string) YEAR(integer) [FORMAT(string)]

    if "`format'" == "" local format "apa"
    local format = strlower("`format'")

    * Resolver nombre completo de encuesta
    _inei_cat_resolve_alias `survey'
    local survey_name "`s(resolved)'"

    * Buscar nombre largo en catalogo
    preserve
    capture {
        _inei_cat_load
        _inei_cat_filter, survey(`survey') yearmin(`year') yearmax(`year')
        local full_name = survey_label[1]
    }
    restore

    if "`full_name'" == "" local full_name "`survey_name'"

    local url "https://proyectos.inei.gob.pe/microdatos/"

    di as text ""

    if "`format'" == "apa" {
        di as text "{bf:Cita APA:}"
        di as text ""
        di as result `"Instituto Nacional de Estadistica e Informatica (INEI). (`year'). `full_name' [Base de datos]. `url'"'
    }
    else if "`format'" == "bibtex" {
        local key = strlower("`survey_name'")
        local key = subinstr("`key'", " ", "_", .)
        di as text "{bf:BibTeX:}"
        di as text ""
        di as result "@misc{inei_`key'_`year',"
        di as result "  author = {{Instituto Nacional de Estadistica e Informatica (INEI)}},"
        di as result "  title  = {`full_name'},"
        di as result "  year   = {`year'},"
        di as result "  note   = {Base de datos},"
        di as result "  url    = {`url'}"
        di as result "}"
    }
    else if "`format'" == "text" {
        di as text "{bf:Referencia:}"
        di as text ""
        di as result "INEI (`year'). `full_name'. Portal de Microdatos: `url'"
    }
    else {
        di as error "Formato no reconocido: `format'"
        di as text "Formatos disponibles: apa, bibtex, text"
        exit 198
    }

    di as text ""
end
