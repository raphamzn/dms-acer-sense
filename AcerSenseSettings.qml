import QtQuick
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    readonly property var pillKeys: ["none", "cpuTemp", "fanRpm"]
    property string pillContent: "cpuTemp"
    property int fanQuiet: 40
    property int pollInterval: 4

    implicitHeight: col.implicitHeight + Theme.spacingM * 2
    height: implicitHeight

    function load(key, def) {
        return pluginService ? pluginService.loadPluginData("acerSense", key, def) : def;
    }
    function save(key, val) {
        if (pluginService)
            pluginService.savePluginData("acerSense", key, val);
    }

    Component.onCompleted: {
        pillContent = load("pillContent", "cpuTemp");
        fanQuiet = load("fanQuiet", 40);
        pollInterval = load("pollInterval", 4);
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        StyledText {
            text: "Acer Sense"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: "Conteúdo da pill (ao lado do ícone)"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
            DankButtonGroup {
                width: parent.width
                model: ["Nada", "Temp CPU", "Fan RPM"]
                currentIndex: root.pillKeys.indexOf(root.pillContent)
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    root.pillContent = root.pillKeys[index];
                    root.save("pillContent", root.pillContent);
                }
            }
            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Temp da GPU fica fora da pill de propósito: leria a dGPU continuamente e a acordaria do sono."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: "Fan Quiet (%)"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
            DankDropdown {
                width: parent.width
                currentValue: String(root.fanQuiet)
                options: ["30", "40", "50", "60"]
                onValueChanged: v => {
                    root.fanQuiet = parseInt(v);
                    root.save("fanQuiet", root.fanQuiet);
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: "Intervalo de atualização (s)"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
            DankDropdown {
                width: parent.width
                currentValue: String(root.pollInterval)
                options: ["2", "4", "6", "10"]
                onValueChanged: v => {
                    root.pollInterval = parseInt(v);
                    root.save("pollInterval", root.pollInterval);
                }
            }
        }
    }
}
