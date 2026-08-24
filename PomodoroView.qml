//  La cara del pomodoro cuando la island está desplegada.
//
//  Lo que se ve es el tiempo y poco más, a propósito: la cuenta se lee de un
//  vistazo desde la píldora y esto es donde se toca. Un anillo, el reloj
//  grande, en qué fase estás, cuántos tomates llevas de la ronda y tres
//  botones.
//
//  El `plugin` se lo pasa el propio plugin —`view: Component { PomodoroView {
//  plugin: raiz } }`— porque el host no inyecta nada. Sin esa línea la vista
//  arranca con «Required property plugin was not initialized» y sale en
//  blanco.

import QtQuick
import QtQuick.Shapes
import K4 as K4

K4.Aparicion {
    id: vista

    required property var plugin

    //  Cuánto se ha consumido de la fase, de 0 a 1. Con la fase parada el
    //  anillo se queda entero, que es lo que dice «aquí no hay nada corriendo».
    readonly property real avance: {
        const total = vista.plugin.duracionDe(vista.plugin.fase)
        if (total <= 0)
            return 0
        return Math.max(0, Math.min(1, 1 - vista.plugin.restante / total))
    }

    anchors.fill: parent

    Item {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height

        // ── el anillo ─────────────────────────────────────────────
        //
        //  Un `Shape` y no una barra: el círculo dice «esto da vueltas» sin
        //  leer nada. Sin `layer.enabled`: son dos arcos finos, y una capa con
        //  MSAA para esto es pagar una textura por nada.
        Shape {
            id: anillo
            width: 96
            height: 96
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            antialiasing: true

            readonly property real radio: 42
            readonly property real centro: 48

            //  El carril completo, por debajo.
            ShapePath {
                fillColor: "transparent"
                strokeColor: K4.Tema.carril
                strokeWidth: 5
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: anillo.centro; centerY: anillo.centro
                    radiusX: anillo.radio; radiusY: anillo.radio
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            //  Y lo consumido encima. Se anima el barrido para que el segundo
            //  no dé un salto de seis grados cada vez.
            ShapePath {
                fillColor: "transparent"
                strokeColor: vista.plugin.tono
                strokeWidth: 5
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    id: arco
                    centerX: anillo.centro; centerY: anillo.centro
                    radiusX: anillo.radio; radiusY: anillo.radio
                    startAngle: -90
                    sweepAngle: vista.avance * 360

                    //  La vista solo existe mientras la island está abierta,
                    //  así que esta animación se destruye con ella. Es la
                    //  diferencia con un bucle infinito colgado de la píldora,
                    //  que seguiría corriendo sin que nadie lo vea.
                    Behavior on sweepAngle {
                        NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
                    }
                }
            }

            //  Dentro del anillo, los tomates de la ronda.
            Row {
                anchors.centerIn: parent
                spacing: 5

                Repeater {
                    model: 4

                    delegate: Rectangle {
                        required property int index
                        width: 6
                        height: 6
                        radius: 3
                        color: index < (vista.plugin.hechos % 4 === 0
                                        && vista.plugin.hechos > 0
                                        ? 4 : vista.plugin.hechos % 4)
                            ? vista.plugin.tono : K4.Tema.carril
                    }
                }
            }
        }

        // ── el reloj y los mandos ─────────────────────────────────
        Column {
            anchors.left: anillo.right
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            K4.Etiqueta {
                text: vista.plugin.comoSeLlama
                color: vista.plugin.tono
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            K4.Etiqueta {
                text: vista.plugin.reloj
                font.pixelSize: 40
                font.weight: Font.Light
            }

            K4.Etiqueta {
                //  Sin fase no hay nada que contar, y con una en marcha la
                //  cuenta de tomates es lo único que no se ve en el anillo.
                text: vista.plugin.fase === "parado"
                    ? K4.Idioma.t("Ready when you are")
                    : K4.Idioma.f("%1 done today", vista.plugin.hechos)
                color: K4.Tema.apagado
                font.pixelSize: 11
            }

            Item { width: 1; height: 6 }

            Row {
                spacing: 14

                K4.Boton {
                    //  Un solo botón para empezar, pausar y seguir: es el que
                    //  se pulsa siempre y no merece que haya que elegir cuál.
                    glifo: vista.plugin.corriendo
                        ? String.fromCodePoint(0xF03E4)   // md-pause
                        : String.fromCodePoint(0xF040A)   // md-play
                    tamano: 22
                    color: vista.plugin.tono
                    onPulsado: vista.plugin.alternar()
                }

                K4.Boton {
                    glifo: String.fromCodePoint(0xF04AD)  // md-skip-next
                    tamano: 20
                    color: K4.Tema.apagado
                    activo: vista.plugin.fase !== "parado"
                    onPulsado: vista.plugin.saltar()
                }

                K4.Boton {
                    glifo: String.fromCodePoint(0xF0709)  // md-restart
                    tamano: 20
                    color: K4.Tema.apagado
                    activo: vista.plugin.fase !== "parado"
                    onPulsado: vista.plugin.parar()
                }
            }
        }
    }
}
