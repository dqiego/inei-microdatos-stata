*! _inei_cat_filter.ado — Filtrar catalogo INEI ya cargado en memoria
*! version 1.0.1  2026-04-02

program define _inei_cat_filter
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        PERIOD(string)]

    * Resolver alias de encuesta
    if "`survey'" != "" {
        _inei_cat_resolve_alias `survey'
        local survey "`s(resolved)'"

        local survey_lower = strlower("`survey'")
        qui gen __match = strpos(strlower(category), "`survey_lower'") > 0 | ///
                      strpos(strlower(survey_label), "`survey_lower'") > 0
        qui keep if __match == 1
        qui drop __match

        if _N == 0 {
            di as error "No se encontro encuesta: `survey'"
            exit 111
        }
    }

    if `yearmin' > 0 {
        qui keep if year >= `yearmin'
    }
    if `yearmax' < 9999 {
        qui keep if year <= `yearmax'
    }

    if "`period'" != "" {
        local period_lower = strlower("`period'")
        qui gen __pmatch = strpos(strlower(period), "`period_lower'") > 0
        qui keep if __pmatch == 1
        qui drop __pmatch
    }

    if _N == 0 {
        di as error "No se encontraron resultados con los filtros especificados"
        exit 111
    }
end
