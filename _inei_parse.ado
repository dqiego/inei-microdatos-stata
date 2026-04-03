*! _inei_parse.ado — Parser HTML para respuestas del portal INEI
*! Extrae <option> elements y filas de tabla con modulos/docs
*! version 1.0.0  2026-04-02

program define _inei_parse, sclass
    version 14.0
    syntax anything(name=parse_type), FILE(string) [CLEAR]

    local parse_type = `parse_type'

    if "`parse_type'" == "options" {
        _inei_parse_options, file(`file') `clear'
    }
    else if "`parse_type'" == "modules" {
        _inei_parse_modules, file(`file') `clear'
    }
    else if "`parse_type'" == "docs" {
        _inei_parse_docs, file(`file') `clear'
    }
    else if "`parse_type'" == "surveys" {
        _inei_parse_surveys, file(`file') `clear'
    }
    else {
        di as error `"_inei_parse: tipo desconocido '`parse_type''"'
        exit 198
    }
end

/* -----------------------------------------------------------------
   Parse <option value="X">Label</option> from HTML
   Deja resultados en un frame o dataset temporal
   ----------------------------------------------------------------- */
program define _inei_parse_options, sclass
    syntax , FILE(string) [CLEAR]

    * Leer archivo completo en Mata
    mata: _inei_do_parse_options("`file'")
end

/* -----------------------------------------------------------------
   Parse module rows from HTML table
   Extrae survey_code, module_code, module_name, csv_code, stata_code, spss_code
   ----------------------------------------------------------------- */
program define _inei_parse_modules, sclass
    syntax , FILE(string) [CLEAR]

    mata: _inei_do_parse_modules("`file'")
end

/* -----------------------------------------------------------------
   Parse documentation rows from HTML table
   ----------------------------------------------------------------- */
program define _inei_parse_docs, sclass
    syntax , FILE(string) [CLEAR]

    mata: _inei_do_parse_docs("`file'")
end

/* -----------------------------------------------------------------
   Parse initial survey list from main page HTML
   ----------------------------------------------------------------- */
program define _inei_parse_surveys, sclass
    syntax , FILE(string) [CLEAR]

    mata: _inei_do_parse_surveys("`file'")
end

/* =================================================================
   MATA IMPLEMENTATIONS
   ================================================================= */
mata:

/* -----------------------------------------------------------------
   Read file contents as a single string (Latin-1)
   ----------------------------------------------------------------- */
string scalar _inei_read_file(string scalar filepath)
{
    real scalar fh
    string scalar content, line

    fh = fopen(filepath, "r")
    if (fh < 0) {
        errprintf("No se puede abrir archivo: %s\n", filepath)
        return("")
    }

    content = ""
    while ((line = fget(fh)) != J(0, 0, "")) {
        content = content + line + char(10)
    }
    fclose(fh)
    return(content)
}

/* -----------------------------------------------------------------
   Strip HTML tags from a string
   ----------------------------------------------------------------- */
string scalar _inei_strip_tags(string scalar s)
{
    string scalar result
    real scalar i, n, inside

    result = ""
    inside = 0
    n = strlen(s)

    for (i = 1; i <= n; i++) {
        if (substr(s, i, 1) == "<") {
            inside = 1
        }
        else if (substr(s, i, 1) == ">") {
            inside = 0
        }
        else if (!inside) {
            result = result + substr(s, i, 1)
        }
    }
    return(strtrim(result))
}

/* -----------------------------------------------------------------
   Decode HTML entities (&amp; &lt; &gt; &nbsp; &#NNN;)
   ----------------------------------------------------------------- */
string scalar _inei_decode_entities(string scalar s)
{
    string scalar result

    result = s
    result = subinstr(result, "&amp;", "&")
    result = subinstr(result, "&lt;", "<")
    result = subinstr(result, "&gt;", ">")
    result = subinstr(result, "&nbsp;", " ")
    result = subinstr(result, "&quot;", `"""')
    result = subinstr(result, "&#39;", "'")
    result = subinstr(result, "&aacute;", "a")
    result = subinstr(result, "&eacute;", "e")
    result = subinstr(result, "&iacute;", "i")
    result = subinstr(result, "&oacute;", "o")
    result = subinstr(result, "&uacute;", "u")
    result = subinstr(result, "&ntilde;", "n")
    result = subinstr(result, "&Aacute;", "A")
    result = subinstr(result, "&Eacute;", "E")
    result = subinstr(result, "&Iacute;", "I")
    result = subinstr(result, "&Oacute;", "O")
    result = subinstr(result, "&Uacute;", "U")
    result = subinstr(result, "&Ntilde;", "N")

    return(strtrim(result))
}

/* -----------------------------------------------------------------
   Parse <option value="X">Label</option> elements
   Stores results as Stata variables: opt_value opt_label
   ----------------------------------------------------------------- */
void _inei_do_parse_options(string scalar filepath)
{
    string scalar content, val, label
    real scalar pos, end_tag, n, i
    string colvector values, labels

    content = _inei_read_file(filepath)
    if (content == "") return

    // Count option elements
    n = 0
    pos = 1
    while ((pos = strpos(substr(content, pos, .), "<option")) > 0) {
        n++
        pos = pos + 7
        // Recalculate position in full string
        if (pos > strlen(content)) break
    }

    // Re-count properly
    n = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(content, "<option", pos)
        if (pos == 0) break
        n++
        pos = pos + 7
    }

    if (n == 0) {
        st_local("n_options", "0")
        return
    }

    values = J(n, 1, "")
    labels = J(n, 1, "")

    i = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(content, "<option", pos)
        if (pos == 0) break
        i++

        // Extract value attribute
        val = _inei_extract_attr(content, pos, "value")

        // Find > after <option ...>
        end_tag = _inei_find_next(content, ">", pos)
        if (end_tag == 0) break

        // Find </option>
        real scalar close_pos
        close_pos = _inei_find_next(content, "</option>", end_tag)
        if (close_pos == 0) close_pos = _inei_find_next(content, "</OPTION>", end_tag)

        if (close_pos > 0) {
            label = substr(content, end_tag + 1, close_pos - end_tag - 1)
            label = _inei_strip_tags(label)
            label = _inei_decode_entities(label)
        }
        else {
            label = ""
        }

        if (i <= n) {
            values[i] = strtrim(val)
            labels[i] = strtrim(label)
        }

        pos = end_tag + 1
    }

    // Store in Stata dataset
    stata("clear")
    st_addobs(i)
    (void) st_addvar("str244", "opt_value")
    (void) st_addvar("str244", "opt_label")
    for (real scalar j = 1; j <= i; j++) {
        st_sstore(j, 1, values[j])
        st_sstore(j, 2, labels[j])
    }

    st_local("n_options", strofreal(i))
}

/* -----------------------------------------------------------------
   Parse module table rows from HTML
   Each row has: module_name, csv_code, stata_code, spss_code
   ----------------------------------------------------------------- */
void _inei_do_parse_modules(string scalar filepath)
{
    string scalar content, row, cell
    real scalar pos, row_end, n, i
    string colvector mod_names, csv_codes, stata_codes, spss_codes

    content = _inei_read_file(filepath)
    if (content == "") return

    // Count table rows
    n = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(content, "<tr", pos)
        if (pos == 0) break
        n++
        pos = pos + 3
    }

    if (n == 0) {
        st_local("n_modules", "0")
        return
    }

    mod_names = J(n, 1, "")
    csv_codes = J(n, 1, "")
    stata_codes = J(n, 1, "")
    spss_codes = J(n, 1, "")

    i = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(content, "<tr", pos)
        if (pos == 0) break

        row_end = _inei_find_next(content, "</tr>", pos)
        if (row_end == 0) row_end = _inei_find_next(content, "</TR>", pos)
        if (row_end == 0) break

        row = substr(content, pos, row_end - pos + 5)

        // Extract cells from this row
        string colvector cells
        cells = _inei_extract_cells(row)

        if (length(cells) >= 4) {
            i++
            if (i <= n) {
                mod_names[i] = _inei_strip_tags(cells[1])
                mod_names[i] = _inei_decode_entities(mod_names[i])

                // Extract download codes from links
                csv_codes[i] = _inei_extract_download_code(cells[2])
                stata_codes[i] = _inei_extract_download_code(cells[3])
                spss_codes[i] = _inei_extract_download_code(cells[4])
            }
        }

        pos = row_end + 5
    }

    // Store in Stata dataset
    if (i > 0) {
        stata("clear")
        st_addobs(i)
        (void) st_addvar("str244", "module_name")
        (void) st_addvar("str100", "csv_code")
        (void) st_addvar("str100", "stata_code")
        (void) st_addvar("str100", "spss_code")

        for (real scalar j = 1; j <= i; j++) {
            st_sstore(j, 1, mod_names[j])
            st_sstore(j, 2, csv_codes[j])
            st_sstore(j, 3, stata_codes[j])
            st_sstore(j, 4, spss_codes[j])
        }
    }

    st_local("n_modules", strofreal(i))
}

/* -----------------------------------------------------------------
   Parse documentation table rows
   ----------------------------------------------------------------- */
void _inei_do_parse_docs(string scalar filepath)
{
    string scalar content, row
    real scalar pos, row_end, n, i
    string colvector doc_names, zip_paths

    content = _inei_read_file(filepath)
    if (content == "") return

    n = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(content, "<tr", pos)
        if (pos == 0) break
        n++
        pos = pos + 3
    }

    if (n == 0) {
        st_local("n_docs", "0")
        return
    }

    doc_names = J(n, 1, "")
    zip_paths = J(n, 1, "")

    i = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(content, "<tr", pos)
        if (pos == 0) break

        row_end = _inei_find_next(content, "</tr>", pos)
        if (row_end == 0) row_end = _inei_find_next(content, "</TR>", pos)
        if (row_end == 0) break

        row = substr(content, pos, row_end - pos + 5)

        string colvector cells
        cells = _inei_extract_cells(row)

        if (length(cells) >= 2) {
            // Check if row has download link
            string scalar zip_path
            zip_path = _inei_extract_zip_path(row)
            if (zip_path != "") {
                i++
                if (i <= n) {
                    doc_names[i] = _inei_strip_tags(cells[1])
                    doc_names[i] = _inei_decode_entities(doc_names[i])
                    zip_paths[i] = zip_path
                }
            }
        }

        pos = row_end + 5
    }

    if (i > 0) {
        stata("clear")
        st_addobs(i)
        (void) st_addvar("str244", "doc_name")
        (void) st_addvar("str244", "zip_path")

        for (real scalar j = 1; j <= i; j++) {
            st_sstore(j, 1, doc_names[j])
            st_sstore(j, 2, zip_paths[j])
        }
    }

    st_local("n_docs", strofreal(i))
}

/* -----------------------------------------------------------------
   Parse initial survey dropdown from main page
   ----------------------------------------------------------------- */
void _inei_do_parse_surveys(string scalar filepath)
{
    string scalar content
    real scalar select_start, select_end

    content = _inei_read_file(filepath)
    if (content == "") return

    // Find the survey select element (cmbEncuesta)
    select_start = _inei_find_next(content, "cmbEncuesta", 1)
    if (select_start == 0) {
        st_local("n_surveys", "0")
        return
    }

    // Find the <select> tag containing it
    select_start = _inei_find_prev(content, "<select", select_start)
    if (select_start == 0) select_start = _inei_find_prev(content, "<SELECT", select_start)

    select_end = _inei_find_next(content, "</select>", select_start)
    if (select_end == 0) select_end = _inei_find_next(content, "</SELECT>", select_start)

    if (select_end == 0) {
        st_local("n_surveys", "0")
        return
    }

    // Extract just the select block
    string scalar select_html
    select_html = substr(content, select_start, select_end - select_start + 9)

    // Write to temp file and parse as options
    string scalar tmpfile
    tmpfile = st_tempfilename()
    real scalar fh
    fh = fopen(tmpfile, "w")
    fput(fh, select_html)
    fclose(fh)

    _inei_do_parse_options(tmpfile)
    unlink(tmpfile)
}

/* -----------------------------------------------------------------
   Helper: find next occurrence of needle in haystack from pos
   ----------------------------------------------------------------- */
real scalar _inei_find_next(string scalar haystack, string scalar needle,
                            real scalar from_pos)
{
    real scalar result
    string scalar sub

    if (from_pos > strlen(haystack)) return(0)

    sub = substr(haystack, from_pos, .)
    result = strpos(sub, needle)
    if (result == 0) {
        // Try case-insensitive
        result = strpos(strlower(sub), strlower(needle))
    }
    if (result == 0) return(0)
    return(from_pos + result - 1)
}

/* -----------------------------------------------------------------
   Helper: find previous occurrence of needle before pos
   ----------------------------------------------------------------- */
real scalar _inei_find_prev(string scalar haystack, string scalar needle,
                            real scalar before_pos)
{
    real scalar result, last, pos
    string scalar sub

    sub = substr(haystack, 1, before_pos)
    last = 0
    pos = 1
    while (1) {
        result = strpos(substr(sub, pos, .), strlower(needle))
        if (result == 0) result = strpos(substr(sub, pos, .), needle)
        if (result == 0) break
        last = pos + result - 1
        pos = last + 1
    }
    return(last)
}

/* -----------------------------------------------------------------
   Helper: extract attribute value from tag at position
   ----------------------------------------------------------------- */
string scalar _inei_extract_attr(string scalar content, real scalar tag_pos,
                                  string scalar attr_name)
{
    real scalar attr_pos, quote_start, quote_end
    string scalar sub, value

    // Find end of tag
    real scalar tag_end
    tag_end = _inei_find_next(content, ">", tag_pos)
    if (tag_end == 0) return("")

    sub = substr(content, tag_pos, tag_end - tag_pos)

    // Find attribute (case-insensitive)
    attr_pos = strpos(strlower(sub), strlower(attr_name) + "=")
    if (attr_pos == 0) return("")

    // Move past attr_name=
    attr_pos = attr_pos + strlen(attr_name) + 1

    // Check for quotes
    string scalar ch
    ch = substr(sub, attr_pos, 1)
    if (ch == `"""' | ch == "'") {
        quote_start = attr_pos + 1
        quote_end = strpos(substr(sub, quote_start, .), ch)
        if (quote_end == 0) return("")
        value = substr(sub, quote_start, quote_end - 1)
    }
    else {
        // No quotes, read until space or >
        value = ""
        real scalar k
        for (k = attr_pos; k <= strlen(sub); k++) {
            ch = substr(sub, k, 1)
            if (ch == " " | ch == ">") break
            value = value + ch
        }
    }

    return(strtrim(value))
}

/* -----------------------------------------------------------------
   Helper: extract <td> cells from a <tr> row
   ----------------------------------------------------------------- */
string colvector _inei_extract_cells(string scalar row)
{
    string colvector cells
    real scalar pos, cell_end, n, i
    string scalar cell_content

    // Count cells
    n = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(row, "<td", pos)
        if (pos == 0) break
        n++
        pos = pos + 3
    }

    cells = J(n, 1, "")
    i = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(row, "<td", pos)
        if (pos == 0) break

        // Find > after <td
        real scalar td_end
        td_end = _inei_find_next(row, ">", pos)
        if (td_end == 0) break

        // Find </td>
        cell_end = _inei_find_next(row, "</td>", td_end)
        if (cell_end == 0) cell_end = _inei_find_next(row, "</TD>", td_end)
        if (cell_end == 0) break

        i++
        if (i <= n) {
            cells[i] = substr(row, td_end + 1, cell_end - td_end - 1)
        }

        pos = cell_end + 5
    }

    return(cells[1::i])
}

/* -----------------------------------------------------------------
   Helper: extract download code from a cell containing link
   e.g., extracts "966-Modulo01" from onclick or href
   ----------------------------------------------------------------- */
string scalar _inei_extract_download_code(string scalar cell_html)
{
    real scalar pos, end_pos
    string scalar code

    // Look for download code pattern: NNN-ModuloNN or NNN-ModuloNNNN
    // Usually in onclick="javascript:descarga('CODE')" or similar

    // Try to find pattern like 'NNN-Modulo'
    pos = strpos(cell_html, "-Modulo")
    if (pos == 0) pos = strpos(cell_html, "-modulo")
    if (pos == 0) return("")

    // Walk backwards to find start of code (digits)
    real scalar start
    start = pos - 1
    while (start >= 1) {
        string scalar c
        c = substr(cell_html, start, 1)
        if (c >= "0" & c <= "9") {
            start--
        }
        else break
    }
    start = start + 1

    // Walk forwards to find end of code
    end_pos = pos + 7 // skip "-Modulo"
    while (end_pos <= strlen(cell_html)) {
        string scalar c2
        c2 = substr(cell_html, end_pos, 1)
        if (c2 >= "0" & c2 <= "9") {
            end_pos++
        }
        else break
    }

    code = substr(cell_html, start, end_pos - start)
    return(strtrim(code))
}

/* -----------------------------------------------------------------
   Helper: extract ZIP path from documentation row
   ----------------------------------------------------------------- */
string scalar _inei_extract_zip_path(string scalar row_html)
{
    real scalar pos, start, end_pos

    // Look for DocumentosZIP/ path
    pos = strpos(row_html, "DocumentosZIP/")
    if (pos == 0) return("")

    // Extract the path after DocumentosZIP/
    start = pos + 14  // skip "DocumentosZIP/"

    // Find end (usually quote or apostrophe)
    end_pos = start
    while (end_pos <= strlen(row_html)) {
        string scalar c
        c = substr(row_html, end_pos, 1)
        if (c == "'" | c == `"""' | c == ")" | c == " ") break
        end_pos++
    }

    return(substr(row_html, start, end_pos - start))
}

end
