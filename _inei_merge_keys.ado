*! _inei_merge_keys.ado — Determinar keys de merge para encuestas INEI
*! Detecta automaticamente si es merge a nivel hogar o individuo
*! version 1.0.0  2026-04-03

program define _inei_merge_keys, sclass
    syntax , [SURVEY(string) ON(string)]

    * Si el usuario especifico keys, usar esos
    if "`on'" != "" {
        sreturn local keys "`on'"
        sreturn local level "custom"
        exit
    }

    * Resolver alias
    if "`survey'" != "" {
        _inei_cat_resolve_alias `survey'
        local survey_resolved = strlower("`s(resolved)'")
    }

    * Keys por defecto segun encuesta
    if strpos("`survey_resolved'", "enaho") > 0 {
        * ENAHO: detectar nivel segun variables presentes
        capture confirm variable codperso
        if _rc == 0 {
            * Tiene codperso -> nivel individuo
            sreturn local keys "conglome vivienda hogar codperso"
            sreturn local level "individuo"
        }
        else {
            * Sin codperso -> nivel hogar
            sreturn local keys "conglome vivienda hogar"
            sreturn local level "hogar"
        }
    }
    else if strpos("`survey_resolved'", "endes") > 0 {
        capture confirm variable caseid
        if _rc == 0 {
            sreturn local keys "caseid"
            sreturn local level "caso"
        }
        else {
            sreturn local keys "hhid"
            sreturn local level "hogar"
        }
    }
    else if strpos("`survey_resolved'", "epen") > 0 {
        capture confirm variable codperso
        if _rc == 0 {
            sreturn local keys "conglome vivienda hogar codperso"
            sreturn local level "individuo"
        }
        else {
            sreturn local keys "conglome vivienda hogar"
            sreturn local level "hogar"
        }
    }
    else {
        * Encuesta desconocida: intentar detectar keys comunes
        local found_keys ""
        foreach v in conglome vivienda hogar codperso {
            capture confirm variable `v'
            if _rc == 0 {
                local found_keys "`found_keys' `v'"
            }
        }

        if "`found_keys'" != "" {
            sreturn local keys "`found_keys'"
            sreturn local level "auto"
        }
        else {
            di as error "No se pudieron detectar keys de merge automaticamente"
            di as error "Use la opcion {bf:on(var1 var2 ...)} para especificarlos"
            exit 198
        }
    }
end
