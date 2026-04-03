*! _inei_unzip.ado — Descomprimir archivo ZIP
*! Usa unzipfile con fallback a shell (tar/unzip)
*! version 1.0.1  2026-04-03

program define _inei_unzip, sclass
    syntax , ZIPFILE(string) DESTDIR(string)

    * Verificar que el ZIP existe
    capture confirm file "`zipfile'"
    if _rc != 0 {
        di as error "Archivo no encontrado: `zipfile'"
        exit 601
    }

    * Crear directorio destino si no existe
    capture mkdir "`destdir'"

    * Normalizar paths (reemplazar \ por /)
    local zipfile = subinstr("`zipfile'", "\", "/", .)
    local destdir = subinstr("`destdir'", "\", "/", .)

    * Guardar directorio actual
    local orig_dir "`c(pwd)'"

    * --- Intento 1: unzipfile de Stata ---
    quietly cd "`destdir'"
    capture noisily unzipfile "`zipfile'", replace
    local rc1 = _rc
    quietly cd "`orig_dir'"

    if `rc1' == 0 {
        sreturn local destdir "`destdir'"
        exit
    }

    * --- Intento 2: shell tar (Windows 10+) ---
    di as text "  unzipfile fallo, intentando con tar..."
    capture quietly ! tar -xf "`zipfile'" -C "`destdir'"

    * Verificar si se extrajo algo
    mata: st_local("n_extracted", strofreal(length(dir("`destdir'", "files", "*")) + length(dir("`destdir'", "dirs", "*"))))
    if `n_extracted' > 0 {
        sreturn local destdir "`destdir'"
        exit
    }

    * --- Intento 3: PowerShell (Windows) ---
    di as text "  tar fallo, intentando con PowerShell..."
    local ps_zip = subinstr("`zipfile'", "/", "\", .)
    local ps_dest = subinstr("`destdir'", "/", "\", .)
    capture quietly ! powershell -Command "Expand-Archive -Path '`ps_zip'' -DestinationPath '`ps_dest'' -Force"

    mata: st_local("n_extracted2", strofreal(length(dir("`destdir'", "files", "*")) + length(dir("`destdir'", "dirs", "*"))))
    if `n_extracted2' > 0 {
        sreturn local destdir "`destdir'"
        exit
    }

    di as error "Error descomprimiendo: `zipfile'"
    di as text "  Intente descomprimir manualmente y use {bf:nodownload}"
    exit 601
end
