import QtQuick
import qs.Common
import qs.Widgets
import "translations.js" as Tr

FocusScope {
    id: root

    property var pluginService: null

    readonly property var pillKeys: ["none", "cpuTemp", "fanRpm"]
    readonly property var langKeys: ["en", "pt", "es"]
    property string language: "en"
    property string pillContent: "cpuTemp"
    property int fanQuiet: 40
    property int pollInterval: 4

    implicitHeight: col.implicitHeight + Theme.spacingM * 2
    height: implicitHeight

    function tr(k) {
        return Tr.tr(k, root.language);
    }
    function load(key, def) {
        return pluginService ? pluginService.loadPluginData("acerSense", key, def) : def;
    }
    function save(key, val) {
        if (pluginService)
            pluginService.savePluginData("acerSense", key, val);
    }

    Component.onCompleted: {
        language = load("language", "en");
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
                text: root.tr("Language")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
            DankButtonGroup {
                width: parent.width
                model: ["English", "Português", "Español"]
                currentIndex: root.langKeys.indexOf(root.language)
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    root.language = root.langKeys[index];
                    root.save("language", root.language);
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: root.tr("Pill content (next to the icon)")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
            DankButtonGroup {
                width: parent.width
                model: [root.tr("Nothing"), root.tr("CPU temp"), "Fan RPM"]
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
                text: root.tr("GPU temp is intentionally left off the pill: it would query the dGPU continuously and wake it from sleep.")
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
                text: root.tr("Refresh interval (s)")
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
