*! _inei_unzip.ado — Descomprimir archivo ZIP
*! Usa unzipfile (disponible desde Stata 11)
*! version 1.0.0  2026-04-03

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

    * Guardar directorio actual
    local orig_dir "`c(pwd)'"

    * Cambiar al directorio destino (unzipfile extrae relativo a cwd)
    quietly cd "`destdir'"

    * Descomprimir
    capture unzipfile "`zipfile'", replace

    * Volver al directorio original
    quietly cd "`orig_dir'"

    if _rc != 0 {
        di as error "Error descomprimiendo: `zipfile'"
        exit 601
    }

    sreturn local destdir "`destdir'"
end
