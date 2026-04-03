*! _inei_parse.ado — Parser HTML para respuestas del portal INEI
*! Extrae <option> elements y filas de tabla con modulos/docs
*! version 1.0.3  2026-04-02

program define _inei_parse, sclass
    version 14.0
    syntax anything(name=parse_type), FILE(string) [CLEAR]

    local parse_type "`parse_type'"

    if "`parse_type'" == "options" {
        _inei_parse_options, file("`file'")
    }
    else if "`parse_type'" == "modules" {
        _inei_parse_modules, file("`file'")
    }
    else if "`parse_type'" == "docs" {
        _inei_parse_docs, file("`file'")
    }
    else if "`parse_type'" == "surveys" {
        _inei_parse_surveys, file("`file'")
    }
    else {
        di as error `"_inei_parse: tipo desconocido '`parse_type''"'
        exit 198
    }
end

program define _inei_parse_options, sclass
    syntax , FILE(string)
    mata: _inei_do_parse_options("`file'")
end

program define _inei_parse_modules, sclass
    syntax , FILE(string)
    mata: _inei_do_parse_modules("`file'")
end

program define _inei_parse_docs, sclass
    syntax , FILE(string)
    mata: _inei_do_parse_docs("`file'")
end

program define _inei_parse_surveys, sclass
    syntax , FILE(string)
    mata: _inei_do_parse_surveys("`file'")
end

/* =================================================================
   MATA IMPLEMENTATIONS
   ================================================================= */
mata:

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
   Parse all <option> from a chunk of HTML
   Returns values and labels via Stata dataset
   ----------------------------------------------------------------- */
void _inei_do_parse_options(string scalar filepath)
{
    string scalar content, val, label
    real scalar pos, end_tag, n, i, close_pos, j
    string colvector values, labels

    content = _inei_read_file(filepath)
    if (content == "") return

    // Count options
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

        val = _inei_extract_attr(content, pos, "value")

        end_tag = _inei_find_next(content, ">", pos)
        if (end_tag == 0) break

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

    stata("clear")
    st_addobs(i)
    (void) st_addvar("str244", "opt_value")
    (void) st_addvar("str244", "opt_label")
    for (j = 1; j <= i; j++) {
        st_sstore(j, 1, values[j])
        st_sstore(j, 2, labels[j])
    }

    st_local("n_options", strofreal(i))
}

/* -----------------------------------------------------------------
   Parse ALL survey dropdowns from the INEI main page
   The portal has 4 dropdowns:
     cmbEncuesta0  — main selector (1=ENAHO Anterior, 2=ENAHO Actualizada, 3=EPEN, rest=direct)
     cmbEncuestaA  — ENAHO Anterior sub-surveys
     cmbEncuestaN  — ENAHO Actualizada sub-surveys
     cmbEncuesta_EPE — EPEN sub-surveys
   We merge all of them into a single flat list.
   ----------------------------------------------------------------- */
void _inei_do_parse_surveys(string scalar filepath)
{
    string scalar content, block, val, label
    real scalar pos, end_pos, n, i, j, close_pos, end_tag
    string colvector all_values, all_labels
    real scalar total

    content = _inei_read_file(filepath)
    if (content == "") return

    // Allocate generous buffer
    all_values = J(200, 1, "")
    all_labels = J(200, 1, "")
    total = 0

    // --- 1. Parse cmbEncuestaA (ENAHO Anterior sub-surveys) ---
    pos = strpos(content, "cmbEncuestaA")
    if (pos > 0) {
        end_pos = _inei_find_next(content, "</select>", pos)
        if (end_pos == 0) end_pos = _inei_find_next(content, "</SELECT>", pos)
        if (end_pos > 0) {
            block = substr(content, pos, end_pos - pos + 9)
            total = _inei_extract_options_from_block(block, all_values, all_labels, total)
        }
    }

    // --- 2. Parse cmbEncuestaN (ENAHO Actualizada sub-surveys) ---
    pos = strpos(content, "cmbEncuestaN")
    if (pos > 0) {
        end_pos = _inei_find_next(content, "</select>", pos)
        if (end_pos == 0) end_pos = _inei_find_next(content, "</SELECT>", pos)
        if (end_pos > 0) {
            block = substr(content, pos, end_pos - pos + 9)
            total = _inei_extract_options_from_block(block, all_values, all_labels, total)
        }
    }

    // --- 3. Parse cmbEncuesta_EPE (EPEN sub-surveys) ---
    pos = strpos(content, "cmbEncuesta_EPE")
    if (pos > 0) {
        end_pos = _inei_find_next(content, "</select>", pos)
        if (end_pos == 0) end_pos = _inei_find_next(content, "</SELECT>", pos)
        if (end_pos > 0) {
            block = substr(content, pos, end_pos - pos + 9)
            total = _inei_extract_options_from_block(block, all_values, all_labels, total)
        }
    }

    // --- 4. Parse cmbEncuesta0 (main dropdown, skip values 1,2,3) ---
    pos = strpos(content, "cmbEncuesta0")
    if (pos > 0) {
        end_pos = _inei_find_next(content, "</select>", pos)
        if (end_pos == 0) end_pos = _inei_find_next(content, "</SELECT>", pos)
        if (end_pos > 0) {
            block = substr(content, pos, end_pos - pos + 9)
            // Parse options but skip values "1", "2", "3" (handled above)
            real scalar opos
            opos = 1
            while (1) {
                opos = _inei_find_next(block, "<option", opos)
                if (opos == 0) break

                val = _inei_extract_attr(block, opos, "value")
                val = strtrim(val)

                end_tag = _inei_find_next(block, ">", opos)
                if (end_tag == 0) break

                close_pos = _inei_find_next(block, "</option>", end_tag)
                if (close_pos == 0) close_pos = _inei_find_next(block, "</OPTION>", end_tag)

                if (close_pos > 0) {
                    label = substr(block, end_tag + 1, close_pos - end_tag - 1)
                    label = strtrim(_inei_strip_tags(label))
                    label = _inei_decode_entities(label)
                }
                else {
                    label = ""
                }

                // Skip empty, "1", "2", "3" (ENAHO/EPEN handled separately)
                if (val != "" & val != "1" & val != "2" & val != "3") {
                    total++
                    if (total <= 200) {
                        all_values[total] = val
                        all_labels[total] = label
                    }
                }

                opos = end_tag + 1
            }
        }
    }

    if (total == 0) {
        st_local("n_surveys", "0")
        return
    }

    // Store in Stata dataset
    stata("clear")
    st_addobs(total)
    (void) st_addvar("str244", "opt_value")
    (void) st_addvar("str244", "opt_label")
    for (j = 1; j <= total; j++) {
        st_sstore(j, 1, all_values[j])
        st_sstore(j, 2, all_labels[j])
    }

    st_local("n_surveys", strofreal(total))
}

/* -----------------------------------------------------------------
   Helper: extract options from an HTML block, append to arrays
   ----------------------------------------------------------------- */
real scalar _inei_extract_options_from_block(
    string scalar block,
    string colvector values,
    string colvector labels,
    real scalar offset)
{
    real scalar pos, end_tag, close_pos, count
    string scalar val, label

    count = offset
    pos = 1
    while (1) {
        pos = _inei_find_next(block, "<option", pos)
        if (pos == 0) break

        val = _inei_extract_attr(block, pos, "value")
        val = strtrim(val)

        end_tag = _inei_find_next(block, ">", pos)
        if (end_tag == 0) break

        close_pos = _inei_find_next(block, "</option>", end_tag)
        if (close_pos == 0) close_pos = _inei_find_next(block, "</OPTION>", end_tag)

        if (close_pos > 0) {
            label = substr(block, end_tag + 1, close_pos - end_tag - 1)
            label = strtrim(_inei_strip_tags(label))
            label = _inei_decode_entities(label)
        }
        else {
            label = ""
        }

        // Skip empty/placeholder values
        if (val != "" & label != "") {
            count++
            if (count <= 200) {
                values[count] = val
                labels[count] = label
            }
        }

        pos = end_tag + 1
    }

    return(count)
}

/* -----------------------------------------------------------------
   Parse module table rows
   ----------------------------------------------------------------- */
void _inei_do_parse_modules(string scalar filepath)
{
    string scalar content, row
    real scalar pos, row_end, n, i, j
    string colvector mod_names, csv_codes, stata_codes, spss_codes, cells

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
        cells = _inei_extract_cells(row)

        if (length(cells) >= 4) {
            i++
            if (i <= n) {
                mod_names[i] = _inei_strip_tags(cells[1])
                mod_names[i] = _inei_decode_entities(mod_names[i])
                csv_codes[i] = _inei_extract_download_code(cells[2])
                stata_codes[i] = _inei_extract_download_code(cells[3])
                spss_codes[i] = _inei_extract_download_code(cells[4])
            }
        }

        pos = row_end + 5
    }

    if (i > 0) {
        stata("clear")
        st_addobs(i)
        (void) st_addvar("str244", "module_name")
        (void) st_addvar("str100", "csv_code")
        (void) st_addvar("str100", "stata_code")
        (void) st_addvar("str100", "spss_code")

        for (j = 1; j <= i; j++) {
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
    string scalar content, row, zip_path
    real scalar pos, row_end, n, i, j
    string colvector doc_names, zip_paths, cells

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
        cells = _inei_extract_cells(row)

        if (length(cells) >= 2) {
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

        for (j = 1; j <= i; j++) {
            st_sstore(j, 1, doc_names[j])
            st_sstore(j, 2, zip_paths[j])
        }
    }

    st_local("n_docs", strofreal(i))
}

/* -----------------------------------------------------------------
   Helpers
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
        result = strpos(strlower(sub), strlower(needle))
    }
    if (result == 0) return(0)
    return(from_pos + result - 1)
}

string scalar _inei_extract_attr(string scalar content, real scalar tag_pos,
                                  string scalar attr_name)
{
    real scalar attr_pos, quote_start, quote_end, tag_end, k
    string scalar sub, value, ch

    tag_end = _inei_find_next(content, ">", tag_pos)
    if (tag_end == 0) return("")

    sub = substr(content, tag_pos, tag_end - tag_pos)

    attr_pos = strpos(strlower(sub), strlower(attr_name) + "=")
    if (attr_pos == 0) return("")

    attr_pos = attr_pos + strlen(attr_name) + 1

    ch = substr(sub, attr_pos, 1)
    if (ch == `"""' | ch == "'") {
        quote_start = attr_pos + 1
        quote_end = strpos(substr(sub, quote_start, .), ch)
        if (quote_end == 0) return("")
        value = substr(sub, quote_start, quote_end - 1)
    }
    else {
        value = ""
        for (k = attr_pos; k <= strlen(sub); k++) {
            ch = substr(sub, k, 1)
            if (ch == " " | ch == ">") break
            value = value + ch
        }
    }

    return(strtrim(value))
}

string colvector _inei_extract_cells(string scalar row)
{
    string colvector cells
    real scalar pos, cell_end, n, i, td_end

    n = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(row, "<td", pos)
        if (pos == 0) break
        n++
        pos = pos + 3
    }

    if (n == 0) return(J(0, 1, ""))

    cells = J(n, 1, "")
    i = 0
    pos = 1
    while (1) {
        pos = _inei_find_next(row, "<td", pos)
        if (pos == 0) break

        td_end = _inei_find_next(row, ">", pos)
        if (td_end == 0) break

        cell_end = _inei_find_next(row, "</td>", td_end)
        if (cell_end == 0) cell_end = _inei_find_next(row, "</TD>", td_end)
        if (cell_end == 0) break

        i++
        if (i <= n) {
            cells[i] = substr(row, td_end + 1, cell_end - td_end - 1)
        }

        pos = cell_end + 5
    }

    if (i == 0) return(J(0, 1, ""))
    return(cells[1::i])
}

string scalar _inei_extract_download_code(string scalar cell_html)
{
    real scalar pos, end_pos, start
    string scalar code, c

    pos = strpos(cell_html, "-Modulo")
    if (pos == 0) pos = strpos(cell_html, "-modulo")
    if (pos == 0) return("")

    start = pos - 1
    while (start >= 1) {
        c = substr(cell_html, start, 1)
        if (c >= "0" & c <= "9") {
            start--
        }
        else break
    }
    start = start + 1

    end_pos = pos + 7
    while (end_pos <= strlen(cell_html)) {
        c = substr(cell_html, end_pos, 1)
        if (c >= "0" & c <= "9") {
            end_pos++
        }
        else break
    }

    code = substr(cell_html, start, end_pos - start)
    return(strtrim(code))
}

string scalar _inei_extract_zip_path(string scalar row_html)
{
    real scalar pos, start, end_pos
    string scalar c

    pos = strpos(row_html, "DocumentosZIP/")
    if (pos == 0) return("")

    start = pos + 14

    end_pos = start
    while (end_pos <= strlen(row_html)) {
        c = substr(row_html, end_pos, 1)
        if (c == "'" | c == `"""' | c == ")" | c == " ") break
        end_pos++
    }

    return(substr(row_html, start, end_pos - start))
}

end
