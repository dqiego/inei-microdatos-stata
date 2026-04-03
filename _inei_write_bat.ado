*! _inei_write_bat.ado — Escribir script .bat con comando curl
*! version 1.0.0  2026-04-02

program define _inei_write_bat
    args batfile curl_cmd

    tempname fh
    file open `fh' using "`batfile'", write replace
    file write `fh' "@echo off" _n
    file write `fh' `"`curl_cmd'"' _n
    file close `fh'
end
