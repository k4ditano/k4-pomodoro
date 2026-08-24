//  Pomodoro: un temporizador de foco que vive en la island.
//
//  La forma es el argumento. Un pomodoro es una actividad VIVA —empieza,
//  corre un rato y termina— y eso es exactamente lo que una Dynamic Island
//  sabe hacer y una barra normal no: el tiempo que queda viaja en la píldora
//  sin ocupar nada, y cuando una fase acaba la island se abre sola a decirlo.
//
//  ── el tiempo NO se cuenta sumando tics ──────────────────────────
//
//  Se guarda CUÁNDO acaba y se resta del reloj. Contando `restante -= 1` cada
//  segundo se acumula el error de cada tic tarde, y peor: el temporizador se
//  para mientras la máquina duerme, así que al volver de suspender te
//  encontrarías veinte minutos de trabajo que en realidad ya pasaron. Con un
//  instante final, dormir el portátil no engaña a nadie.
//
//  ── lo que este plugin NO hace ───────────────────────────────────
//
//  No manda notificaciones del sistema: para eso haría falta lanzar procesos,
//  y un temporizador no necesita ese permiso. Cuando una fase acaba se abre
//  la island, que es más visible que un aviso y ya está pagado.

import QtQuick
import K4 as K4

K4.Plugin {
    id: raiz

    name: "pomodoro"
    title: K4.Idioma.t("Pomodoro")

    //  Por debajo del lanzador y del centro de control: cuando una fase acaba
    //  esto se abre solo, y abrirse solo encima de lo que estabas haciendo es
    //  de mala educación.
    priority: 40

    islandWidth: 330
    islandHeight: 176

    // ── el estado, que vive en el plugin y no en la vista ─────────
    //
    //  La vista se destruye cada vez que pierdes la island; si el reloj
    //  viviera ahí, cerrarla pararía el pomodoro.
    readonly property var fases: ["parado", "trabajo", "corto", "largo"]
    property string fase: "parado"

    //  El instante en que acaba la fase, en milisegundos del reloj. 0 es «no
    //  hay cuenta en marcha».
    property double finEn: 0

    //  Y cuánto quedaba al pausar, para poder seguir donde estaba.
    property int pausadoEn: 0
    readonly property bool corriendo: fase !== "parado" && finEn > 0

    //  Cuántos tomates llevas en esta ronda. A los cuatro toca descanso largo.
    property int hechos: 0

    // ── lo que se puede ajustar ───────────────────────────────────
    property int minutosTrabajo: 25
    property int minutosCorto: 5
    property int minutosLargo: 15
    property bool sonar: true
    property bool seguirSolo: false

    function duracionDe(f) {
        if (f === "trabajo") return minutosTrabajo * 60
        if (f === "corto") return minutosCorto * 60
        if (f === "largo") return minutosLargo * 60
        return 0
    }

    //  Lo que queda, en segundos. Del reloj, nunca de una suma.
    property int restante: 0

    function recalcular() {
        if (fase === "parado") { restante = 0; return }
        if (finEn <= 0) { restante = pausadoEn; return }
        restante = Math.max(0, Math.round((finEn - Date.now()) / 1000))
    }

    readonly property string reloj: {
        const s = Math.max(0, restante)
        const m = Math.floor(s / 60)
        const r = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    readonly property string comoSeLlama:
        fase === "trabajo" ? K4.Idioma.t("Focus")
        : fase === "corto" ? K4.Idioma.t("Break")
        : fase === "largo" ? K4.Idioma.t("Long break")
        : K4.Idioma.t("Pomodoro")

    readonly property color tono: fase === "trabajo" ? K4.Tema.rojo
        : fase === "parado" ? K4.Tema.apagado : K4.Tema.verde

    // ── el mando ──────────────────────────────────────────────────
    function empezar(f) {
        fase = f
        pausadoEn = 0
        finEn = Date.now() + duracionDe(f) * 1000
        recalcular()
        apuntar()
    }

    function pausar() {
        if (!corriendo)
            return
        pausadoEn = restante
        finEn = 0
        apuntar()
    }

    function seguir() {
        if (fase === "parado" || finEn > 0)
            return
        finEn = Date.now() + Math.max(1, pausadoEn) * 1000
        pausadoEn = 0
        recalcular()
        apuntar()
    }

    function alternar() {
        if (fase === "parado") empezar("trabajo")
        else if (corriendo) pausar()
        else seguir()
    }

    function parar() {
        fase = "parado"
        finEn = 0
        pausadoEn = 0
        hechos = 0
        restante = 0
        apuntar()
    }

    //  Qué toca después de la que acaba de terminar.
    function siguienteFase() {
        if (fase !== "trabajo")
            return "trabajo"
        return (hechos % 4 === 0 && hechos > 0) ? "largo" : "corto"
    }

    function saltar() {
        if (fase === "parado")
            return
        if (fase === "trabajo")
            hechos += 1
        const que = siguienteFase()
        empezar(que)
    }

    //  Se acabó la fase: se anuncia y se decide si sigue sola.
    function terminar() {
        if (fase === "trabajo")
            hechos += 1
        const que = siguienteFase()

        //  Un empujón a la island: es una cosa física que ha pasado, y la
        //  barra sabe moverse. El host arbitra —uno cada medio segundo— así
        //  que no hay que medirlo aquí.
        K4.Isla.efecto(raiz.name, "empujon", 0.9)
        if (sonar)
            campana.sonar()

        if (seguirSolo) {
            empezar(que)
        } else {
            fase = que
            finEn = 0
            pausadoEn = duracionDe(que)
            recalcular()
            apuntar()
        }

        //  Y se abre a decirlo. Esto es lo único que este plugin hace sin que
        //  se lo pidan, y es la razón de que exista en una island.
        avisoSolo = true
        abierto = true
        cerrarSolo.restart()
    }

    //  El aviso se cierra solo si no le haces caso: se abrió sin permiso, así
    //  que se va sin que tengas que echarlo.
    property Timer cerrarSolo: Timer {
        interval: 9000
        onTriggered: if (!K4.Isla.raton) raiz.abierto = false
    }

    // ── el latido ─────────────────────────────────────────────────
    //
    //  Un segundo, y SOLO mientras hay cuenta en marcha. Parado no late.
    property Timer latido: Timer {
        interval: 1000
        repeat: true
        running: raiz.corriendo
        onTriggered: {
            raiz.recalcular()
            if (raiz.restante <= 0)
                raiz.terminar()
        }
    }

    // ── el indicador de la píldora ────────────────────────────────
    //
    //  Lo que hace que esto valga la pena: el tiempo que queda se ve sin abrir
    //  nada y sin ocupar sitio.
    //
    //  Y se repinta solo cuando alguien lo está viendo. `K4.Isla.aLaVista` es
    //  falso con la barra escondida, apartada por una captura, o en un monitor
    //  que no la enseña — y refrescar un texto cada segundo para nadie es
    //  repintar la escena entera cada segundo para nadie. Al volver a la vista
    //  se pinta de golpe, que para eso está el `onALaVistaChanged`.
    function pintarPildora() {
        if (fase === "parado") {
            K4.Pildora.quitar("pomodoro.reloj")
            return
        }
        if (!K4.Isla.aLaVista)
            return
        K4.Pildora.registrar("pomodoro.reloj",
                             (corriendo ? "" : "❙❙ ") + reloj,
                             0xF051B,          // md-timer_outline
                             tono, 60, true)
    }

    onRelojChanged: pintarPildora()
    onFaseChanged: pintarPildora()
    onCorriendoChanged: pintarPildora()

    property Connections mirarISLA: Connections {
        target: K4.Isla
        function onALaVistaChanged() { raiz.pintarPildora() }
    }

    //  Un clic en el indicador abre el plugin, como el resto de la casa.
    property Connections desdePildora: Connections {
        target: K4.Pildora
        function onInvocado(id) {
            if (id === "pomodoro.reloj")
                raiz.abierto = true
        }
    }

    // ── la island ─────────────────────────────────────────────────
    property bool abierto: false
    active: abierto
    function close() { abierto = false }

    function toggle() {
        avisoSolo = false          // lo abres tú: el teclado es tuyo
        abierto = !abierto
    }

    //  ── cerrarlo, que es la mitad que faltaba ────────────────────
    //
    //  Sin esto no había forma de cerrarlo: el ESC no llegaba y un toque en el
    //  fondo abría el centro de control ENCIMA, que es peor que no hacer nada.
    //
    //  El ESC no llega solo. Una capa recibe teclas si el compositor se las da,
    //  y «bajo demanda» significa cuando PINCHAS la superficie — pero a esto se
    //  llega desde el centro de aplicaciones, desde un atajo o porque se abre
    //  sola, y ahí no pincha nadie. La documentación de `K4.Plugin` lo dice con
    //  todas las letras: lo que se abre, se mira y se cierra quiere
    //  `grabKeyboard`, aunque no se escriba en ello.
    //
    //  Pero NO cuando se abre sola. `grabKeyboard` deja al escritorio sin
    //  teclado mientras esté abierto, y esto se abre por su cuenta al acabar
    //  una fase: quedarse con tus teclas nueve segundos porque un temporizador
    //  ha terminado es robar. Se coge el teclado solo si lo has abierto tú, y
    //  el aviso se conforma con el ratón.
    property bool avisoSolo: false
    grabKeyboard: abierto && !avisoSolo

    //  Y un toque en el fondo lo cierra. Sin declararlo, el host entiende que
    //  el toque no es tuyo y abre el centro de control por encima.
    handlesBackgroundTap: true
    onBackgroundTapped: raiz.close()

    //  Si te acercas a un aviso, deja de ser un aviso: se queda hasta que lo
    //  cierres, y con el teclado, para que el ESC funcione como en todo lo
    //  demás.
    property Connections deLaIsla: Connections {
        target: K4.Isla
        function onRatonChanged() {
            if (K4.Isla.raton && raiz.abierto)
                raiz.avisoSolo = false
        }
    }

    view: Component {
        PomodoroView { plugin: raiz }
    }

    // ── el aviso ──────────────────────────────────────────────────
    property K4.Sonido campana: K4.Sonido {
        fuente: campana.delSistema("complete")
        volumen: 0.6
    }

    // ── lo que se guarda ──────────────────────────────────────────
    //
    //  Incluido el instante final: reiniciar la barra a mitad de un pomodoro
    //  no debería costarte el pomodoro.
    property K4.Guardado guardado: K4.Guardado {
        plugin: "pomodoro"
        onCargado: function (d) {
            if (!d)
                return
            if (d.minutosTrabajo > 0) raiz.minutosTrabajo = d.minutosTrabajo
            if (d.minutosCorto > 0) raiz.minutosCorto = d.minutosCorto
            if (d.minutosLargo > 0) raiz.minutosLargo = d.minutosLargo
            if (d.sonar !== undefined) raiz.sonar = !!d.sonar
            if (d.seguirSolo !== undefined) raiz.seguirSolo = !!d.seguirSolo
            if (d.hechos > 0) raiz.hechos = d.hechos

            //  Y la cuenta a medias, si la había y sigue teniendo sentido.
            //  Comprobada contra la lista: un fichero a mano con cualquier
            //  otra cosa dejaría una fase que no sabe pintar nadie.
            if (raiz.fases.indexOf(d.fase) > 0) {
                raiz.fase = d.fase
                if (d.finEn > Date.now()) {
                    raiz.finEn = d.finEn
                } else if (d.pausadoEn > 0) {
                    raiz.pausadoEn = d.pausadoEn
                } else {
                    //  Acabó mientras la barra no estaba. No se anuncia una
                    //  campana con media hora de retraso: se deja lista la
                    //  siguiente y que la empiece quien vuelva.
                    raiz.fase = raiz.siguienteFase()
                    raiz.pausadoEn = raiz.duracionDe(raiz.fase)
                }
                raiz.recalcular()
                raiz.pintarPildora()
            }
        }
    }

    function apuntar() {
        guardado.guardar({
            minutosTrabajo: minutosTrabajo, minutosCorto: minutosCorto,
            minutosLargo: minutosLargo, sonar: sonar, seguirSolo: seguirSolo,
            fase: fase, finEn: finEn, pausadoEn: pausadoEn, hechos: hechos
        })
    }

    // ── sus ajustes, en Ajustes ───────────────────────────────────
    K4.Ajustes {
        plugin: "pomodoro"
        grupo: K4.Idioma.t("Pomodoro")
        opciones: [
            { id: "trabajo", tipo: "eleccion", glifo: 0xF051B,   // md-timer_outline
              nombre: K4.Idioma.t("Focus length"),
              desc: K4.Idioma.t("How long one tomato lasts"),
              alternativas: [{ codigo: "15", nombre: "15 min" },
                             { codigo: "25", nombre: "25 min" },
                             { codigo: "50", nombre: "50 min" }] },
            { id: "corto", tipo: "eleccion", glifo: 0xF0176,     // md-coffee
              nombre: K4.Idioma.t("Short break"),
              desc: K4.Idioma.t("After each tomato"),
              alternativas: [{ codigo: "3", nombre: "3 min" },
                             { codigo: "5", nombre: "5 min" },
                             { codigo: "10", nombre: "10 min" }] },
            { id: "largo", tipo: "eleccion", glifo: 0xF0092,     // md-beach
              nombre: K4.Idioma.t("Long break"),
              desc: K4.Idioma.t("Every four tomatoes"),
              alternativas: [{ codigo: "10", nombre: "10 min" },
                             { codigo: "15", nombre: "15 min" },
                             { codigo: "30", nombre: "30 min" }] },
            { id: "seguirSolo", glifo: 0xF006A,                  // md-autorenew
              nombre: K4.Idioma.t("Chain phases on their own"),
              desc: K4.Idioma.t("Off, each phase waits for you to start it") },
            { id: "sonar", glifo: 0xF009A,                       // md-bell
              nombre: K4.Idioma.t("Ring when a phase ends"),
              desc: K4.Idioma.t("The desktop's own chime") }
        ]
        valores: ({ trabajo: String(raiz.minutosTrabajo),
                    corto: String(raiz.minutosCorto),
                    largo: String(raiz.minutosLargo),
                    seguirSolo: raiz.seguirSolo, sonar: raiz.sonar })
        onCambiado: function (id, valor) {
            if (id === "trabajo") raiz.minutosTrabajo = Number(valor) || 25
            else if (id === "corto") raiz.minutosCorto = Number(valor) || 5
            else if (id === "largo") raiz.minutosLargo = Number(valor) || 15
            else if (id === "seguirSolo") raiz.seguirSolo = valor === true
            else if (id === "sonar") raiz.sonar = valor === true
            else return

            //  Cambiar la duración con una cuenta parada la deja lista con la
            //  nueva; con una cuenta EN MARCHA no se toca, que mover la meta a
            //  mitad de carrera es lo contrario de lo que sirve un pomodoro.
            if (!raiz.corriendo && raiz.fase !== "parado") {
                raiz.pausadoEn = raiz.duracionDe(raiz.fase)
                raiz.recalcular()
            }
            raiz.apuntar()
        }
    }

    // ── el atajo y las órdenes ────────────────────────────────────
    //
    //  Hijos sueltos y NO propiedades con nombre: `services` es la propiedad
    //  por defecto de K4.Plugin y es donde el gestor busca los IpcHandler para
    //  apagarlos al destruir el plugin. Metido en una propiedad no los
    //  encuentra, y recargar en caliente deja el target en manos del cadáver.
    K4.Atajo {
        name: "pomodoro"
        description: "Pomodoro: empezar, pausar o seguir"
        onPressed: raiz.alternar()
    }

    K4.Ipc {
        target: "k4.pomodoro"

        //  Ojo con los dos «alternar» que hay aquí: este es el del RELOJ
        //  —empezar, pausar, seguir—, que es lo que se pulsa mil veces. El del
        //  panel son `ver` y `cerrar`, y existen porque sin ellos no había
        //  manera de abrirlo desde fuera: ni para un guion, ni para probarlo.
        function alternar(): void { raiz.alternar() }
        function ver(): void { raiz.avisoSolo = false; raiz.abierto = true }
        function cerrar(): void { raiz.close() }
        function empezar(): void { raiz.empezar("trabajo") }
        function pausar(): void { raiz.pausar() }
        function saltar(): void { raiz.saltar() }
        function parar(): void { raiz.parar() }

        function estado(): string {
            return JSON.stringify({
                fase: raiz.fase, corriendo: raiz.corriendo,
                restante: raiz.restante, reloj: raiz.reloj,
                hechos: raiz.hechos, abierto: raiz.abierto,
                minutos: { trabajo: raiz.minutosTrabajo,
                           corto: raiz.minutosCorto, largo: raiz.minutosLargo }
            })
        }
    }
}
