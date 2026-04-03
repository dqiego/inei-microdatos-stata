*! inei_aliases.ado — Mostrar aliases cortos para encuestas INEI
*! version 1.0.0  2026-04-02

program define inei_aliases
    version 14.0

    di as text ""
    di as text "{bf:Aliases de encuestas INEI}"
    di as text "{hline 55}"
    di as text %~20s "Alias" " " %~30s "Encuesta"
    di as text "{hline 55}"

    _inei_alias_row "enaho"              "ENAHO (ambas metodologias)"
    _inei_alias_row "enaho_anterior"     "ENAHO Anterior (1997-2003)"
    _inei_alias_row "enaho_actualizada"  "ENAHO Actualizada (2004+)"
    _inei_alias_row "endes"              "ENDES"
    _inei_alias_row "epen"               "EPEN"
    _inei_alias_row "cenagro"            "CENAGRO"
    _inei_alias_row "eea"                "EEA"
    _inei_alias_row "enapres"            "ENAPRES"
    _inei_alias_row "censo"              "Censos Nacionales"
    _inei_alias_row "sisfoh"             "SISFOH"
    _inei_alias_row "enh"                "ENH"
    _inei_alias_row "enacom"             "ENACOM"
    _inei_alias_row "enahur"             "ENAHUR"
    _inei_alias_row "enniv"              "ENNIV"
    _inei_alias_row "enssa"              "ENSSA"
    _inei_alias_row "enesem"             "ENESEM"

    di as text "{hline 55}"
    di as text ""
    di as text "Uso: inei list, survey(enaho)"
    di as text "     inei download, survey(endes) yearmin(2020)"
    di as text ""
end

program define _inei_alias_row
    args alias fullname

    di as result %~20s "`alias'" " " as text %~30s "`fullname'"
end
