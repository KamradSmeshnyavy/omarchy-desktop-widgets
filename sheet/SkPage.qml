import QtQuick
import "MotionShared.js" as Motion

// Страница панели настроек для обликов райсов (SheetRumda, SheetYami, …): CORE (райс / вариант / бар выпадающими
// списками), COLORS (темы райса и акцент — ряды «тема» и «обои»), FONTS, PROFILES и все страницы схемы (Schema.js).
// Вид ручек — из Sk.t; смена вкладки — анимацией облика Sk.t.swap: slide | fade | flip | type | drop.
// Высота ограничена maxHeight — дальше страница листается (KeyNav сам докручивает к выбранной строке).
Flickable {
  id: pg
  property string tab: "core"
  property bool oneColumn: false
  property real maxHeight: 520
  property int dir: 1
  readonly property real colW: Sk.n("colW", 320)
  readonly property real gap: Sk.n("gap", 26)
  implicitWidth: body.item ? body.item.width : colW
  implicitHeight: Math.min(maxHeight, contentHeight)
  width: implicitWidth
  height: implicitHeight
  contentWidth: width
  contentHeight: body.item ? body.item.height : 0
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  interactive: contentHeight > height

  property string was: tab
  onTabChanged: { swap.restart(); contentY = 0 }

  Item {
    id: holder
    width: pg.width
    height: pg.contentHeight
    transform: [Translate { id: shift }, Rotation { id: turn; origin.x: holder.width / 2; axis { x: 0; y: 1; z: 0 } }]
    Loader {
      id: body
      sourceComponent: ({ core: core, colors: colors, fonts: fonts, profiles: profiles })[pg.tab] ?? schemaPage
    }
    // «печать» строк (type): шторка сверху вниз
    Rectangle {
      id: curtain
      visible: Sk.s("swap", "slide") === "type" && height > 0
      anchors.bottom: parent.bottom
      width: parent.width
      height: 0
      color: Sk.c("bg")
    }
  }
  SequentialAnimation {
    id: swap
    ScriptAction { script: {
      const k = Sk.s("swap", "slide")
      shift.x = k === "slide" ? 28 * pg.dir : 0
      shift.y = k === "drop" ? -22 : 0
      turn.angle = k === "flip" ? 70 * pg.dir : 0
      holder.opacity = k === "type" ? 1 : 0
      curtain.height = k === "type" ? pg.contentHeight : 0
    } }
    ParallelAnimation {
      NumberAnimation { target: holder; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
      NumberAnimation { target: shift; property: "x"; to: 0; duration: 260; easing.type: Easing.OutCubic }
      NumberAnimation { target: shift; property: "y"; to: 0; duration: 320; easing.type: Easing.OutBack }
      NumberAnimation { target: turn; property: "angle"; to: 0; duration: 300; easing.type: Easing.OutCubic }
      NumberAnimation { target: curtain; property: "height"; to: 0; duration: Math.min(600, 40 + pg.contentHeight * 1.2); easing.type: Easing.Linear }
    }
  }

  // ── CORE ───────────────────────────────────────────────────────────
  Component {
    id: core
    Column {
      spacing: 4
      width: pg.colW + 20
      SkTitle { width: pg.colW; text: "Rice"; index: 0 }
      SkPick { width: pg.colW; label: "Rice"; dropdown: true; options: SheetCore.riceOptions; current: SheetCore.riceNow; onChose: v => SheetCore.chooseRice(v) }
      SkPick { width: pg.colW; label: "Variant"; dropdown: true; options: SheetCore.variantOptions; current: SheetCore.variantNow; onChose: v => StoreShared.act("rice", [v]) }
      SkPick { width: pg.colW; label: "Bar"; dropdown: true; options: SheetCore.barOptions; current: SheetCore.barNow; onChose: v => StoreShared.act("bar", [v]) }
      Item { width: 1; height: 6 }
      SkLabel { width: pg.colW; height: 18; text: "Theme  " + (SheetCore.theme || "—"); faint: true; font.pixelSize: Math.max(9, Sk.n("size", 12) - 2) }
    }
  }

  // ── COLORS: темы райса и акцент ────────────────────────────────────
  Component {
    id: colors
    Column {
      id: cc
      spacing: 8
      readonly property real w: pg.oneColumn ? pg.colW : Math.max(pg.colW, 7 * 64)
      width: w
      SkTitle { width: cc.w; text: "Theme"; index: 0 }
      Flow {
        width: cc.w
        spacing: 8
        Repeater {
          model: SheetCore.riceThemes
          Item {
            id: th
            required property var modelData
            required property int index
            readonly property bool used: SheetCore.themeUsed(modelData.id)
            width: 58; height: 74
            Rectangle {
              visible: Sk.n("shadow", 0) > 0
              x: Sk.n("shadow", 0); y: Sk.n("shadow", 0); width: parent.width; height: parent.height
              radius: Sk.n("radius", 4); color: Sk.c("shadowColor", "#000000")
            }
            Rectangle {
              anchors.fill: parent
              radius: Sk.n("radius", 4)
              clip: true
              color: th.modelData.c[0]
              border.width: th.used ? 2 : Math.max(1, Sk.n("border", 1))
              border.color: th.used ? Sk.c("accent") : Sk.alpha(Sk.c("ink"), 0.3)
              Column {
                x: 6; y: 6; spacing: 2
                Repeater { model: th.modelData.c.slice(1); Rectangle { required property string modelData; width: 46; height: 6; radius: Math.min(3, Sk.n("radius", 4)); color: modelData } }
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 3
              width: parent.width - 6; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
              text: String(th.modelData.id).replace(/^dynamic-.*/, "dynamic")
              color: Sk.ink(th.modelData.c[0])
              font.family: Sk.s("font", "monospace"); font.pixelSize: 8
            }
            SkHit {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              kbdRadius: Sk.n("radius", 4)
              readonly property string rowLabel: "Theme " + th.modelData.id
              onHit: StoreShared.act("theme", [th.modelData.id])
            }
          }
        }
      }
      Item { width: 1; height: 4 }
      SkTitle { width: cc.w; text: "Accent"; index: 1 }
      Repeater {
        model: [["theme", SheetCore.accentTheme], ["wallpaper", SheetCore.accentWall]]
        Row {
          id: srow
          required property var modelData
          visible: modelData[1].length > 0
          spacing: 8
          SkLabel { width: 84; height: 26; text: srow.modelData[0] }
          Flow {
            width: cc.w - 92
            spacing: 6
            Repeater {
              model: srow.modelData[1]
              Item {
                id: sw
                required property string modelData
                readonly property bool used: String(modelData).toLowerCase() === SheetCore.accentNow
                readonly property string shape: Sk.s("swatch", "round")
                width: 24; height: 24
                Rectangle {
                  anchors.centerIn: parent
                  width: sw.used ? 26 : 20; height: width
                  radius: sw.shape === "round" ? width / 2 : sw.shape === "square" ? 0 : Math.min(5, Sk.n("radius", 4))
                  color: sw.modelData
                  border.width: sw.used ? 2 : 1
                  border.color: sw.used ? Sk.c("ink") : Sk.alpha(Sk.c("ink"), 0.3)
                  Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                  Rectangle { visible: sw.used; anchors.centerIn: parent; width: 6; height: 6; radius: sw.shape === "round" ? 3 : 0; color: Sk.ink(sw.modelData) }
                }
                SkHit {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  kbdRadius: sw.shape === "round" ? 12 : 3
                  readonly property string rowLabel: "Accent " + sw.modelData
                  onHit: SheetCore.setAccent(sw.modelData)
                }
              }
            }
          }
        }
      }
      Row {
        spacing: 10
        SkLabel { width: 84; height: 26; text: "now" }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: Sk.s("swatch", "round") === "round" ? 7 : 2; color: SheetCore.accentNow || Sk.c("accent") }
        SkLabel { height: 26; text: SheetCore.accentNow || "—"; faint: false }
        Item {
          visible: SheetCore.accentCustom
          width: rs.implicitWidth + 18; height: 24
          Rectangle { anchors.fill: parent; radius: Sk.n("radius", 4); color: rm.containsMouse ? Sk.alpha(Sk.c("accent"), 0.18) : "transparent"; border.width: 1; border.color: Sk.alpha(Sk.c("ink"), 0.3) }
          SkLabel { id: rs; anchors.centerIn: parent; text: "reset"; faint: false }
          SkHit { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; kbdRadius: Sk.n("radius", 4); onHit: SheetCore.resetAccent() }
        }
      }
    }
  }

  // ── FONTS ─────────────────────────────────────────────────────────
  Component {
    id: fonts
    Column {
      id: fc
      spacing: 8
      readonly property real w: pg.oneColumn ? pg.colW : Math.max(pg.colW, 620)
      width: w
      Row {
        spacing: 12
        SkField { id: find; width: Math.min(260, fc.w - 120); placeholder: "search  ( / )"; onAccepted: if (Sk.keys) Sk.keys.forceActiveFocus() }
        SkLabel { height: 26; width: fc.w - find.width - 12; text: SheetCore.fontNow; lit: true }
      }
      Grid {
        columns: pg.oneColumn ? 1 : 3
        columnSpacing: 10
        rowSpacing: 2
        Repeater {
          model: SheetCore.fonts.filter(f => (f.label + " " + (f.note || "")).toLowerCase().includes(find.text.toLowerCase()))
          Item {
            id: fr
            required property var modelData
            width: pg.oneColumn ? fc.w : (fc.w - 20) / 3
            height: 24
            Rectangle { anchors.fill: parent; radius: Sk.n("radius", 4); color: fr.modelData.cur ? Sk.alpha(Sk.c("accent"), 0.16) : fm.containsMouse ? Sk.alpha(Sk.c("ink"), 0.07) : "transparent" }
            Text {
              x: 6; width: parent.width - 12; anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              text: fr.modelData.label
              color: fr.modelData.cur ? Sk.c("accent") : Sk.c("ink")
              font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12)
            }
            SkHit { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; kbdRadius: Sk.n("radius", 4); onHit: StoreShared.act("font", [fr.modelData.value]) }
          }
        }
      }
      // «/» в панели — сюда
      Connections { target: pg; function onSearch() { find.grab() } }
    }
  }
  signal search()

  // ── PROFILES ──────────────────────────────────────────────────────
  Component {
    id: profiles
    Column {
      id: pc
      spacing: 4
      readonly property real w: pg.colW
      width: w
      SkTitle { width: pc.w; text: "Profiles"; index: 2 }
      Repeater {
        model: SheetCore.profiles
        Item {
          id: pr
          required property var modelData
          property bool armed: false
          readonly property bool used: SheetCore.profileUsed(modelData)
          readonly property string rowLabel: SheetCore.profileName(modelData)
          readonly property string rowHint: "Enter — apply · right click twice — delete yours"
          width: pc.w; height: Math.max(24, Sk.n("rowH", 26))
          Rectangle { anchors.fill: parent; radius: Sk.n("radius", 4); color: pr.used ? Sk.alpha(Sk.c("accent"), 0.16) : pm.containsMouse ? Sk.alpha(Sk.c("ink"), 0.07) : "transparent" }
          SkLabel { x: 8; width: parent.width - 100; height: parent.height; text: (pr.used ? "● " : "○ ") + SheetCore.profileName(pr.modelData); lit: pr.used; faint: false }
          SkLabel {
            anchors.right: parent.right; anchors.rightMargin: 8; height: parent.height
            text: pr.armed ? "again — delete" : pr.modelData.mine ? "mine" : "profile"
            font.pixelSize: Math.max(9, Sk.n("size", 12) - 2)
          }
          MouseArea {
            id: pm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real kbdRadius: Sk.n("radius", 4)
            function kbdPress() { SheetCore.applyProfile(pr.modelData) }
            onClicked: m => {
              if (m.button === Qt.LeftButton) return SheetCore.applyProfile(pr.modelData)
              if (!pr.modelData.mine) return
              if (pr.armed) StoreShared.act("delete", [pr.modelData.id])
              pr.armed = !pr.armed
            }
          }
        }
      }
      Item { width: 1; height: 8 }
      SkLabel { width: pc.w; height: 20; text: "save as" }
      SkField {
        width: pc.w
        placeholder: "name"
        onAccepted: { if (text.trim()) StoreShared.act("save", [text.trim()]); text = ""; if (Sk.keys) Sk.keys.forceActiveFocus() }
      }
    }
  }

  // ── страницы схемы ────────────────────────────────────────────────
  Component {
    id: schemaPage
    Flow {
      id: sp
      readonly property var page: SheetCore.page(pg.tab)
      readonly property var cols: !page ? [] : pg.oneColumn ? [page.columns.reduce((a, c) => a.concat(c), [])] : page.columns
      spacing: pg.gap
      width: pg.oneColumn ? pg.colW : cols.length * (pg.colW + pg.gap)
      Repeater {
        model: sp.cols
        Column {
          id: col
          required property var modelData
          required property int index
          readonly property var all: modelData.reduce((a, s) => a.concat(s.controls), [])
          readonly property bool wide: all.some(c => c.type === "bezier")
          width: wide && !pg.oneColumn ? Math.max(pg.colW, 560) : pg.colW
          visible: all.some(c => SheetCore.shown(c))
          spacing: 8
          Repeater {
            model: col.modelData
            Column {
              id: sec
              required property var modelData
              required property int index
              visible: modelData.controls.some(c => SheetCore.shown(c))
              width: col.width
              spacing: 2
              SkTitle { width: sec.width; text: sec.modelData.label; index: col.index * 3 + sec.index }
              Repeater {
                model: sec.modelData.controls
                Loader {
                  id: ctl
                  required property var modelData
                  readonly property var def: modelData
                  width: sec.width
                  height: item?.implicitHeight ?? 0
                  visible: SheetCore.shown(def)
                  active: visible
                  sourceComponent: ({ slider: slider, toggle: flip, choice: choice, bezier: bezier, animpreset: preset })[def.type] ?? null
                  Component { id: slider; SkSlider { width: ctl.width; key: ctl.def.key; label: ctl.def.label; unit: ctl.def.unit; from: ctl.def.min; to: ctl.def.max; step: ctl.def.step; fallback: ctl.def.dflt ?? ctl.def.min } }
                  Component { id: flip; SkToggle { width: ctl.width; key: ctl.def.key; label: ctl.def.label; raises: ctl.def.raises; fallback: ctl.def.dflt ?? true } }
                  Component { id: choice; SkPick { width: ctl.width; label: ctl.def.label; options: ctl.def.options; current: SheetCore.current(ctl.def); onChose: v => StoreShared.set(ctl.def.key, v) } }
                  Component { id: bezier; SettingBezierShared {} }
                  Component {
                    id: preset
                    SkPick {
                      width: ctl.width
                      label: "Preset"
                      options: Motion.PRESET_OPTIONS
                      current: StoreShared.values["animation.preset"] || "theme"
                      onChose: v => Motion.pick(StoreShared, v, StoreShared.values["animation.curve"] || Motion.CURVE)
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: StoreShared.reset(ctl.def.key ?? "animation")
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
