*! _inei_cat_resolve_alias.ado — Resolver alias de encuesta a nombre completo
*! version 1.0.1  2026-04-02

program define _inei_cat_resolve_alias, sclass
    args alias_input

    local alias_lower = strlower("`alias_input'")

    if "`alias_lower'" == "enaho" {
        sreturn local resolved "ENAHO"
    }
    else if "`alias_lower'" == "endes" {
        sreturn local resolved "ENDES"
    }
    else if "`alias_lower'" == "epen" {
        sreturn local resolved "EPEN"
    }
    else if "`alias_lower'" == "cenagro" {
        sreturn local resolved "CENAGRO"
    }
    else if "`alias_lower'" == "eea" {
        sreturn local resolved "EEA"
    }
    else if "`alias_lower'" == "enapres" {
        sreturn local resolved "ENAPRES"
    }
    else if "`alias_lower'" == "enaho_anterior" | "`alias_lower'" == "enaho-anterior" {
        sreturn local resolved "ENAHO Anterior"
    }
    else if "`alias_lower'" == "enaho_actualizada" | "`alias_lower'" == "enaho-actualizada" {
        sreturn local resolved "ENAHO Actualizada"
    }
    else if "`alias_lower'" == "censo" {
        sreturn local resolved "Censo"
    }
    else if "`alias_lower'" == "sisfoh" {
        sreturn local resolved "SISFOH"
    }
    else if "`alias_lower'" == "enh" {
        sreturn local resolved "ENH"
    }
    else if "`alias_lower'" == "enacom" {
        sreturn local resolved "ENACOM"
    }
    else if "`alias_lower'" == "enahur" {
        sreturn local resolved "ENAHUR"
    }
    else if "`alias_lower'" == "enniv" {
        sreturn local resolved "ENNIV"
    }
    else if "`alias_lower'" == "enssa" {
        sreturn local resolved "ENSSA"
    }
    else if "`alias_lower'" == "enesem" {
        sreturn local resolved "ENESEM"
    }
    else {
        sreturn local resolved "`alias_input'"
    }
end
