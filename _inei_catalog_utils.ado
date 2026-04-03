*! _inei_catalog_utils.ado — Dispatcher para utilidades de catalogo INEI
*! version 1.0.1  2026-04-02

program define _inei_catalog_utils
    version 14.0
    syntax anything(name=action), [SURVEY(string) YEARMIN(integer 0) ///
        YEARMAX(integer 9999) PERIOD(string) CATALOG(string)]

    local action "`action'"

    if "`action'" == "load" {
        _inei_cat_load, catalog(`catalog')
    }
    else if "`action'" == "filter" {
        _inei_cat_filter, survey(`survey') yearmin(`yearmin') ///
            yearmax(`yearmax') period(`period')
    }
    else if "`action'" == "resolve_alias" {
        _inei_cat_resolve_alias `survey'
    }
    else {
        di as error "_inei_catalog_utils: accion desconocida '`action''"
        exit 198
    }
end
