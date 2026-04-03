*! inei_list.ado — Listar encuestas y modulos disponibles del INEI
*! version 1.0.3  2026-04-03

program define inei_list
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        PERIOD(string) MODULES CATALOG(string)]

    preserve

    _inei_catalog_utils load, catalog(`catalog')
    _inei_catalog_utils filter, survey(`survey') yearmin(`yearmin') ///
        yearmax(`yearmax') period(`period')

    if "`modules'" != "" {
        _inei_list_modules
    }
    else {
        _inei_list_surveys
    }

    restore
end

program define _inei_list_surveys
    qui collapse (min) year_min=year (max) year_max=year ///
        (count) n_modules=year, by(category survey_label)

    qui sort category year_min

    di as text ""
    di as text "{bf:Encuestas disponibles}"
    di as text ""

    mata: _inei_show_surveys()

    di as text ""
    di as text "{hline 65}"
    di as text "  Total: " as result _N as text " encuestas"
    di as text ""
end

program define _inei_list_modules
    qui sort category year period module_name

    di as text ""
    di as text "{bf:Modulos disponibles}"
    di as text ""

    mata: _inei_show_modules()

    di as text ""
    di as text "{hline 65}"
    di as text "  Total: " as result _N as text " modulos"
    di as text ""
end

mata:
void _inei_show_surveys()
{
    real scalar i, n, ymin, ymax, nmod
    string scalar cat, lab, prev_cat

    n = st_nobs()
    prev_cat = ""

    for (i = 1; i <= n; i++) {
        cat  = st_sdata(i, "category")
        lab  = st_sdata(i, "survey_label")
        ymin = st_data(i, "year_min")
        ymax = st_data(i, "year_max")
        nmod = st_data(i, "n_modules")

        if (cat != prev_cat) {
            if (prev_cat != "") printf("\n")
            printf("  %s\n", cat)
            printf("  -----------------------------------------------------------------\n")
        }
        prev_cat = cat

        // Word-wrap del label
        _inei_print_wrapped(lab, "    ", 65)

        printf("      %g-%g  |  %g modulos\n", ymin, ymax, nmod)
    }
}

void _inei_show_modules()
{
    real scalar i, n, yr, prev_year
    string scalar cat, per, mname, scode, prev_cat

    n = st_nobs()
    prev_cat = ""
    prev_year = .

    for (i = 1; i <= n; i++) {
        cat   = st_sdata(i, "category")
        yr    = st_data(i, "year")
        per   = st_sdata(i, "period")
        mname = st_sdata(i, "module_name")
        scode = st_sdata(i, "stata_code")

        if (cat != prev_cat) {
            if (prev_cat != "") printf("\n")
            printf("  %s\n", cat)
            printf("  -----------------------------------------------------------------\n")
            prev_year = .
        }
        prev_cat = cat

        if (yr != prev_year) {
            printf("\n    %g - %s\n", yr, per)
        }
        prev_year = yr

        // Truncar nombre de modulo
        if (strlen(mname) > 45) {
            mname = substr(mname, 1, 42) + "..."
        }

        printf("      %s  [%s]\n", mname, scode)
    }
}

void _inei_print_wrapped(string scalar text, string scalar prefix,
    real scalar maxwidth)
{
    string scalar remaining, chunk, line
    real scalar line_len, break_pos, j

    if (text == "") return

    line_len = maxwidth - strlen(prefix)
    if (line_len < 20) line_len = 20

    remaining = text

    while (strlen(remaining) > 0) {
        if (strlen(remaining) <= line_len) {
            printf("%s%s\n", prefix, remaining)
            remaining = ""
        }
        else {
            chunk = substr(remaining, 1, line_len)
            break_pos = line_len

            for (j = line_len; j >= 1; j--) {
                if (substr(chunk, j, 1) == " ") {
                    break_pos = j
                    break
                }
            }

            line = substr(remaining, 1, break_pos)
            remaining = strtrim(substr(remaining, break_pos + 1, .))
            printf("%s%s\n", prefix, line)
        }
    }
}
end
