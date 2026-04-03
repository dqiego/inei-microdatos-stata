*! inei.ado — Comando principal para acceder a microdatos del INEI
*! Paquete Stata para descargar, buscar y gestionar microdatos de Peru
*! Basado en inei-microdatos (Python) de fiorellarmartins
*! version 1.0.0  2026-04-02
*! MIT License

program define inei
    version 14.0

    * Extraer subcomando (primer argumento)
    * Parsear con coma: "inei list, survey(x)" -> subcmd="list" rest=", survey(x)"
    gettoken subcmd 0 : 0, parse(" ,")

    if "`subcmd'" == "" {
        _inei_help
        exit
    }

    * Convertir a minusculas
    local subcmd = strlower("`subcmd'")

    * Dispatcher — pasar el resto incluyendo la coma
    if "`subcmd'" == "list" {
        inei_list `0'
    }
    else if "`subcmd'" == "download" {
        inei_download `0'
    }
    else if "`subcmd'" == "docs" {
        inei_docs `0'
    }
    else if "`subcmd'" == "search" {
        inei_search `0'
    }
    else if "`subcmd'" == "track" {
        inei_track `0'
    }
    else if "`subcmd'" == "crawl" {
        inei_crawl `0'
    }
    else if "`subcmd'" == "aliases" {
        inei_aliases `0'
    }
    else if "`subcmd'" == "stats" {
        inei_stats `0'
    }
    else if "`subcmd'" == "help" {
        _inei_help
    }
    else {
        di as error `"inei: subcomando desconocido '`subcmd''"'
        di as text ""
        _inei_help
        exit 198
    }
end

program define _inei_help
    di as text ""
    di as text "{bf:inei} - Acceso a microdatos del INEI (Peru)"
    di as text "{hline 55}"
    di as text ""
    di as text "  {bf:Comandos disponibles:}"
    di as text ""
    di as text "    {bf:inei list}      Listar encuestas y modulos disponibles"
    di as text "    {bf:inei download}  Descargar microdatos"
    di as text "    {bf:inei docs}      Descargar documentacion"
    di as text "    {bf:inei search}    Buscar variables en el indice"
    di as text "    {bf:inei track}     Seguir variable entre anios"
    di as text "    {bf:inei crawl}     Actualizar catalogo desde el portal"
    di as text "    {bf:inei aliases}   Mostrar aliases de encuestas"
    di as text "    {bf:inei stats}     Estadisticas del catalogo"
    di as text ""
    di as text "  {bf:Ejemplos:}"
    di as text ""
    di as text "    inei list"
    di as text "    inei list, survey(enaho) yearmin(2020)"
    di as text "    inei download, survey(enaho) yearmin(2024) format(STATA)"
    di as text "    inei search {c 34}ingreso neto{c 34}"
    di as text "    inei track P208, survey(enaho)"
    di as text ""
    di as text "  Para mas informacion: {bf:help inei}"
    di as text ""
end
