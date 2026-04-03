*! _inei_curl.ado — Ejecutar curl via archivo .bat
*! Escribe el comando a un .bat y lo ejecuta con cmd.exe
*! Esto evita problemas de encoding al pasar chars especiales via shell
*! version 1.0.0  2026-04-03

program define _inei_curl, sclass
    syntax , CMD(string asis) [DELAY(integer 0)]

    local batfile "`c(tmpdir)'/inei_cmd.bat"

    * Escribir comando al .bat
    tempname fh
    file open `fh' using "`batfile'", write text replace
    file write `fh' "@echo off" _n
    file write `fh' `cmd' _n
    file close `fh'

    * Ejecutar
    quietly ! cmd.exe /c "`batfile'"

    if `delay' > 0 {
        sleep `delay'
    }

    capture erase "`batfile'"
end
