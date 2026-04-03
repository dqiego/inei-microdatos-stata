{smcl}
{* *! version 1.0.0  2026-04-02}{...}
{viewerjumpto "Syntax" "inei##syntax"}{...}
{viewerjumpto "Description" "inei##description"}{...}
{viewerjumpto "Commands" "inei##commands"}{...}
{viewerjumpto "Examples" "inei##examples"}{...}
{viewerjumpto "Author" "inei##author"}{...}
{title:Title}

{phang}
{bf:inei} {hline 2} Acceso a microdatos del INEI (Peru)


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:inei} {it:subcomando} [{cmd:,} {it:opciones}]

{synoptset 25 tabbed}{...}
{synopthdr:Subcomandos}
{synoptline}
{synopt:{opt list}}Listar encuestas y modulos disponibles{p_end}
{synopt:{opt download}}Descargar microdatos{p_end}
{synopt:{opt docs}}Descargar documentacion{p_end}
{synopt:{opt search}}Buscar variables en el indice{p_end}
{synopt:{opt track}}Seguir variable entre anios{p_end}
{synopt:{opt crawl}}Actualizar catalogo desde el portal{p_end}
{synopt:{opt aliases}}Mostrar aliases de encuestas{p_end}
{synopt:{opt stats}}Estadisticas del catalogo{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:inei} proporciona acceso programatico al portal de microdatos del
{browse "https://proyectos.inei.gob.pe/microdatos/":INEI} (Instituto Nacional
de Estadistica e Informatica de Peru).

{pstd}
El paquete permite buscar, listar y descargar microdatos de 67 encuestas
(ENAHO, ENDES, EPEN, CENAGRO, etc.) que abarcan desde 1994 hasta 2025,
con mas de 5,900 modulos descargables y 525,000+ variables indexadas.

{pstd}
Basado en el paquete Python {browse "https://github.com/fiorellarmartins/inei-microdatos":inei-microdatos}
de fiorellarmartins.

{pstd}
{bf:Requisitos:} Se requiere {cmd:curl} instalado en el sistema para las
funciones de crawling y descarga. En Windows 10+ ya viene preinstalado.


{marker commands}{...}
{title:Commands}

{dlgtab:inei list}

{p 8 17 2}
{cmd:inei list}
[{cmd:,} {opt survey(string)} {opt yearmin(#)} {opt yearmax(#)}
{opt period(string)} {opt modules}]

{pstd}
Muestra las encuestas disponibles en el catalogo. Con la opcion {opt modules}
muestra el detalle de cada modulo.

{dlgtab:inei download}

{p 8 17 2}
{cmd:inei download}
{cmd:,} {opt survey(string)}
[{opt format(CSV|STATA|SPSS)} {opt dest(string)}
{opt yearmin(#)} {opt yearmax(#)} {opt period(string)}
{opt layout(string)} {opt nofallback} {opt dryrun} {opt docs}]

{pstd}
Descarga microdatos. El formato por defecto es STATA. Si el formato
preferido no esta disponible, intenta automaticamente con otro formato
(a menos que se use {opt nofallback}).

{pstd}
Layouts disponibles: {bf:default} ({it:encuesta/anio/periodo/}),
{bf:flat} ({it:encuesta/}), {bf:by-year} ({it:encuesta/anio/}),
{bf:by-format} ({it:formato/encuesta/anio/}).

{dlgtab:inei docs}

{p 8 17 2}
{cmd:inei docs}
{cmd:,} {opt survey(string)}
[{opt dest(string)} {opt yearmin(#)} {opt yearmax(#)}
{opt period(string)} {opt dryrun}]

{pstd}
Descarga documentacion (cuestionarios, diccionarios, fichas tecnicas).

{dlgtab:inei search}

{p 8 17 2}
{cmd:inei search} {it:"query"}
[{cmd:,} {opt survey(string)} {opt year(#)} {opt module(string)}
{opt exact} {opt limit(#)}]

{pstd}
Busca variables por nombre o etiqueta en el indice pre-construido
de 525,000+ variables. La primera ejecucion importa el indice CSV a .dta
(puede tomar unos segundos).

{dlgtab:inei track}

{p 8 17 2}
{cmd:inei track} {it:variable}
[{cmd:,} {opt survey(string)}]

{pstd}
Muestra en que anios y modulos aparece una variable, detectando gaps
temporales. Util para identificar cambios metodologicos.

{dlgtab:inei crawl}

{p 8 17 2}
{cmd:inei crawl}
[{cmd:,} {opt survey(string)} {opt yearmin(#)} {opt yearmax(#)}
{opt refresh} {opt dest(string)} {opt delay(#)}]

{pstd}
Navega el portal INEI para construir o actualizar el catalogo de
encuestas. Requiere conexion a internet y {cmd:curl}.

{dlgtab:inei aliases}

{p 8 17 2}
{cmd:inei aliases}

{pstd}
Muestra la tabla de aliases cortos para encuestas (ej: {bf:enaho} ->
{it:ENAHO}).

{dlgtab:inei stats}

{p 8 17 2}
{cmd:inei stats}

{pstd}
Muestra estadisticas generales del catalogo.


{marker examples}{...}
{title:Examples}

{pstd}Listar todas las encuestas:{p_end}
{phang2}{cmd:. inei list}{p_end}

{pstd}Listar modulos de ENAHO desde 2020:{p_end}
{phang2}{cmd:. inei list, survey(enaho) yearmin(2020) modules}{p_end}

{pstd}Preview de descarga (sin descargar):{p_end}
{phang2}{cmd:. inei download, survey(enaho) yearmin(2024) yearmax(2024) format(STATA) dryrun}{p_end}

{pstd}Descargar ENAHO 2024 en formato STATA:{p_end}
{phang2}{cmd:. inei download, survey(enaho) yearmin(2024) yearmax(2024) format(STATA) dest("./datos")}{p_end}

{pstd}Descargar con documentacion incluida:{p_end}
{phang2}{cmd:. inei download, survey(endes) yearmin(2023) format(STATA) dest("./datos") docs}{p_end}

{pstd}Buscar variables relacionadas a ingreso:{p_end}
{phang2}{cmd:. inei search "ingreso neto"}{p_end}

{pstd}Buscar variable exacta en ENAHO:{p_end}
{phang2}{cmd:. inei search "P208", survey(enaho) exact}{p_end}

{pstd}Seguir variable P208 a traves de los anios:{p_end}
{phang2}{cmd:. inei track P208, survey(enaho)}{p_end}

{pstd}Actualizar catalogo:{p_end}
{phang2}{cmd:. inei crawl}{p_end}

{pstd}Actualizar solo ENAHO 2020+:{p_end}
{phang2}{cmd:. inei crawl, survey(enaho) yearmin(2020)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Basado en {browse "https://github.com/fiorellarmartins/inei-microdatos":inei-microdatos}
(Python) de fiorellarmartins.{p_end}

{pstd}
Version Stata: 2026.{p_end}

{pstd}
Licencia: MIT{p_end}
