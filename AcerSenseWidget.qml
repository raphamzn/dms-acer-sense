import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "translations.js" as Tr

PluginComponent {
    id: root

    property var telemetry: ({})
    property var gpuData: ({})
    property bool popoutVisible: false
    property string ctlError: ""

    readonly property string lang: pluginData.language || "en"
    readonly property string pillContent: pluginData.pillContent || "cpuTemp"
    readonly property int pollInterval: (pluginData.pollInterval || 4) * 1000
    readonly property int fanQuiet: pluginData.fanQuiet || 40

    readonly property string readerPath: PluginService.pluginDirectory + "/acerSense/acer-read"

    readonly property var profileValues: ["low-power", "quiet", "balanced", "balanced-performance"]
    readonly property var profileLabels: [tr("Power Saver"), tr("Quiet"), tr("Balanced"), tr("Performance")]

    popoutWidth: 380

    function tr(k) {
        return Tr.tr(k, root.lang);
    }

    function profileIcon(p) {
        switch (p) {
        case "low-power":
            return "energy_savings_leaf";
        case "quiet":
            return "bedtime";
        case "balanced":
            return "balance";
        case "balanced-performance":
            return "bolt";
        }
        return "tune";
    }

    function fanPresetIndex(s) {
        if (!s)
            return -1;
        if (s === "0,0")
            return 0;
        if (s === "100,100")
            return 2;
        return 1;
    }

    function pillSecondary() {
        if (root.pillContent === "cpuTemp")
            return (root.telemetry.cpuTemp != null) ? (root.telemetry.cpuTemp + "°") : "";
        if (root.pillContent === "fanRpm")
            return (root.telemetry.fanCpu != null) ? (root.telemetry.fanCpu + " rpm") : "";
        return "";
    }

    function runCtl(args, desc) {
        if (ctlProcess.running)
            return;
        root.ctlError = "";
        ctlProcess.actionDesc = desc;
        ctlProcess.command = ["sudo", "-n", "/usr/local/bin/acer-ctl"].concat(args);
        ctlProcess.running = true;
    }
    function setProfile(p) {
        runCtl(["profile", p], "Profile: " + p);
    }
    function setFan(preset) {
        if (preset === "quiet") {
            runCtl(["fan", String(root.fanQuiet)], "Fan: quiet " + root.fanQuiet + "%");
            return;
        }
        runCtl(["fan", preset], "Fan: " + preset);
    }
    function setBatteryLimit(on) {
        runCtl(["battery-limit", on ? "on" : "off"], "Battery limit: " + (on ? "80%" : "off"));
    }
    function setUsbCharging(v) {
        runCtl(["usb-charging", v], "USB charging: " + v);
    }
    function setGpu(mode) {
        runCtl(["gpu", mode], "GPU: " + mode + " — reboot to apply");
    }

    function refreshSysfs() {
        if (!sysfsProcess.running)
            sysfsProcess.running = true;
    }
    function refreshGpu() {
        if (!gpuProcess.running)
            gpuProcess.running = true;
    }

    Process {
        id: sysfsProcess
        command: ["sh", root.readerPath, "sysfs"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (!t)
                    return;
                try {
                    root.telemetry = JSON.parse(t);
                } catch (e) {
                    console.warn("acerSense sysfs parse:", e);
                }
            }
        }
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSysfs()
    }

    Process {
        id: gpuProcess
        command: ["sh", root.readerPath, "gpu"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (!t)
                    return;
                try {
                    root.gpuData = JSON.parse(t);
                } catch (e) {
                    console.warn("acerSense gpu parse:", e);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.popoutVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshGpu()
    }

    Process {
        id: ctlProcess
        property string actionDesc: ""
        running: false
        stderr: SplitParser {
            onRead: line => {
                if (line.trim())
                    root.ctlError = line.trim();
            }
        }
        onExited: (code, status) => {
            if (code === 0) {
                ToastService.showInfo(ctlProcess.actionDesc);
                root.refreshSysfs();
                if (root.popoutVisible)
                    root.refreshGpu();
            } else {
                ToastService.showError("Failed: " + ctlProcess.actionDesc, root.ctlError || ("exit " + code));
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.profileIcon(root.telemetry.profile)
                color: Theme.primary
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.pillSecondary()
                visible: text !== ""
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: root.profileIcon(root.telemetry.profile)
                color: Theme.primary
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.pillSecondary()
                visible: text !== ""
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    popoutContent: Component {
        Item {
            id: panel

            property var parentPopout: null
            property var closePopout: null
            property string pendingGpu: ""

            implicitHeight: panelCol.implicitHeight
            width: parent ? parent.width : root.popoutWidth

            onParentPopoutChanged: {
                if (parentPopout)
                    root.popoutVisible = Qt.binding(() => parentPopout.shouldBeVisible);
            }

            Column {
                id: panelCol
                width: panel.width
                spacing: Theme.spacingM

                Rectangle {
                    width: parent.width
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    implicitHeight: headerCol.implicitHeight + Theme.spacingM * 2

                    Column {
                        id: headerCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Acer Nitro / Predator"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingL

                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    name: "memory"
                                    size: Theme.iconSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: "CPU " + (root.telemetry.cpuTemp != null ? root.telemetry.cpuTemp : "—") + "°C"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    name: "auto_awesome_mosaic"
                                    size: Theme.iconSizeSmall
                                    color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: "GPU " + (root.gpuData.gpuTemp != null ? root.gpuData.gpuTemp : "—") + "°C"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingL

                            StyledText {
                                text: "Fan CPU: " + (root.telemetry.fanCpu != null ? root.telemetry.fanCpu + " rpm" : "—")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            StyledText {
                                text: "Fan GPU: " + (root.telemetry.fanGpu != null ? root.telemetry.fanGpu + " rpm" : "—")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: root.tr("Power profile")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    DankButtonGroup {
                        width: parent.width
                        model: root.profileLabels
                        currentIndex: root.profileValues.indexOf(root.telemetry.profile)
                        onSelectionChanged: (index, selected) => {
                            if (selected)
                                root.setProfile(root.profileValues[index]);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: root.tr("Fans")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    DankButtonGroup {
                        width: parent.width
                        model: ["Auto", root.tr("Quiet") + " " + root.fanQuiet + "%", "Max"]
                        currentIndex: root.fanPresetIndex(root.telemetry.fanSpeed)
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            if (index === 0)
                                root.setFan("auto");
                            else if (index === 1)
                                root.setFan("quiet");
                            else
                                root.setFan("max");
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.tr("Battery") + " — " + (root.telemetry.battPct != null ? root.telemetry.battPct + "%" : "—") + (root.telemetry.battStatus ? " · " + root.tr(root.telemetry.battStatus) : "") + (root.telemetry.battCycles != null ? " · " + root.telemetry.battCycles + " " + root.tr("cycles") : "")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    DankToggle {
                        width: parent.width
                        text: root.tr("Limit charge to 80%")
                        checked: root.telemetry.battLimiter === 1
                        onToggled: on => root.setBatteryLimit(on)
                    }
                    DankDropdown {
                        width: parent.width
                        text: root.tr("USB charging")
                        currentValue: (root.telemetry.usbCharging == null || root.telemetry.usbCharging === 0) ? "off" : String(root.telemetry.usbCharging)
                        options: ["off", "10", "20", "30"]
                        onValueChanged: v => root.setUsbCharging(v)
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.gpuData.gpuMode != null

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "GPU — " + root.tr("mode") + " " + (root.gpuData.gpuMode || "—") + (root.gpuData.gpuUtil != null ? " · " + root.gpuData.gpuUtil + "% " + root.tr("usage") : "")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: panel.pendingGpu === ""

                        Repeater {
                            model: ["hybrid", "integrated", "nvidia"]
                            DankButton {
                                text: modelData
                                backgroundColor: root.gpuData.gpuMode === modelData ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: root.gpuData.gpuMode === modelData ? Theme.onPrimary : Theme.surfaceText
                                enabled: root.gpuData.gpuMode !== modelData
                                onClicked: panel.pendingGpu = modelData
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: panel.pendingGpu !== ""

                        StyledText {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: root.tr("Switch GPU to") + " '" + panel.pendingGpu + "' — " + root.tr("Save your work — this ends the graphics session and requires a reboot.")
                            color: Theme.warning
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Row {
                            spacing: Theme.spacingS
                            DankButton {
                                text: root.tr("Confirm")
                                backgroundColor: Theme.error
                                textColor: "#FFFFFF"
                                onClicked: {
                                    root.setGpu(panel.pendingGpu);
                                    panel.pendingGpu = "";
                                }
                            }
                            DankButton {
                                text: root.tr("Cancel")
                                backgroundColor: Theme.surfaceContainerHigh
                                textColor: Theme.surfaceText
                                onClicked: panel.pendingGpu = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
