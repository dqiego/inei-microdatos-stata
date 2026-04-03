{smcl}
{* *! version 2.0.0  2026-04-03}{...}
{viewerjumpto "Quick Start" "inei##quickstart"}{...}
{viewerjumpto "Syntax" "inei##syntax"}{...}
{viewerjumpto "Description" "inei##description"}{...}
{viewerjumpto "Commands" "inei##commands"}{...}
{viewerjumpto "Workflows" "inei##workflows"}{...}
{viewerjumpto "ENAHO Modules" "inei##enaho"}{...}
{viewerjumpto "Examples" "inei##examples"}{...}
{viewerjumpto "Troubleshooting" "inei##troubleshooting"}{...}
{viewerjumpto "Author" "inei##author"}{...}
{title:Title}

{phang}
{bf:inei} {hline 2} Acceso a microdatos del INEI (Peru)


{marker quickstart}{...}
{title:Quick Start}

{pstd}Cargar sumarias ENAHO 2024 en memoria:{p_end}
{phang2}{cmd:. inei use, survey(enaho) year(2024) module(34) clear}{p_end}

{pstd}Buscar variables relacionadas a ingreso:{p_end}
{phang2}{cmd:. inei search "ingreso", survey(enaho) yearmin(2024)}{p_end}

{pstd}Ver variables de un modulo sin descargar:{p_end}
{phang2}{cmd:. inei describe, survey(enaho) year(2024) module(05)}{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:inei} {it:subcomando} [{cmd:,} {it:opciones}]

{synoptset 25 tabbed}{...}
{synopthdr:Subcomandos}
{synoptline}
{p2coldent:* {bf:Cargar datos}}(requiere internet en primera descarga){p_end}
{synopt:{opt use}}Descargar y cargar modulo en memoria{p_end}
{synopt:{opt merge}}Combinar modulos del mismo anio{p_end}
{synopt:{opt append}}Apilar modulo a traves de multiples anios{p_end}
{p2coldent:* {bf:Explorar catalogo}}{p_end}
{synopt:{opt list}}Listar encuestas y modulos disponibles{p_end}
{synopt:{opt search}}Buscar variables en el indice (525k+){p_end}
{synopt:{opt describe}}Ver variables de un modulo sin descargar{p_end}
{synopt:{opt track}}Seguir variable a traves de los anios{p_end}
{p2coldent:* {bf:Descargar}}{p_end}
{synopt:{opt download}}Descargar microdatos (ZIPs){p_end}
{synopt:{opt docs}}Descargar documentacion{p_end}
{p2coldent:* {bf:Utilidades}}{p_end}
{synopt:{opt cite}}Generar cita bibliografica{p_end}
{synopt:{opt aliases}}Mostrar aliases de encuestas{p_end}
{synopt:{opt stats}}Estadisticas del catalogo{p_end}
{synopt:{opt crawl}}Actualizar catalogo desde el portal{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:inei} proporciona acceso programatico al portal de microdatos del
{browse "https://proyectos.inei.gob.pe/microdatos/":INEI} (Instituto Nacional
de Estadistica e Informatica de Peru).

{pstd}
El paquete permite buscar, listar, descargar y cargar en memoria microdatos
de 67 encuestas (ENAHO, ENDES, EPEN, CENAGRO, etc.) que abarcan desde 1994
hasta 2025, con mas de 5,900 modulos descargables y 525,000+ variables
indexadas.

{pstd}
Basado en el paquete Python {browse "https://github.com/fiorellarmartins/inei-microdatos":inei-microdatos}
de fiorellarmartins.

{pstd}
{bf:Requisitos:} Stata 14+. Se requiere {cmd:curl} para descarga y crawling
(preinstalado en Windows 10+, macOS y Linux).


{marker commands}{...}
{title:Commands}

{dlgtab:inei use — Cargar datos en memoria}

{p 8 17 2}
{cmd:inei use}
{cmd:,} {opt survey(string)} {opt year(#)} {opt module(string)}
[{opt clear} {opt format(STATA|CSV|SPSS)} {opt dest(string)}
{opt file(string)} {opt nodownload}]

{pstd}
Descarga el ZIP del modulo, lo descomprime, busca el .dta y lo carga en
memoria. Si el archivo ya fue descargado, usa la cache local (no re-descarga).

{pstd}
Estampa metadata en {cmd:char _dta[]} que se puede consultar con
{cmd:char list _dta[]}.

{pmore}{opt survey()} — nombre o alias de encuesta (ej: enaho, endes){p_end}
{pmore}{opt year()} — anio de la encuesta{p_end}
{pmore}{opt module()} — codigo o nombre parcial del modulo{p_end}
{pmore}{opt clear} — reemplaza datos en memoria{p_end}
{pmore}{opt dest()} — directorio de cache (default: ~/ado/personal/inei_cache/){p_end}
{pmore}{opt file()} — nombre parcial del .dta si hay multiples en el ZIP{p_end}

{dlgtab:inei merge — Combinar modulos}

{p 8 17 2}
{cmd:inei merge}
{cmd:,} {opt survey(string)} {opt year(#)} {opt modules(string)}
[{opt clear} {opt on(string)} {opt format(string)} {opt dest(string)}]

{pstd}
Carga multiples modulos de una misma encuesta-anio y los combina con
{cmd:merge 1:1}. Detecta automaticamente las variables de identificacion
(merge keys) segun la encuesta.

{pmore}{opt modules()} — lista de codigos de modulo separados por espacio (ej: 01 34){p_end}
{pmore}{opt on()} — especificar manualmente las variables de merge (override deteccion automatica){p_end}

{pstd}
Keys de merge por defecto:{break}
  ENAHO hogar: {bf:conglome vivienda hogar}{break}
  ENAHO individuo: {bf:conglome vivienda hogar codperso}{break}
  ENDES: {bf:caseid}

{dlgtab:inei append — Apilar anios}

{p 8 17 2}
{cmd:inei append}
{cmd:,} {opt survey(string)} {opt module(string)}
{opt yearmin(#)} {opt yearmax(#)}
[{opt clear} {opt gen(varname)} {opt format(string)} {opt dest(string)}]

{pstd}
Carga el mismo modulo para multiples anios y los apila con {cmd:append}.
Util para construir paneles o series de tiempo.

{pmore}{opt gen(varname)} — crea variable que identifica el anio de origen{p_end}

{pstd}
Nota: si el set de variables cambia entre anios (cambio metodologico),
se muestra un warning.

{dlgtab:inei list — Listar encuestas}

{p 8 17 2}
{cmd:inei list}
[{cmd:,} {opt survey(string)} {opt yearmin(#)} {opt yearmax(#)}
{opt period(string)} {opt modules}]

{pstd}
Muestra las encuestas disponibles en el catalogo. Con {opt modules}
muestra el detalle de cada modulo incluyendo codigos de descarga.

{dlgtab:inei search — Buscar variables}

{p 8 17 2}
{cmd:inei search} {it:"query"}
[{cmd:,} {opt survey(string)} {opt year(#)} {opt yearmin(#)} {opt yearmax(#)}
{opt module(string)} {opt exact} {opt limit(#)}]

{pstd}
Busca variables por nombre o etiqueta en el indice pre-construido
de 525,000+ variables. La primera ejecucion importa el CSV a .dta.

{pmore}{opt exact} — buscar coincidencia exacta en nombre de variable{p_end}
{pmore}{opt limit(#)} — maximo de resultados a mostrar (default: 20){p_end}

{pstd}
Muestra codigo de modulo entre corchetes y un hint de uso con {cmd:inei use}.

{dlgtab:inei describe — Ver variables de un modulo}

{p 8 17 2}
{cmd:inei describe}
{cmd:,} {opt survey(string)} {opt year(#)} {opt module(string)}

{pstd}
Muestra la lista de variables con labels de un modulo especifico, sin
necesidad de descargar los datos. Usa el indice pre-construido.

{dlgtab:inei track — Seguir variable entre anios}

{p 8 17 2}
{cmd:inei track} {it:variable}
[{cmd:,} {opt survey(string)}]

{pstd}
Muestra en que anios y modulos aparece una variable. Detecta gaps
temporales que pueden indicar cambios metodologicos.

{dlgtab:inei download — Descargar ZIPs}

{p 8 17 2}
{cmd:inei download}
{cmd:,} {opt survey(string)}
[{opt format(CSV|STATA|SPSS)} {opt dest(string)}
{opt yearmin(#)} {opt yearmax(#)} {opt period(string)}
{opt layout(string)} {opt nofallback} {opt dryrun} {opt docs}]

{pstd}
Descarga microdatos como archivos ZIP. El formato por defecto es STATA.
Si no esta disponible, intenta otro formato (a menos que se use {opt nofallback}).

{pstd}
Layouts: {bf:default} ({it:encuesta/anio/periodo/}),
{bf:flat} ({it:encuesta/}), {bf:by-year} ({it:encuesta/anio/}),
{bf:by-format} ({it:formato/encuesta/anio/}).

{dlgtab:inei docs — Descargar documentacion}

{p 8 17 2}
{cmd:inei docs}
{cmd:,} {opt survey(string)}
[{opt dest(string)} {opt yearmin(#)} {opt yearmax(#)}
{opt period(string)} {opt dryrun}]

{pstd}
Descarga documentacion (cuestionarios, diccionarios, fichas tecnicas).

{dlgtab:inei cite — Generar cita}

{p 8 17 2}
{cmd:inei cite}
{cmd:,} {opt survey(string)} {opt year(#)} [{opt format(apa|bibtex|text)}]

{pstd}
Genera cita bibliografica para los datos. Formatos: {bf:apa} (default),
{bf:bibtex}, {bf:text}.

{dlgtab:inei aliases — Tabla de aliases}

{p 8 17 2}
{cmd:inei aliases}

{pstd}
Muestra la tabla de aliases cortos para encuestas (ej: {bf:enaho} ->
{it:ENAHO}).

{dlgtab:inei stats — Estadisticas}

{p 8 17 2}
{cmd:inei stats}

{pstd}
Muestra estadisticas generales del catalogo. Incluye fecha de ultima
actualizacion y warning si tiene mas de 3 meses.

{dlgtab:inei crawl — Actualizar catalogo}

{p 8 17 2}
{cmd:inei crawl}
[{cmd:,} {opt survey(string)} {opt yearmin(#)} {opt yearmax(#)}
{opt refresh} {opt dest(string)} {opt delay(#)} {opt debug}]

{pstd}
Navega el portal INEI para construir o actualizar el catalogo de
encuestas y modulos. Requiere conexion a internet y {cmd:curl}.


{marker workflows}{...}
{title:Workflows comunes}

{pstd}{bf:1. Encontrar variable -> cargar datos}{p_end}

{phang2}{cmd:. inei search "ingreso", survey(enaho) yearmin(2024)}{p_end}
{phang2}{it:(anotar el codigo de modulo del resultado, ej: 05)}{p_end}
{phang2}{cmd:. inei use, survey(enaho) year(2024) module(05) clear}{p_end}

{pstd}{bf:2. Combinar modulos (ej: vivienda + sumarias)}{p_end}

{phang2}{cmd:. inei merge, survey(enaho) year(2024) modules(01 34) clear}{p_end}

{pstd}{bf:3. Construir panel longitudinal}{p_end}

{phang2}{cmd:. inei append, survey(enaho) module(34) yearmin(2019) yearmax(2024) gen(anio) clear}{p_end}
{phang2}{cmd:. tab anio}{p_end}

{pstd}{bf:4. Explorar modulo antes de descargar}{p_end}

{phang2}{cmd:. inei describe, survey(enaho) year(2024) module(05)}{p_end}

{pstd}{bf:5. Verificar disponibilidad de variable en el tiempo}{p_end}

{phang2}{cmd:. inei track P208, survey(enaho)}{p_end}

{pstd}{bf:6. Generar cita para tesis/paper}{p_end}

{phang2}{cmd:. inei cite, survey(enaho) year(2024) format(apa)}{p_end}


{marker enaho}{...}
{title:Modulos ENAHO mas usados}

{pstd}
Referencia rapida de los modulos mas comunes de ENAHO. Use el codigo
en {cmd:inei use, module(XX)}.

{p2colset 5 12 14 2}{...}
{p2col:Code}Nombre{p_end}
{p2line}
{p2col:{bf:01}}Caracteristicas de la Vivienda y del Hogar{p_end}
{p2col:{bf:02}}Caracteristicas de los Miembros del Hogar{p_end}
{p2col:{bf:03}}Educacion{p_end}
{p2col:{bf:04}}Salud{p_end}
{p2col:{bf:05}}Empleo e Ingresos{p_end}
{p2col:{bf:06}}Gastos en Salud{p_end}
{p2col:{bf:07}}Gastos de Alimentos y Bebidas{p_end}
{p2col:{bf:08}}Gastos en Alimentos Fuera del Hogar{p_end}
{p2col:{bf:09}}Gastos en Transporte y Comunicaciones{p_end}
{p2col:{bf:10}}Gastos en Esparcimiento, Diversion y Cultura{p_end}
{p2col:{bf:11}}Gastos de Transferencias{p_end}
{p2col:{bf:15}}Gastos en Vestido y Calzado{p_end}
{p2col:{bf:16}}Gastos de Muebles y Enseres{p_end}
{p2col:{bf:17}}Gastos de Otros Bienes y Servicios{p_end}
{p2col:{bf:18}}Equipamiento del Hogar{p_end}
{p2col:{bf:22}}Produccion Agropecuaria{p_end}
{p2col:{bf:34}}Sumarias (variables resumen){p_end}
{p2col:{bf:37}}Gobernabilidad, Democracia y Transparencia{p_end}
{p2col:{bf:77}}Ingresos del Trabajador Independiente{p_end}
{p2col:{bf:84}}Participacion Ciudadana{p_end}
{p2col:{bf:85}}Programas Sociales{p_end}
{p2line}

{pstd}
Nota: Los codigos pueden variar entre anios. Use {cmd:inei list, survey(enaho) yearmin(2024) modules}
para ver la lista completa de un anio especifico.


{marker examples}{...}
{title:Examples}

{pstd}{bf:Cargar datos}{p_end}

{phang2}{cmd:. inei use, survey(enaho) year(2024) module(34) clear}{p_end}
{phang2}{cmd:. describe}{p_end}
{phang2}{cmd:. char list _dta[]}{p_end}

{pstd}{bf:Merge de modulos}{p_end}

{phang2}{cmd:. inei merge, survey(enaho) year(2024) modules(01 34) clear}{p_end}

{pstd}{bf:Panel longitudinal}{p_end}

{phang2}{cmd:. inei append, survey(enaho) module(34) yearmin(2020) yearmax(2024) gen(anio) clear}{p_end}

{pstd}{bf:Buscar variables}{p_end}

{phang2}{cmd:. inei search "ingreso neto"}{p_end}
{phang2}{cmd:. inei search "P208", survey(enaho) exact}{p_end}
{phang2}{cmd:. inei search "educacion", survey(endes) yearmin(2020) yearmax(2023)}{p_end}

{pstd}{bf:Explorar modulo}{p_end}

{phang2}{cmd:. inei describe, survey(enaho) year(2024) module(05)}{p_end}

{pstd}{bf:Tracking de variable}{p_end}

{phang2}{cmd:. inei track P208, survey(enaho)}{p_end}

{pstd}{bf:Listar encuestas}{p_end}

{phang2}{cmd:. inei list}{p_end}
{phang2}{cmd:. inei list, survey(enaho) yearmin(2020) modules}{p_end}

{pstd}{bf:Descargar archivos}{p_end}

{phang2}{cmd:. inei download, survey(enaho) yearmin(2024) yearmax(2024) format(STATA) dryrun}{p_end}
{phang2}{cmd:. inei download, survey(enaho) yearmin(2024) yearmax(2024) format(STATA) dest("./datos")}{p_end}

{pstd}{bf:Cita bibliografica}{p_end}

{phang2}{cmd:. inei cite, survey(enaho) year(2024) format(apa)}{p_end}
{phang2}{cmd:. inei cite, survey(enaho) year(2024) format(bibtex)}{p_end}

{pstd}{bf:Actualizar catalogo}{p_end}

{phang2}{cmd:. inei crawl}{p_end}
{phang2}{cmd:. inei crawl, survey(enaho) yearmin(2020)}{p_end}


{marker troubleshooting}{...}
{title:Troubleshooting}

{pstd}{bf:Error: "curl" no reconocido}{p_end}
{pmore}Windows 10+ incluye curl. Si tiene una version anterior, descargue
curl de {browse "https://curl.se/download.html"} y agreguelo al PATH.{p_end}

{pstd}{bf:Error: no se pudo conectar al portal}{p_end}
{pmore}Verifique su conexion a internet y que puede acceder a
{browse "https://proyectos.inei.gob.pe/microdatos/"} en su navegador.{p_end}

{pstd}{bf:Error: modulo no encontrado}{p_end}
{pmore}Use {cmd:inei list, survey(X) yearmin(Y) modules} para ver los
codigos de modulo disponibles para esa encuesta y anio.{p_end}

{pstd}{bf:El primer inei search tarda mucho}{p_end}
{pmore}La primera ejecucion importa el indice de 525k variables desde CSV
a .dta. Las busquedas posteriores son rapidas.{p_end}

{pstd}{bf:Encoding/caracteres raros en labels}{p_end}
{pmore}El portal INEI usa Latin-1/Windows-1252. Stata 14+ almacena UTF-8
internamente. Si ve caracteres extraños, intente con Stata 14+ o posterior.{p_end}

{pstd}{bf:Error: datos en memoria no guardados}{p_end}
{pmore}Use la opcion {bf:clear} para reemplazar datos en memoria, o guarde
primero con {cmd:save}.{p_end}

{pstd}{bf:El merge produce obs inesperados}{p_end}
{pmore}Los modulos ENAHO pueden tener diferentes niveles de observacion
(hogar vs individuo). El merge auto-detecta el nivel, pero puede especificar
keys manualmente con {opt on(var1 var2 ...)}.{p_end}

{pstd}{bf:El append muestra warning de cambio de variables}{p_end}
{pmore}Esto indica que INEI cambio la metodologia o variables entre anios.
Los datos se apilan de todos modos, pero variables faltantes tendran
valores missing.{p_end}


{marker author}{...}
{title:Author}

{pstd}
Basado en {browse "https://github.com/fiorellarmartins/inei-microdatos":inei-microdatos}
(Python) de fiorellarmartins.{p_end}

{pstd}
Version Stata: {browse "https://github.com/dqiego/inei-microdatos-stata"}{p_end}

{pstd}
Version: 2.0.0 (2026-04-03){p_end}

{pstd}
Licencia: MIT{p_end}
