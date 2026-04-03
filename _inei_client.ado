*! _inei_client.ado — HTTP client para portal INEI
*! Usa curl para POST requests, copy de Stata como fallback para GET
*! Maneja cookies de sesion y encoding Latin-1
*! version 1.0.0  2026-04-02

program define _inei_client, sclass
    version 14.0
    syntax anything(name=action), [URL(string) PARAMs(string) ///
        OUTFILE(string) COOKIEFILE(string) DELAY(real 0.2)]

    local action "`action'"

    if "`action'" == "init" {
        _inei_client_init, cookiefile(`cookiefile')
    }
    else if "`action'" == "get" {
        _inei_client_get, url(`url') outfile(`outfile') ///
            cookiefile(`cookiefile') delay(`delay')
    }
    else if "`action'" == "post" {
        _inei_client_post, url(`url') params(`params') ///
            outfile(`outfile') cookiefile(`cookiefile') delay(`delay')
    }
    else if "`action'" == "download" {
        _inei_client_download, url(`url') outfile(`outfile') ///
            cookiefile(`cookiefile')
    }
    else {
        di as error `"_inei_client: accion desconocida '`action''"'
        exit 198
    }
end

/* -----------------------------------------------------------------
   Inicializar sesion con el portal INEI
   GET a la pagina principal para obtener cookies
   ----------------------------------------------------------------- */
program define _inei_client_init, sclass
    syntax , [COOKIEFILE(string)]

    if "`cookiefile'" == "" {
        tempfile cookiefile
    }

    local base_url "https://proyectos.inei.gob.pe/microdatos"
    local init_url "`base_url'/Consulta_por_Encuesta.asp?CU=19558"

    tempfile tmpout

    * Intentar con curl
    local curl_cmd `"curl -s -k -L -c "`cookiefile'" -o "`tmpout'" "`init_url'""'

    capture shell `curl_cmd'
    if _rc != 0 {
        di as error "Error: curl no disponible o fallo la conexion"
        di as error "Instale curl: https://curl.se/download.html"
        exit 601
    }

    * Verificar que se obtuvo respuesta
    capture confirm file "`tmpout'"
    if _rc != 0 {
        di as error "Error: no se pudo conectar al portal INEI"
        exit 601
    }

    sreturn local cookiefile "`cookiefile'"
    sreturn local initfile "`tmpout'"

    di as text "Sesion INEI iniciada correctamente"
end

/* -----------------------------------------------------------------
   GET request
   ----------------------------------------------------------------- */
program define _inei_client_get, sclass
    syntax , URL(string) OUTFILE(string) [COOKIEFILE(string) DELAY(real 0.2)]

    * Delay entre requests
    if `delay' > 0 {
        sleep `= round(`delay' * 1000)'
    }

    * Intentar con copy de Stata primero
    capture copy "`url'" "`outfile'", replace
    if _rc == 0 {
        sreturn local status "ok"
        exit
    }

    * Fallback a curl
    if "`cookiefile'" != "" {
        local cookie_opt `"-b "`cookiefile'" -c "`cookiefile'""'
    }

    local curl_cmd `"curl -s -k -L `cookie_opt' -o "`outfile'" "`url'""'

    capture shell `curl_cmd'
    if _rc != 0 {
        di as error "Error descargando: `url'"
        sreturn local status "failed"
        exit 601
    }

    sreturn local status "ok"
end

/* -----------------------------------------------------------------
   POST request (requiere curl)
   ----------------------------------------------------------------- */
program define _inei_client_post, sclass
    syntax , URL(string) PARAMs(string) OUTFILE(string) ///
        [COOKIEFILE(string) DELAY(real 0.2)]

    * Delay entre requests
    if `delay' > 0 {
        sleep `= round(`delay' * 1000)'
    }

    if "`cookiefile'" != "" {
        local cookie_opt `"-b "`cookiefile'" -c "`cookiefile'""'
    }

    * POST request con curl
    * params viene en formato "key1=val1&key2=val2"
    local curl_cmd `"curl -s -k -L `cookie_opt' -X POST -d "`params'" -H "Content-Type: application/x-www-form-urlencoded" -o "`outfile'" "`url'""'

    capture shell `curl_cmd'
    if _rc != 0 {
        di as error "Error en POST a: `url'"
        sreturn local status "failed"
        exit 601
    }

    capture confirm file "`outfile'"
    if _rc != 0 {
        sreturn local status "failed"
        exit 601
    }

    sreturn local status "ok"
end

/* -----------------------------------------------------------------
   Download file (para microdatos/docs)
   Intenta copy primero, fallback a curl
   Timeout de 120 segundos
   ----------------------------------------------------------------- */
program define _inei_client_download, sclass
    syntax , URL(string) OUTFILE(string) [COOKIEFILE(string)]

    * Intentar con copy de Stata primero
    capture copy "`url'" "`outfile'", replace
    if _rc == 0 {
        * Verificar que el archivo no esta vacio
        capture mata: st_numscalar("__fsize", _inei_filesize("`outfile'"))
        if __fsize > 0 {
            sreturn local status "ok"
            sreturn local method "copy"
            scalar drop __fsize
            exit
        }
        capture scalar drop __fsize
    }

    * Fallback a curl con timeout
    if "`cookiefile'" != "" {
        local cookie_opt `"-b "`cookiefile'""'
    }

    local curl_cmd `"curl -s -k -L --max-time 120 `cookie_opt' -o "`outfile'" "`url'""'

    capture shell `curl_cmd'
    if _rc != 0 {
        sreturn local status "failed"
        sreturn local method "curl"
        exit
    }

    capture confirm file "`outfile'"
    if _rc != 0 {
        sreturn local status "failed"
        sreturn local method "curl"
        exit
    }

    sreturn local status "ok"
    sreturn local method "curl"
end

/* -----------------------------------------------------------------
   Mata helper: file size
   ----------------------------------------------------------------- */
mata:
real scalar _inei_filesize(string scalar filepath)
{
    real scalar fh, sz

    fh = fopen(filepath, "r")
    if (fh < 0) return(0)

    fseek(fh, 0, 1)  // seek to end
    sz = ftell(fh)
    fclose(fh)
    return(sz)
}
end
