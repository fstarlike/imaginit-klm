import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "imagineit.klm"

  property bool popupOpen: false
  property bool addingLanguage: false
  property string searchText: ""
  property var snapshotData: ({})
  property var enabledLayouts: []
  property var availableLayouts: []
  property string shortcut: "none"
  property bool shortcutRuntimeActive: true
  property bool shortcutRepairAttempted: false
  property bool osdEnabled: true
  property int osdDuration: 950
  property string activeName: ""
  property int activeIndex: 0
  property string activeKeyboard: ""
  property bool initialized: false
  property bool osdVisible: false
  property string osdLanguage: ""
  property string osdCode: ""
  property bool refreshPending: false

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string ctlPath: homeDir + "/.config/omarchy/plugins/imagineit.klm/bin/klmctl"
  readonly property string barLabel: Model.friendlyName(activeName)
  readonly property var addCandidates: Model.filteredAvailable(availableLayouts, enabledLayouts, searchText, 14)

  function close() {
    popupOpen = false
    addingLanguage = false
    searchText = ""
  }

  function togglePopup() {
    popupOpen = !popupOpen
    if (popupOpen) refresh()
    else close()
  }

  function refresh() {
    if (snapshotProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    snapshotProc.command = [ctlPath, "snapshot"]
    snapshotProc.running = true
  }

  function applySnapshot(data) {
    if (!data || !data.state) return
    snapshotData = data
    enabledLayouts = data.state.layouts || []
    availableLayouts = data.available || []
    shortcut = String(data.state.shortcut || "none")
    shortcutRuntimeActive = !data.runtime || data.runtime.shortcutActive !== false
    osdEnabled = data.state.osd !== false
    osdDuration = Number(data.state.osdDuration || 950)
    if (data.active) {
      activeName = String(data.active.activeName || activeName || "")
      activeIndex = Number(data.active.activeIndex || 0)
      activeKeyboard = String(data.active.keyboard || "")
    }
    initialized = true
    if (shortcut === "alt-shift" && enabledLayouts.length > 1 && !shortcutRuntimeActive && !shortcutRepairAttempted) {
      shortcutRepairAttempted = true
      repairShortcutTimer.restart()
    }
  }

  function runAction(args) {
    if (actionProc.running) return
    var cmd = [ctlPath]
    for (var i = 0; i < args.length; i++) cmd.push(String(args[i]))
    actionProc.command = cmd
    actionProc.running = true
  }

  function switchTo(index) {
    runAction(["switch", String(index)])
  }

  function addLayout(code) {
    runAction(["add-layout", code])
    addingLanguage = false
    searchText = ""
  }

  function removeLayout(code) {
    if (enabledLayouts.length <= 1) return
    runAction(["remove-layout", code])
  }

  function toggleAltShift() {
    runAction(["set-shortcut", shortcut === "alt-shift" ? "none" : "alt-shift"])
  }

  function toggleOsd() {
    runAction(["set-osd", osdEnabled ? "off" : "on"])
  }

  function openWebsite() {
    if (websiteProc.running) return
    websiteProc.command = ["xdg-open", "https://imagineit.online/"]
    websiteProc.running = true
  }

  function languageNameForCode(code) {
    for (var i = 0; i < availableLayouts.length; i++) {
      var item = availableLayouts[i]
      if (item && String(item.code) === String(code)) return String(item.name || code)
    }
    return String(code || "")
  }

  function parseActiveLayoutEvent(event) {
    var parts = Model.eventParts(event)
    var keyboard = parts[0]
    var next = parts[1]
    if (!Model.isTypedKeyboard(keyboard) || !next) return

    activeKeyboard = keyboard
    var changed = next !== activeName
    activeName = next
    if (changed && initialized && osdEnabled) showOsd(next)
    eventRefresh.restart()
  }

  function showOsd(name) {
    osdLanguage = Model.friendlyName(name)
    osdCode = Model.initials(name)
    osdVisible = true
    osdHide.restart()
  }

  function currentScreenName() {
    var w = button.QsWindow.window
    return w && w.screen ? String(w.screen.name || "") : ""
  }

  function shouldShowOsdHere() {
    var focused = Hyprland.focusedMonitor
    if (!focused || !focused.name) return true
    var own = currentScreenName()
    return own === "" || own === String(focused.name)
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "activelayout") root.parseActiveLayoutEvent(event)
      else if (name === "configreloaded") eventRefresh.restart()
    }
  }

  Timer {
    id: repairShortcutTimer
    interval: 180
    repeat: false
    onTriggered: root.runAction(["repair-shortcut"])
  }

  Timer {
    id: eventRefresh
    interval: 250
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: osdHide
    interval: Math.max(350, root.osdDuration)
    repeat: false
    onTriggered: root.osdVisible = false
  }

  Process {
    id: snapshotProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.applySnapshot(JSON.parse(text || "{}"))
        } catch (e) {
          console.warn("imagineit KLM: invalid snapshot", e)
        }
      }
    }
    onRunningChanged: {
      if (!running && root.refreshPending) root.refresh()
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) actionRefresh.restart()
  }

  Process {
    id: websiteProc
    stderr: StdioCollector { waitForEnd: true }
  }

  Timer {
    id: actionRefresh
    interval: 260
    repeat: false
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barLabel
    fontSize: Style.font.caption
    horizontalMargin: 7
    tooltipText: root.activeName ? (root.activeName + " · click to manage languages") : "imagineit KLM"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.runAction(["switch", "next"])
      else root.togglePopup()
    }
    onWheelMoved: function(delta) {
      root.runAction(["switch", delta > 0 ? "prev" : "next"])
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    contentWidth: panel.fittedContentWidth(Style.space(370))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight + Style.space(12) + footerBlock.implicitHeight, Style.space(610))

    Item {
      anchors.fill: parent

    ScrollView {
      id: scrollArea
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: footerBlock.top
      anchors.bottomMargin: Style.space(12)
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: contentColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: contentColumn
        width: Math.max(1, scrollArea.availableWidth)
        spacing: Style.space(12)

        Item {
          width: parent.width
          implicitHeight: Math.max(Style.space(48), titleColumn.implicitHeight)

          Column {
            id: titleColumn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "imagineit KLM"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: "Keyboard languages"
              color: Util.alpha(Color.popups.text, 0.58)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            width: Style.space(42)
            height: Style.space(42)
            radius: Style.space(12)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(Color.accent, 0.13)

            Text {
              anchors.centerIn: parent
              text: Model.initials(root.activeName)
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(58)
          radius: Style.space(12)
          color: Util.alpha(Color.popups.text, 0.055)
          border.width: Math.max(1, Style.space(1))
          border.color: Util.alpha(Color.popups.text, 0.10)

          Column {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: root.barLabel
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              text: "Current input language"
              color: Util.alpha(Color.popups.text, 0.52)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            width: Style.space(8)
            height: width
            radius: width / 2
            color: Color.accent
            anchors.right: parent.right
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          Text {
            text: "LANGUAGES"
            color: Util.alpha(Color.popups.text, 0.48)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(5)

          Repeater {
            model: root.enabledLayouts

            Rectangle {
              required property var modelData
              required property int index
              width: contentColumn.width
              height: Style.space(44)
              radius: Style.space(10)
              color: langHover.hovered ? Util.alpha(Color.popups.text, 0.07) : "transparent"

              readonly property bool current: index === root.activeIndex

              Rectangle {
                width: Style.space(28)
                height: width
                radius: Style.space(8)
                anchors.left: parent.left
                anchors.leftMargin: Style.space(7)
                anchors.verticalCenter: parent.verticalCenter
                color: parent.current ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.popups.text, 0.055)
                Text {
                  anchors.centerIn: parent
                  text: String(parent.parent.modelData.code || "").substring(0, 2).toUpperCase()
                  color: parent.parent.current ? Color.accent : Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(44)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                  text: root.languageNameForCode(modelData.code)
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: current
                }
                Text {
                  text: String(modelData.code || "") + (modelData.variant ? " · " + modelData.variant : "")
                  color: Util.alpha(Color.popups.text, 0.42)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                visible: current
                text: "✓"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                anchors.right: removeButton.visible ? removeButton.left : parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
              }

              Rectangle {
                id: removeButton
                visible: root.enabledLayouts.length > 1 && !current
                width: Style.space(26)
                height: width
                radius: Style.space(8)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                color: removeHover.hovered ? Util.alpha(Color.urgent, 0.16) : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: "×"
                  color: removeHover.hovered ? Color.urgent : Util.alpha(Color.popups.text, 0.48)
                  font.pixelSize: Style.font.title
                }
                HoverHandler { id: removeHover }
                TapHandler { onTapped: root.removeLayout(modelData.code) }
              }

              HoverHandler { id: langHover }
              TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.switchTo(index)
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: root.addingLanguage ? Style.space(38) : Style.space(38)
          radius: Style.space(10)
          color: addHover.hovered ? Util.alpha(Color.accent, 0.10) : Util.alpha(Color.popups.text, 0.035)
          border.width: Math.max(1, Style.space(1))
          border.color: Util.alpha(Color.popups.text, 0.09)

          Text {
            anchors.centerIn: parent
            text: root.addingLanguage ? "Close language picker" : "+  Add language"
            color: root.addingLanguage ? Color.accent : Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
          HoverHandler { id: addHover }
          TapHandler {
            onTapped: {
              root.addingLanguage = !root.addingLanguage
              if (!root.addingLanguage) root.searchText = ""
            }
          }
        }

        Column {
          visible: root.addingLanguage
          width: parent.width
          spacing: Style.space(6)

          TextField {
            id: searchField
            width: parent.width
            height: Style.space(38)
            placeholderText: "Search language or layout code…"
            text: root.searchText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            selectByMouse: true
            onTextChanged: root.searchText = text
            background: Rectangle {
              radius: Style.space(10)
              color: Util.alpha(Color.popups.text, 0.05)
              border.width: 1
              border.color: searchField.activeFocus ? Color.accent : Util.alpha(Color.popups.text, 0.12)
            }
          }

          Repeater {
            model: root.addCandidates
            Rectangle {
              required property var modelData
              width: contentColumn.width
              height: Style.space(38)
              radius: Style.space(9)
              color: candidateHover.hovered ? Util.alpha(Color.popups.text, 0.07) : "transparent"

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                text: String(modelData.name || modelData.code)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                width: parent.width - Style.space(72)
              }
              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                text: String(modelData.code || "").toUpperCase()
                color: Util.alpha(Color.popups.text, 0.42)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              HoverHandler { id: candidateHover }
              TapHandler { onTapped: root.addLayout(modelData.code) }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.text, 0.10)
        }

        Column {
          width: parent.width
          spacing: Style.space(5)

          Text {
            text: "SWITCHING"
            color: Util.alpha(Color.popups.text, 0.48)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          Rectangle {
            width: parent.width
            height: Style.space(46)
            radius: Style.space(10)
            color: shortcutHover.hovered ? Util.alpha(Color.popups.text, 0.055) : "transparent"

            Column {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(7)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              Text {
                text: "Alt + Shift"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              Text {
                text: root.enabledLayouts.length <= 1
                  ? "Add another language first"
                  : (root.shortcut === "alt-shift" && !root.shortcutRuntimeActive
                      ? "Repairing shortcut…"
                      : "Either order · Alt→Shift or Shift→Alt")
                color: Util.alpha(Color.popups.text, 0.46)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              width: Style.space(36)
              height: Style.space(20)
              radius: height / 2
              anchors.right: parent.right
              anchors.rightMargin: Style.space(7)
              anchors.verticalCenter: parent.verticalCenter
              color: root.shortcut === "alt-shift" ? Color.accent : Util.alpha(Color.popups.text, 0.16)
              opacity: root.enabledLayouts.length > 1 ? 1 : 0.45
              Rectangle {
                width: Style.space(16)
                height: width
                radius: width / 2
                y: Style.space(2)
                x: root.shortcut === "alt-shift" ? parent.width - width - Style.space(2) : Style.space(2)
                color: root.shortcut === "alt-shift" ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
              }
            }
            HoverHandler { id: shortcutHover }
            TapHandler {
              enabled: root.enabledLayouts.length > 1
              onTapped: root.toggleAltShift()
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(46)
            radius: Style.space(10)
            color: osdHover.hovered ? Util.alpha(Color.popups.text, 0.055) : "transparent"

            Column {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(7)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              Text {
                text: "Language switch OSD"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              Text {
                text: "Show the new language in the center of the screen"
                color: Util.alpha(Color.popups.text, 0.46)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              width: Style.space(36)
              height: Style.space(20)
              radius: height / 2
              anchors.right: parent.right
              anchors.rightMargin: Style.space(7)
              anchors.verticalCenter: parent.verticalCenter
              color: root.osdEnabled ? Color.accent : Util.alpha(Color.popups.text, 0.16)
              Rectangle {
                width: Style.space(16)
                height: width
                radius: width / 2
                y: Style.space(2)
                x: root.osdEnabled ? parent.width - width - Style.space(2) : Style.space(2)
                color: root.osdEnabled ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
              }
            }
            HoverHandler { id: osdHover }
            TapHandler { onTapped: root.toggleOsd() }
          }
        }
      }
    }

      Column {
        id: footerBlock
        width: parent.width
        anchors.bottom: parent.bottom
        spacing: Style.space(8)

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(Color.popups.text, 0.10)
        }

        Text {
          width: parent.width
          text: "Saved automatically · right-click the bar label to switch quickly"
          color: Util.alpha(Color.popups.text, 0.38)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        Text {
          id: websiteLink
          width: parent.width
          text: "imagineit.online"
          color: websiteHover.hovered ? Color.accent : Util.alpha(Color.popups.text, 0.62)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.underline: websiteHover.hovered
          horizontalAlignment: Text.AlignHCenter

          Behavior on color { ColorAnimation { duration: 120 } }
          HoverHandler {
            id: websiteHover
            cursorShape: Qt.PointingHandCursor
          }
          TapHandler { onTapped: root.openWebsite() }
        }
      }
    }
  }

  PanelWindow {
    id: osdWindow
    screen: button.QsWindow.window ? button.QsWindow.window.screen : null
    visible: root.osdVisible && root.shouldShowOsdHere()
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "imagineit-klm-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    BorderSurface {
      id: osdCard
      readonly property int pad: Style.space(22)
      readonly property int cardRadius: Style.cornerRadius > 0 ? Style.space(20) : 0
      width: Math.max(Style.space(188), osdNameMetrics.advanceWidth + pad * 2 + borderLeft + borderRight)
      height: borderTop + pad + osdBody.implicitHeight + pad + borderBottom
      anchors.centerIn: parent
      color: Util.alpha(Color.background, 0.97)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: cardRadius
      opacity: root.osdVisible ? 1 : 0
      scale: root.osdVisible ? 1 : 0.92

      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
      Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      TextMetrics {
        id: osdNameMetrics
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
        text: root.osdLanguage
      }

      Column {
        id: osdBody
        width: Math.max(1, osdCard.width - osdCard.borderLeft - osdCard.borderRight - osdCard.pad * 2)
        x: osdCard.borderLeft + osdCard.pad
        y: osdCard.borderTop + osdCard.pad
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Style.space(72)

          Rectangle {
            width: Style.space(72)
            height: width
            radius: Style.cornerRadius > 0 ? Style.space(20) : 0
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(Color.accent, 0.16)
            border.width: Math.max(1, Style.space(1))
            border.color: Util.alpha(Color.accent, 0.38)

            Rectangle {
              anchors.fill: parent
              anchors.margins: Style.space(5)
              radius: Math.max(0, parent.radius - Style.space(5))
              color: "transparent"
              border.width: 1
              border.color: Util.alpha(Color.popups.text, 0.07)
            }

            Text {
              anchors.centerIn: parent
              text: root.osdCode
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.display
              font.bold: true
              font.letterSpacing: 1
            }
          }
        }

        Text {
          width: parent.width
          text: root.osdLanguage
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: "Input language"
          color: Util.alpha(Color.popups.text, 0.48)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }

        Item {
          visible: root.enabledLayouts.length > 1
          width: parent.width
          height: visible ? Style.space(8) : 0

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Repeater {
              model: root.enabledLayouts
              Rectangle {
                required property int index
                width: index === root.activeIndex ? Style.space(16) : Style.space(6)
                height: Style.space(6)
                radius: height / 2
                color: index === root.activeIndex ? Color.accent : Util.alpha(Color.popups.text, 0.22)
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }
              }
            }
          }
        }
      }
    }
  }
}
