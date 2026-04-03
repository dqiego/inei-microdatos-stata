*! _inei_display_wrapped.ado — Mostrar texto con word-wrap
*! Lee directamente de una variable Stata en la obs especificada
*! Uso: _inei_display_wrapped varname obs_num prefix maxwidth
*! version 1.0.5  2026-04-02

program define _inei_display_wrapped
    args varname obsnum prefix maxwidth

    if "`maxwidth'" == "" local maxwidth 72
    if "`prefix'" == "" local prefix ""

    mata: _inei_do_display_wrap("`varname'", strtoreal("`obsnum'"), ///
        "`prefix'", strtoreal("`maxwidth'"))
end

* Overload: mostrar un scalar directamente
program define _inei_display_wrapped_scalar
    args scalarname prefix maxwidth

    if "`maxwidth'" == "" local maxwidth 72
    if "`prefix'" == "" local prefix ""

    mata: _inei_do_display_wrap_str(st_strscalar("`scalarname'"), ///
        "`prefix'", strtoreal("`maxwidth'"))
end

mata:
void _inei_do_display_wrap(string scalar varname, real scalar obsnum,
    string scalar prefix, real scalar maxwidth)
{
    string scalar text

    text = st_sdata(obsnum, varname)
    _inei_do_display_wrap_str(text, prefix, maxwidth)
}

void _inei_do_display_wrap_str(string scalar text, string scalar prefix,
    real scalar maxwidth)
{
    string scalar remaining, chunk, line
    real scalar line_len, break_pos, i

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

            for (i = line_len; i >= 1; i--) {
                if (substr(chunk, i, 1) == " ") {
                    break_pos = i
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
