// Los cuatro finales del lookup público, con la salida REAL del script.
//
// El panel quedaba con IPv4, ISP, ubicación y bandera todos en "—" y un
// "No response" que no decía nada. La causa: los cuatro colgaban de un
// `curl -4`, y ninguno de los tres últimos necesita IPv4 para nada. Si la ruta
// v4 al proveedor no anda pero la v6 sí, el proveedor contesta lo mismo.
import QtQuick
import "../netindicator/contents/ui/lib" as Lib

Item {    id: h


    // NetState ya no es un singleton: es uno por applet. El test crea el suyo,
    // igual que main.qml.
    Lib.NetState { id: estado }

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }
    function fixture(name) {
        const req = new XMLHttpRequest();
        req.open("GET", "file:///tmp/pub-" + name + ".txt", false);
        req.send(null);
        return req.responseText;
    }

    Component.onCompleted: {
        // 1. Todo bien.
        estado.applyPublicLookup(h.fixture("ok"));
        h.expect("la IPv4 llega", estado.publicIp4, "186.57.139.30");
        h.expect("el ISP también", estado.isp, "AS22927 Telefonica de Argentina");
        h.expect("y el país, que es la bandera", estado.countryCode, "AR");
        h.expect("estado OK", estado.statusText, "OK");

        // 2. La ruta IPv4 al proveedor no anda. Antes esto borraba las cuatro
        //    filas; ahora sólo se desconoce la dirección v4.
        estado.applyPublicLookup(h.fixture("v6only"));
        h.expect("sin IPv4 no se inventa una", estado.publicIp4, "");
        h.expect("pero el ISP sobrevive", estado.isp, "AS22927 Telefonica de Argentina");
        h.expect("y el país, o sea la bandera", estado.countryCode, "AR");
        h.expect("y la ubicación", estado.location, "AR - Berazategui");
        h.expect("y lo dice", estado.statusText, "OK - answered over IPv6");

        // 3. No contestó nadie: se nombra el motivo, y no se borra nada.
        estado.applyPublicLookup(h.fixture("timeout"));
        h.expect("un timeout se nombra", estado.statusText, "No response - timed out");
        h.expect("y no borra el ISP que ya teníamos", estado.isp, "AS22927 Telefonica de Argentina");
        h.expect("ni el país", estado.countryCode, "AR");

        // 4. ipinfo.io limita por IP y devuelve 429 con cuerpo vacío. El
        //    siguiente proveedor de la cadena contesta - con OTRO esquema de
        //    campos, que es justo lo que los extractores genéricos existen para
        //    aguantar: no hay forma de comprobar los nombres de campo de cada
        //    proveedor desde aquí, así que no se adivinan.
        estado.applyPublicLookup(h.fixture("ratelimited"));
        h.expect("un proveedor caído no es el final", estado.publicIp4, "186.57.139.30");
        h.expect("y el ISP sale de otro nombre de campo", estado.isp, "Telefonica de Argentina");
        h.expect("y el país también", estado.countryCode, "AR");
        h.expect("con el nombre largo en la ubicación", estado.location, "Argentina - Berazategui");

        // 5. Un esquema con los datos un nivel adentro.
        estado.applyPublicLookup(h.fixture("anidado"));
        h.expect("un campo anidado también se encuentra", estado.isp, "Telefonica de Argentina");
        h.expect("el país anidado igual", estado.countryCode, "AR");

        // 6. Todos los proveedores rechazan: el código HTTP es la respuesta.
        estado.applyPublicLookup(h.fixture("alldown"));
        h.expect("un rechazo se nombra por su código", estado.statusText, "Provider refused - HTTP 503");

        // 7. El proveedor contestó, pero no JSON: casi siempre su página de error.
        estado.applyPublicLookup(h.fixture("html"));
        h.expect("una respuesta que no es JSON se distingue", estado.statusText, "Provider refused - HTTP 429");

        h.expect("curl 6 es DNS", estado.curlReason(6), "DNS");
        h.expect("curl 7 es sin ruta", estado.curlReason(7), "no route");
        h.expect("un código raro se muestra igual", estado.curlReason(99), "curl 99");
        h.expect("una IPv6 no pasa por IPv4", estado.isIpv4("2802:8010::1"), false);
        h.expect("y una IPv4 sí", estado.isIpv4("192.168.1.39"), true);

        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
