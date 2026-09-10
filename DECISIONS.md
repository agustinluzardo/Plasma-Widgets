Tres decisiones, y por qué:

1. NADA DE COMPONENTES CRUZANDO DE ARCHIVO.
   El port ponía `sourceComponent: body.horizontalBarPill` - un Component
   definido en el scope de main.qml, instanciado por el loader de
   representaciones de Plasma, que corre en OTRO contexto. El propio header del
   plugin de DMS avisa de esto ("a bound component refuses to be created outside
   its creation context"). Ahora cada representación es su PROPIO archivo y lee
   el estado de un singleton, así que no hay contexto que cruzar.

2. CANVAS EN VEZ DE SHAPE PARA PAC-MAN.
   Shape necesita `preferredRendererType` (Qt 6.6+) para verse bien, que es
   justo lo que este contenedor no puede ejercitar - o sea, lo que se dibuja
   acá no era lo que se dibujaba allá. Canvas anda en cualquier Qt y en
   cualquier backend, incluido software. Con eso el dibujo pasa a ser
   verificable de verdad desde acá.

3. EL PANEL MANDA.
   Sin MouseArea tapando, sin implicitWidth peleando con Layout, sin chrome
   propio. La representación compacta declara su tamaño y nada más; el popup lo
   dimensiona y posiciona Plasma.

## Por qué Pac-Man era invisible (y ningún cambio en PacmanStrip.qml lo arreglaba)

`main.qml` declaraba **sólo** `compactRepresentation`. En
`libplasma/src/plasmaquick/appletquickitem.cpp`,
`AppletQuickItemPrivate::appletShouldBeExpanded()` empieza así:

```cpp
if (!fullRepresentation) {
    // If a full representation wasn't specified, the one and only
    // representation of the plasmoid are our direct contents, so we
    // consider it always expanded
    return true;
}
```

Esa comprobación corre **antes** de mirar `preferredRepresentation`. O sea que
`preferredRepresentation: compactRepresentation` era código muerto: el applet se
consideraba expandido, `compactRepresentationCheck()` tomaba la rama `full`,
`createFullRepresentationItem()` devolvía `nullptr` porque no había ninguna, y el
`if (item)` de abajo no hacía nada.

Resultado: ninguna representación creada, `currentRepresentationItem` nulo,
`connectLayoutAttached()` nunca llamado (por eso tampoco había hints de tamaño),
y **`PacmanStrip` nunca se instanciaba**. Sin error, sin aviso, sin icono de
fallo — un hueco con forma de applet en el panel. Por eso siete rondas de
cambios dentro de `PacmanStrip.qml` no cambiaron absolutamente nada: ese archivo
no se estaba ejecutando.

NetIndicator funcionaba desde el principio porque declara las dos
representaciones (`NetPill` y `NetPanel`). Esa era la única diferencia
relevante entre los dos widgets.

Arreglo: `DesktopList.qml` como representación completa. Existe porque Plasma la
exige, no porque el plugin de DMS tuviera un popout, así que es lo más chico que
se justifica: la lista de escritorios que la tira dibuja, en palabras, con el
número de ventanas y el actual marcado. El clic del ratón sigue yendo a las
celdas de la tira — el envoltorio `CompactApplet` maneja hover y teclado, no
clics — así que el comportamiento en el panel no cambia.

Los tests de píxeles no podían ver esto: todos instancian `PacmanStrip`
directamente. `AppletTest.qml` transcribe `appletShouldBeExpanded()` y afirma que
un panel horizontal resuelve a la representación **compacta**; `run.sh` además
falla estáticamente si un `main.qml` declara `compactRepresentation` sin
`fullRepresentation`.

## Por qué el pill de red no abría nada

Abrir el popup es tarea de la **representación compacta**, no del shell.
`CompactApplet.qml` envuelve la representación en un `ToolTipArea` y un
`FocusScope` que manejan hover y teclado; nada convierte un clic en una
expansión. `DefaultCompactRepresentation.qml` lo hace él mismo:

```qml
property PlasmoidItem plasmoidItem
MouseArea {
    property bool wasExpanded: false
    onPressed: wasExpanded = plasmoidItem.expanded
    onClicked: plasmoidItem.expanded = !wasExpanded
}
```

`NetPill.qml` traía un comentario afirmando lo contrario ("el izquierdo se lo
queda el panel, que es lo que abre el popout") y sólo aceptaba `Qt.RightButton`.
Resultado: el clic izquierdo no hacía absolutamente nada.

`wasExpanded` se lee en el **press** a propósito: un popup abierto se cierra al
perder el foco antes de que llegue el clic, así que alternar contra el valor en
vivo lo reabriría al instante y parecería trabado.

De paso, el botón derecho ya no se consume: en Plasma es el que abre el menú del
widget ("Configurar…", "Quitar"). La acción secundaria de DMS pasó al botón del
medio, que es el gesto de activación secundaria de Plasma.

## Por qué las páginas de settings se veían sueltas

`Kirigami.FormData` es una propiedad **adjunta** que `FormLayout` lee sólo de sus
hijos **directos**. Las dos páginas envolvían todos los controles en un
`ColumnLayout`, así que la columna de etiquetas entera ("Minimum slots:",
"Palette:", "Show:"…) no se dibujaba nunca. No da error: sólo queda una lista de
controles sin nombres.

Aparte, `KCM.SimpleKCM` toma **un** item de contenido. El toggle de debug estaba
declarado fuera del `FormLayout`, así que no se dibujaba nunca — y su
`property alias cfg_debugOverlay` seguía resolviendo, que es por lo que nada se
quejó.

`tests/check_settings_page.py` comprueba las dos cosas. La primera versión de esa
comprobación tenía el mismo agujero que el bug que buscaba: comparaba contra
dónde **empieza** el FormLayout, así que un control puesto después de su cierre
pasaba igual. Ahora cuenta llaves y exige que esté dentro del bloque.

## Por qué el fantasma se veía mal

Corría con `Shape.GeometryRenderer`, con el argumento de que "la única curva de
un fantasma es la cúpula de la cabeza". Es falso: la cúpula es un arco de 180
grados y los cuatro pies son `PathQuad`. El renderer geométrico triangula las
cinco y el sprite sale facetado. El original de DMS usa `CurveRenderer` en las
dos formas; el port ahora también, y `run.sh` lo comprueba.

## Por qué el widget de red no listaba ninguna VPN

`probeScript` es un array de líneas de shell unido con `.join("; ")`. Ese
separador mete un punto y coma donde la sintaxis no lo admite:

```
... | while IFS= read -r l; do;   u=${l%%:*}; ...;   case "$t" in vpn|wireguard);     ... ;;;   esac; done
```

`do;`, `wireguard);` y `;;;` son tres errores de sintaxis, y `sh -c` analiza el
script **entero** antes de ejecutar una sola línea. O sea que el probe no corría
nunca: ni dispositivos, ni direcciones, ni perfiles. Lo que se veía era la lista
de VPN vacía con tres cargadas en NetworkManager.

Ahora se une con `"\n"`, que es separador válido en todos esos sitios.
`tests/ProbeTest.qml` vuelca el script real desde el QML, `run.sh` lo pasa por
`bash -n`, lo corre contra un `nmcli` de mentira en `tests/fakebin/` que
reproduce la máquina del usuario, y `VpnTest.qml` comprueba que los tres
perfiles lleguen parseados.

## Por qué ningún control del panel hacía nada

`NetState.saveSetting()` escribía sólo a través de `root.pluginService`, el
objeto que exponía el host de DMS. En Plasma es `null`, así que cada chip y cada
stepper del panel se dibujaba y no hacía absolutamente nada, sin un solo aviso.

`main.qml` intentaba puentearlo con
`Lib.NetState.savePluginData = (key, value) => ...`, pero **esa propiedad no
estaba declarada** en NetState: la asignación tira, y con ella se llevaba el
`refreshAll()` de la línea siguiente. Ahora está declarada y `saveSetting` la
prefiere.

## Por qué no se podía agrandar la IP

El tamaño del texto del pill venía de `Theme.barTextSize(barThickness,
barConfig?.fontScale, ...)`. En DMS `barConfig` era la barra y el usuario lo
ajustaba allí; en Plasma es `null`, así que el texto quedaba clavado al grosor
del panel sin ningún control, mientras el icono sí tenía `iconOffset`.
Añadido `textOffset` en paralelo exacto al del icono: esquema, página de
settings y stepper con vista previa en el panel.

## El mock de configuración tiene que seguir al esquema

`textOffset` y `debugOverlay` estaban en `main.xml` y no en
`PlasmoidConfigMock.qml`, así que los tests leían `undefined` y ejercitaban el
valor por defecto en vez del real. `run.sh` compara ahora las claves de los dos
esquemas contra el mock.

## Por qué el widget se releía en bucle

`NetService.applyProbe()` emitía `networkStatusChanged()` al final de **cada**
lectura. `NetState` escucha esa señal y responde con `refreshAll()`, que vuelve
a correr el mismo probe. Bucle cerrado: el widget se releía tan rápido como
contestara nmcli - "checking" permanente y la latencia saltando sin parar.

Estuvo latente todo este tiempo porque el script tenía el error de sintaxis: la
salida vacía se descartaba antes de llegar a `applyProbe`, así que la señal no
se emitía nunca. **Arreglar el probe encendió el bucle.**

La señal significa ahora "la red cambió", no "acabamos de releer la red": se
compara una firma del estado y sólo se emite cuando difiere.

La firma se calcula sobre lo **parseado**, nunca sobre el texto crudo del probe.
`ip -j addr` trae `valid_life_time` / `preferred_life_time`, que bajan un
segundo por segundo en una dirección DHCP, así que el texto difiere en cada
lectura aunque la red esté quieta - el arreglo ingenuo habría parecido correcto
y habría seguido en bucle. `RefreshTest.qml` falsifica las dos versiones.

## Lo que al port de Pac-Man le faltaba de la versión de DMS

El port se hizo antes de que la versión de DMS creciera, así que le faltaban
cuatro ajustes: `slotBackground` (none / corridor / corridorTint / rails),
`slotBackgroundColorMode`, `slotBackgroundColor` y `mouthPellet`. Portados
textuales del original; el bloque de dibujo vuelve a ser el mismo.

Un cambio sí hubo que hacer: en DMS el fondo lo dibuja el `pillHost`, que
**crece** para dejarle sitio. En un panel de Plasma el alto lo fija el panel, así
que anclar los rieles a `parent.top` / `parent.bottom` los pegaría a los bordes
del panel y se leerían como una línea del panel, no como el corredor del juego.
El fondo se dibuja alrededor de un contenedor centrado del tamaño de la tira más
su margen, y ese tamaño es el que el panel lee en los hints de Layout - si no,
el corredor caería fuera del applet y el panel lo recortaría.

`BackgroundTest.qml` cuenta píxeles **del color del corredor**, no píxeles
pintados: con los rieles ocultos las 19 afirmaciones sobre propiedades pasaban
igual, porque la tira ya dibuja sprites. `pixels.py` acepta ahora
`--color RRGGBB [mínimo]`.

## Por qué el logo de la distro era un cuadrado blanco

Se construía como `<ID>-logo` y se le pasaba a `Kirigami.Icon` sin más. En Arch
el ID de os-release es `arch`, pero el icono se llama `archlinux-logo`: ningún
tema tiene `arch-logo`, así que lo que se dibujaba era el cuadrado de icono
ausente. Un nombre inventado no es un icono.

`os-release` tiene un campo para exactamente esto: `LOGO=`, definido por la spec
como "el nombre de un icono según la Icon Theme Specification". Se prueba ése
primero, después las variantes derivadas del ID (`<ID>-logo`, `<ID>linux-logo`,
`distributor-logo-<ID>`, `<ID>`), y **cada candidato se busca en disco** antes de
aceptarlo. Si ninguno existe queda vacío y el logo no se dibuja, que es mejor que
un cuadrado.

La ruta de os-release sale de `NETINDICATOR_OSRELEASE` con `/etc/os-release` por
defecto: sin esa costura el test sólo podría comprobar la distro sobre la que
corre, que es justamente la que no falla. `run.sh` simula Arch con y sin el
icono instalado, y con `LOGO=` explícito.

## Por qué se perdían la IPv4, el ISP, la ubicación y la bandera a la vez

Los cuatro colgaban de un solo `curl -4`. Si la ruta IPv4 al proveedor no anda
-bloqueada, sin ruta, o el proveedor limitando por IP- no hay respuesta, y con
ella se van el ISP, la ciudad y el país, o sea la bandera. **Ninguno de esos tres
necesita IPv4**: si la petición sin forzar llega por IPv6, el proveedor contesta
lo mismo.

Ahora, si `-4` vuelve vacío se repite sin forzar. Lo único que queda sin saberse
es la dirección v4, y se dice así ("OK - answered over IPv6") en vez de vaciar el
panel.

**Eso no alcanzó.** El estado seguía diciendo "No response" *sin motivo*, o sea
`rc=0` con cuerpo vacío: curl conectó y no imprimió nada. Eso no es un problema
de red, es HTTP - un 429, un 403, o una redirección que `curl` sin `-L` descarta
en silencio. Faltaban tres cosas:

- **`-L`**, porque una redirección sin seguir se ve idéntica a una respuesta
  vacía.
- **El código HTTP** (`-w '%{http_code}'`). "Provider refused - HTTP 429" es una
  respuesta útil; "No response" no lo es.
- **Una cadena de proveedores.** Uno solo es un punto único de fallo, y si el
  bucle de refresco que arreglamos antes estuvo pegándole a ipinfo.io tan rápido
  como contestara nmcli, que ese proveedor limite por IP es lo esperable.

Los proveedores de respaldo traen otros nombres de campo, y **no hay forma de
comprobar esos esquemas desde aquí** (el proxy de salida bloquea las tres APIs).
Así que no se adivinan: `_flatten` recorre el JSON -el nivel de arriba y uno de
anidado, donde viven `connection.isp` o `asn.name`- y `_pick` / `findAddress`
eligen por forma y por nombre de clave. El test cubre cuatro esquemas distintos,
incluido uno anidado. La dirección que devuelve el proveedor sólo va a la fila de IPv4 si
**parece** una IPv4; meter ahí la v6 sería mentir.

Además el código de salida de curl se tiraba: "No response" no distingue un
timeout de un DNS que no resuelve de una ruta que no existe. Ahora se nombra, y
un cuerpo que no es JSON (casi siempre la página de error del proveedor) se
distingue de un cuerpo vacío.

Y `refreshPublic()` por defecto no reintentaba **ninguna** vez, así que un fallo
suelto se quedaba en pantalla hasta el tick siguiente, cinco minutos después.
Ahora son dos intentos separados tres segundos.

## La cadena de proveedores no saltaba al siguiente

El diagnóstico del usuario lo dejó a la vista: ipinfo.io no devuelve un cuerpo
vacío al limitar por IP, devuelve el 429 **con** cuerpo:

```
https://ipinfo.io/json  -4: rc=0 http=429  {"status":429,"error":{"title":"Rate limit hit",...
https://ifconfig.co/json    : rc=0 http=200  {"ip":"186.57.139.30","country":"Argentina",...
https://ipwho.is/           : rc=0 http=200  {"ip":"186.57.139.30","success":true,...
```

La condición de la cadena era `[ -n "$body" ]`, así que aceptaba la página de
error de ipinfo y **nunca llegaba a los otros dos**, que contestaban 200 con los
datos correctos. Ahora exige además un código 2xx: el estado decide, no el
tamaño del cuerpo. El fixture del test usa el 429 real, con cuerpo.

## Los avisos `cfg_<algo>Default` del diálogo de settings NO son un bug nuestro

`AppletConfiguration.qml` hace `config.keys().forEach(key => props["cfg_" + key]
= config[key])`, y `KConfigPropertyMap` expone, por cada entrada del esquema,
también una clave `<nombre>Default`. Plasma intenta ponerlas en la página, la
página no las declara, y se queja una vez por ajuste.

**No hay que declararlas.** `saveConfig()` escribe de vuelta `config[key] =
page["cfg_" + key]` para toda clave que la página tenga, así que declararlas
haría que se escribieran claves `*Default` en el archivo de configuración del
usuario. Y no somos un caso especial: en todos los applets de plasma-workspace
hay **cero** apariciones de `cfg_*Default`, o sea que los propios de KDE producen
los mismos avisos. `cfg_length` y `cfg_expanding` son de la misma familia: claves
que el panel guarda en la config del applet y que la página no conoce.

## El botón del medio no alternaba entre IP de LAN y de túnel

No era un fallo: la alternancia vive detrás del ajuste **Local IP source →
"Swap on middle click"**, y el valor de fábrica es `lan`, con el que el botón del
medio refresca. Con el ajuste puesto funciona - `ToggleTest.qml` recorre los tres
modos con un túnel arriba.

Lo que **sí** estaba mal: con "Swap on middle click" puesto pero sin ningún túnel
llevando tráfico, el gesto invertía `showingTunnelIp`, un booleano que
`displayLocalIp` ignora en ese caso. O sea que no alternaba ni refrescaba: no
hacía absolutamente nada, y encima dejaba el estado invertido, así que el clic
siguiente -ya con el túnel arriba- salía al revés. Ahora, sin dos direcciones que
mostrar, cae al refresco.

## Auditoría a fondo de los dos plugins

**El aviso `Created graphical object was not placed in the graphics scene` no es
nuestro y no se puede arreglar desde aquí.** Cadena completa, verificada en el
fuente:

| | |
|---|---|
| `plasma-desktop/.../AppletConfiguration.qml:365` | `app` es un `Kirigami.ApplicationItem`, así que `app.pageStack` es un `PageRow` |
| `kirigami/src/controls/PageRow.qml:860` | `pagesLogic` es un **`QtObject`** |
| `kirigami/src/controls/PageRow.qml:982` | `pageComp.createObject(pagesLogic, properties)` - a propósito: *"The parent needs to be set otherwise a reference needs to be kept around to avoid the page being garbage collected"* |
| `qtdeclarative/src/qml/qml/qqmlcomponent.cpp:1781-1799` | con padre dado, si las auto-parent de QtQuick devuelven `IncompatibleParent` (un Item dentro de un no-Item) → `qmlWarning(me)` |

`qmlWarning(me)` culpa al objeto creado, o sea a **nuestra** página, y por eso
apunta a su línea raíz. Le pasa a toda página de Kirigami que exista.
Reproducido aislado: `createObject(unItem)` calla, `createObject(unQtObject)`
avisa. No se filtra del diagnóstico: esconder lo que no se entiende es cómo se
entierra un error de verdad después.

**Inyección de shell por el destino del ping (arreglado).** El comando se armaba
con `JSON.stringify(effectivePingTarget)`, que produce comillas **dobles** - y
dentro de comillas dobles el shell sigue interpolando `$`, `` ` `` y `\`.
`pingTarget` es un campo de texto libre en la página de settings, así que un
valor como `x$(comando)` se ejecutaba. Demostrado: con `JSON.stringify` los dos
payloads del test crean sus archivos; con `Sh.quote` (comillas simples) ninguno.
`run.sh` lo comprueba de las dos formas: estática (ningún comando de shell se
cita con `JSON.stringify`) y ejecutando el comando real con la carga dentro.

**Paridad con los originales de DMS: completa.**
Pac-Man 21/21 ajustes. NetIndicator 33/33, más `textOffset`, que en DMS no hacía
falta porque el tamaño del texto lo daba la barra.

**Revisado y sin hallazgos:** ningún `console.log`, `TODO` ni `FIXME` en el
código que se envía; el resto de los comandos usan `Sh.quote` o un argv sin
shell (`notify-send`, `dbus-send`); los `catch` documentan qué se traga cada uno
y por qué, incluido el único vacío (`ip -j route get`), donde dejar los valores
como estaban ES la respuesta correcta.

**Anotado, no tocado:** quedan propiedades muertas de la superficie del host de
DMS (`parentScreen`, `section`, `pluginId`, `widgetThickness` en Pac-Man) y
varias de la capa `Theme` que estos dos widgets no usan. Son inertes; borrarlas
es churn con riesgo y sin beneficio observable.

## Auditoría de memoria

**Un leak real, en `Sh._pending` (arreglado).** La cola de callbacks por comando
llevaba escrito su propio supuesto: *"dos comandos idénticos en vuelo serían
indistinguibles, así que los callbacks se encolan y se contestan en orden"*. El
supuesto es falso. El motor ejecutable de Plasma **deduplica por nombre de
source**: dos comandos idénticos en vuelo son UN source y producen UNA respuesta,
no dos. Se hacía `shift()` de un callback y el resto quedaba huérfano, con su
clave viva en el mapa para toda la sesión. Dos clics rápidos sobre el mismo
escritorio alcanzaban. Ahora la respuesta se reparte a todos los que preguntaron.

**Y un SIGSEGV encontrado al arreglarlo.** La primera versión del arreglo
borraba la clave con `delete` en cada respuesta. Eso crashea el motor:

```
QV4::Runtime::StoreElement → Object::internalPut → Object::insertMember → SIGSEGV
```

Insertar y borrar claves a repetición sobre un objeto JS guardado en una
propiedad `var` corrompe la tabla interna de V4; en Qt 6.4 revienta tras unos
cientos de ciclos. Reproducido, acotado con `gdb`, y falsificado: con `delete`
crashea a los ~200 comandos, con `splice` aguanta 2000. La cola se vacía **en
sitio** y la clave no se borra nunca — el conjunto de comandos distintos es
finito, así que el mapa no crece. (El usuario corre Qt 6.11, donde puede que no
se manifieste; el patrón se evita igual.)

**Fugas en marcha: ninguna.** Estrés con muestreo de `VmRSS`, mucho más duro que
el uso real:

| | carga | 60 s |
|---|---|---|
| Pac-Man | un cambio de escritorio cada 80 ms (750 reconstrucciones) | **+328 kB** |
| Network Indicator | sonda + lookup completos cada 40 ms (1500 ciclos) | **+108 kB** |

En la realidad Network Indicator hace **un** ciclo cada 300 s. Los dos son ruido
de heap que el GC recupera, no retención.

**El instrumento mentía primero.** La primera medición daba 6.2 MB de "fuga" en
Network Indicator. Eran del mock: `DsMock.calls` crecía sin límite y se copiaba
entero en cada `concat`, o sea O(n²). Acotado el log, la fuga desapareció. Medir
con un instrumento que no se auditó no es medir.

**Consumo.** ~10 MB por widget en un proceso frío, y la mayor parte es cargar los
módulos QML que cada uno importa por primera vez (`QtQuick.Shapes`,
`QtQuick.Layouts`, los singletons). Dentro de plasmashell esos módulos ya están
cargados, así que el costo marginal real es bastante menor. Los dos deltas
limpios sí son atribuibles: **~200 kB por slot extra** de Pac-Man, y **~5.6 MB el
popup** de Network Indicator, que Plasma sólo construye al abrirlo.

**Timers: todos gateados.** Los dos repetitivos de Pac-Man (el reloj de sprites a
130 ms y el watchdog a 3 s) llevan `root.visible` en su condición de `running`.
Los de Network Indicator corren sólo mientras hay una operación de VPN en vuelo o
en el ciclo de refresco configurado.

## Iconos propios

Los dos widgets salían en "Añadir widgets" con iconos prestados del tema —
un globo genérico y los cuatro cuadrados de `preferences-desktop-virtual`.

Cómo se pone uno propio, verificado en el fuente y no adivinado
(`plasma-workspace/components/shellprivate/plasmaappletitemmodel.cpp:58-78`):
Plasma prueba tres cosas en orden — un icono del tema llamado igual que el
plugin id; después un `Icon` **que empiece con `/`**, que resuelve *dentro del
paquete* vía `pkg.filePath("", icon)`; y si no, un nombre del tema. Con
`fileType` vacío, `kpackage/src/kpackage/package.cpp:327,342` arma
`<paquete>/contents` + `/` + `<icon>`, así que `"/images/x.svg"` cae en
`contents/images/x.svg`.

El de Pac-Man está dibujado con **la geometría del propio widget**: el arco
barre 360-2*30 grados y cierra al centro igual que su `ShapePath`, y el fantasma
lleva los cuatro pies festoneados con las profundidades alternas de
`footDepth()`. Dos desvíos deliberados: el amarillo no es el `#FFFF00` de la
cabina y el pellet no es blanco, porque sobre un fondo claro los dos
desaparecen y el icono tiene que leerse en los dos temas. Renderizados y
mirados a 96, 32 y 22 px sobre claro y oscuro antes de darlos por buenos.

## Las descripciones, en inglés las dos

La de Network Indicator había quedado en castellano mientras la de Pac-Man
estaba en inglés, y se veían una al lado de la otra en el diálogo.

`check_metadata.py` lo comprueba, pero su **primera versión no habría servido**:
buscaba tildes, y la descripción culpable —"Tu IP local y los perfiles VPN de
NetworkManager, desde el panel"— no tiene ni una. Ahora busca palabras
funcionales del castellano, que son las que no se pueden esquivar al escribir
una frase. Falsificada devolviéndole el texto viejo: lo caza por `desde, el,
los, tu, y`.

## Segunda auditoría: las zonas que la primera no tocó

**`perMonitor` era un ajuste muerto, y ahora funciona.** Estaba en el esquema, en
la página y en `pluginData`, y nadie lo leía. Lo justificaba este comentario, que
es **falso**:

> *Plasma has one set of virtual desktops for the whole session - they are not
> per monitor the way Hyprland workspaces are*

Los escritorios son globales, pero **cuál está actual puede diferir por salida**:
`VirtualDesktopInfo::WaylandPrivate` mantiene `currentDesktops[outputName]`,
poblado por `PlasmaVirtualDesktop::outputEntered`. No es teoría — el Pager de KDE
se apoya exactamente en eso (`plasma-desktop/applets/pager/pagermodel.cpp:363`) y
el Task Manager también (`taskfilterproxymodel.cpp:390`). `currentDesktopByScreenName`
**sí** es `Q_INVOKABLE`, al contrario que `position()` y `requestActivate()`.

La tira toma su pantalla igual que el Pager: `screenName: root.Screen.name`
(`applets/pager/qml/main.qml:144`). Como es una **función** y no una propiedad,
ningún binding se entera solo: hace falta escuchar `currentDesktopForScreenChanged`,
y se escucha desde la tira, no desde el singleton, porque este archivo ya aprendió
que un `Connections` guardado en una propiedad del singleton es frágil.

Límite honesto: `requestActivateOnScreen` **no** es invocable, así que hacer clic
en un slot cambia el escritorio de todas las pantallas. Está dicho en el texto del
ajuste.

**Un nombre de VPN con dos puntos salía con la barra invertida.** `nmcli -t`
escapa `:` como `\:`, el diseño pone el campo largo al final para no tener que
desescapar… y nadie desescapaba el valor final. "VPN: Canada" se veía
`VPN\: Canada`. Una sola pasada, no dos reemplazos seguidos, que con `\\:` se
pisarían.

**El flujo de VPN: auditado, sano, y ahora cubierto.** `vpnIsBusy` deja todos los
botones grises y sólo se baja dentro de un refresh; si ese refresh no llega, el
panel se congela — que es lo que pasó en DMS. El watchdog que lo rescata está
bien puesto (`Timer` cada 2 s mientras hay ocupación, con gracia de 30 s, o 6 s
si la operación provablemente no puede contestar). No tenía **ni un test**: ahora
son 18, incluidos el rescate, las dos gracias y el `vpnToggle` del popout.
Falsificado anulando `recoverStuckVpnBusy()`.

**Hallazgo abierto: el port perdió el modo vertical.** Los dos originales de DMS
declaran `verticalBarPill` además del horizontal
(`PacmanWorkspaces.qml:1262`, `NetIndicator.qml:849`). En el port **no queda
ninguno**, y ningún widget mira `Plasmoid.formFactor`; el `isVertical` de
NetState está clavado en `false`. En un panel vertical el contenedor fuerza el
ancho al grosor del panel y toma el alto de los hints, así que la tira horizontal
quedaría recortada.

Y expone un punto ciego de la auditoría anterior: medí la paridad contando
**claves de settings**, no capacidades. Por eso dio 21/21 y 33/33 y aun así
faltaba una función entera.
