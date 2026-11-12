import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick
import qs.Commons as Commons
import "dotmatrix" as DotMatrix

// Виджеты рабочего стола: часы, now playing, визуализатор cava, кольца системы,
// и дашборд, выезжающий из-под бара / рамки (Dashboard.qml, IPC widgets toggleDashboard).
// Окна на слое Bottom — над обоями и под окнами, клики проходят насквозь (кроме
// кнопок плеера). Настройки — ~/.config/omarchy/widgets.json (Customizer → Widgets),
// применяются на лету. Данные (cava, /proc, MPRIS) собираются здесь один раз на все мониторы.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/omarchy/widgets.json"

  readonly property var defaults: ({
    clock: true,
    clockStyle: "big",          // big stacked terminal minimal
    clockAnchor: "top-left",
    clock24: true,
    clockSeconds: false,
    media: true,
    mediaAnchor: "bottom-left",
    visualizer: true,
    visualizerStyle: "bars",    // bars mirror wave
    visualizerBars: 48,
    visualizerHeight: 140,
    visualizerAlpha: 0.45,
    visualizerIdle: false,      // показывать и без музыки (cava тогда работает всегда)
    sysinfo: true,
    sysinfoAnchor: "top-right",
    network: false,             // сеть: интерфейс, ↓/↑ и точечный осциллограф (NetWidget, как в NIHIL)
    networkAnchor: "top-left",
    todo: false,                // Todo / заметки (TodoWidget, ~/.config/omarchy/widgets-todo.json)
    todoAnchor: "right",
    todoMax: 8,
    quote: false,               // цитата дня (QuoteWidget, свои — ~/.config/omarchy/widgets-quotes.txt)
    quoteAnchor: "bottom-right",
    photo: false,               // фото-рамка (PhotoWidget): папка photoDir или текущие обои
    photoAnchor: "left",
    photoDir: "",
    photoInterval: 10,
    edgeMargin: 24,             // от внутреннего края бара / рамки до карточки
    tint: "accent",             // роль (accent foreground muted) или ключ colors.toml / #hex
    locale: "",                 // язык даты: "" — как в Customizer (customizer.json), иначе системный
    screens: "all",             // all primary
    weatherCity: "",            // город для погоды (open-meteo); пусто — блок погоды с подсказкой
    weatherUnits: "celsius",    // celsius fahrenheit
    desktopWidgets: true,       // false — слой виджетов рабочего стола не создаётся вовсе
    widgetStyle: "style",       // style (по стилю Customizer) · default · dotmatrix
    edgeHover: false,           // открытие дашборда / настроек / лаунчера по наведению на края экрана
    // Дашборд (Dashboard.qml / DotMatrixDashboard.qml) и меню выключения: стиль — BarStyle.qml.
    dashStyle: "default",       // default dotmatrix
    dashFollowBar: true,
    dashAttach: "auto",         // auto attached floating
    dashBackground: "background",
    dashAlpha: 0.94,
    dashRadius: 22,
    dashBorder: false,
    dashMedia: true,
    dashCalendar: true,
    dashWeather: true,
    dashStats: true,
    dashAnimation: "grow",      // grow slide fade liquid
    dashDuration: 340,
    // Домашний экран (HomeScreen.qml): часы, приветствие и плитки на пустом рабочем столе.
    home: false,
    homeName: "",               // имя в приветствии; пусто — $USER
    homeDots: true,             // точечная сетка на фоне
    homeHideWidgets: true,      // прятать виджеты на якорях, пока виден домашний экран
    homeLayout: "glyph",        // classic glyph minimal
    homeScale: 1,               // множитель размера раскладки
    homeGreeting: true,
    homeDate: true,
    homeMeta: true,             // glyph: строка погоды, батареи и сети под приветствием
    homeBlink: false,           // мигающее двоеточие часов (glyph)
    homeCards: "glyph",         // glyph: glyph — плоские карточки как в glyph-rice · style — материал стиля
    homeWidgets: "weather,calendar,temp,player,system",  // glyph: плитки бенто по порядку
    // Deck (Deck.qml): дашборд из-под нижнего края по наведению.
    deck: false,
    deckSections: "clock,weather,perf,net,media",
    deckScale: 1,
    deckCards: "glyph",         // glyph — плоская карточка · style — материал стиля
    deckDelay: 150              // мс курсора на полосе у края до открытия
  })

  property var raw: ({})
  property var palette: ({})

  function value(key) {
    var v = raw[key]
    return v === undefined || v === null ? defaults[key] : v
  }
  function num(key) {
    var n = Number(value(key))
    return isFinite(n) ? n : Number(defaults[key])
  }
  function flag(key) { return value(key) === true }

  // ── Открепляемые виджеты ───────────────────────────────────────────────
  // <name>Anchor = "free" + <name>Pos { cx, cy, screen } — свободное место (центр в долях экрана);
  // <name>Float = true — на слое поверх окон (DesktopLayer floating). Режим правки — IPC widgets
  // toggleEdit (Super+Ctrl+W): виджеты тащатся мышью, ПКМ — меню. Прежний якорь хранится в
  // <name>AnchorDocked, «Вернуть на место» возвращает его.
  property bool editMode: false

  // Deck: имя экрана, где он открыт ("" — закрыт). Открыт — опрос системы, сети и погоды.
  property string deckOn: ""
  onDeckOnChanged: if (deckOn !== "") weatherFetcher.refreshIfStale()

  // Где сейчас виден домашний экран: { "<экран>": true }. Пока виден — виджеты на якорях этого
  // экрана прячутся (homeHideWidgets), опрос системы и погоды работает.
  property var homeShown: ({})
  readonly property bool homeAny: Object.keys(homeShown).some(function(k) { return homeShown[k] })
  function setHomeShown(screen, on) {
    var o = Object.assign({}, homeShown)
    o[screen] = on
    homeShown = o
    if (on) weatherFetcher.refreshIfStale()
  }
  function homeHides(screen) { return flag("home") && homeShown[screen] === true && value("homeHideWidgets") !== false }
  Timer { interval: 10 * 60 * 1000; repeat: true; running: root.homeAny; onTriggered: weatherFetcher.refreshIfStale() }
  onEditModeChanged: if (editMode) { dashboardOpen = false; settingsOpen = false; powerOpen = false; overviewOpen = false }
  readonly property var widgetNames: ["clock", "media", "sysinfo", "network", "todo", "quote", "photo"]
  readonly property bool anyFloat: widgetNames.some(function(n) {
    return flag(n) && String(value(n + "Anchor")) === "free" && flag(n + "Float")
  })
  readonly property bool anyFree: widgetNames.some(function(n) { return flag(n) && String(value(n + "Anchor")) === "free" })
  // desktopWidgets = false — обычные (на якорях) виджеты не показываются; свободные, которые
  // расставили руками, остаются.
  readonly property bool deskOff: value("desktopWidgets") === false

  // Слить ключи в widgets.json (тот же файл правит Customizer — пишем всё содержимое разом).
  function saveKeys(obj) {
    var next = Object.assign({}, raw)
    for (var k in obj) {
      if (obj[k] === undefined) delete next[k]
      else next[k] = obj[k]
    }
    raw = next
    configFile.setText(JSON.stringify(next, null, 2) + "\n")
  }
  function freeKeys(name, screen, cx, cy) {
    var o = {}
    var a = String(value(name + "Anchor"))
    if (a !== "free") o[name + "AnchorDocked"] = a
    o[name + "Anchor"] = "free"
    o[name + "Pos"] = { cx: Math.round(cx * 10000) / 10000, cy: Math.round(cy * 10000) / 10000, screen: screen }
    return o
  }
  function placeFree(name, screen, cx, cy) { saveKeys(freeKeys(name, screen, cx, cy)) }
  function setFloat(name, on, screen) {
    var o = String(value(name + "Anchor")) === "free" ? {}
      : freeKeys(name, screen, 0.5, 0.5)
    o[name + "Float"] = on
    saveKeys(o)
  }
  function dock(name) {
    var o = {}
    o[name + "Anchor"] = String(value(name + "AnchorDocked") || defaults[name + "Anchor"] || "top-left")
    o[name + "AnchorDocked"] = undefined
    o[name + "Float"] = undefined
    o[name + "Pos"] = undefined
    saveKeys(o)
  }
  // Карточку из дашборда — на стол поверх окон, под дашбордом (как плеер Vitreus).
  function detach(name) {
    var o = freeKeys(name, focusedScreen ? String(focusedScreen.name) : "", 0.5, 0.22)
    o[name] = true
    o[name + "Float"] = true
    saveKeys(o)
    dashboardOpen = false
  }

  function resolve(spec, fallback) {
    var s = String(spec || "").trim()
    if (s === "") return fallback
    if (s.charAt(0) === "#") return Qt.color(s)
    if (s === "accent") return Commons.Color.accent
    if (s === "foreground") return Commons.Color.foreground
    if (s === "background") return Commons.Color.background
    if (s === "muted") return Commons.Color.muted
    if (s === "urgent") return Commons.Color.urgent
    if (palette[s]) return Qt.color(palette[s])
    return fallback
  }
  readonly property color accent: resolve(value("tint"), Commons.Color.accent)
  readonly property color foreground: Commons.Color.foreground
  readonly property color muted: Commons.Color.muted
  readonly property color background: Commons.Color.background
  // Шрифт обычных (не DOT-MATRIX) карточек: Omarchy или sans профиля шрифтов — токен typeface стиля.
  readonly property string fontFamily: dashStyle.fontFamily
  readonly property string iconFamily: Commons.Style.font.family   // Nerd-иконки — всегда шрифт Omarchy
  // style — по стилю Customizer (~/.config/omarchy/style.json): у DOT-MATRIX — dotmatrix-виджеты, у остальных —
  // обычные виджеты на подложке в материале стиля (WidgetCard). default — прежний вид без подложек.
  readonly property string widgetMode: String(value("widgetStyle"))
  readonly property bool dotmatrixWidgets: widgetMode === "dotmatrix" || (widgetMode === "style" && DotMatrix.Finish.dotmatrix)
  readonly property bool styledWidgets: widgetMode === "style" && !DotMatrix.Finish.dotmatrix
  readonly property bool dotmatrixDash: String(value("dashStyle")) === "dotmatrix"

  property string uiLang: ""
  readonly property bool ru: String(locale.name).indexOf("ru") === 0
  function tr(en, ruText) { return ru ? ruText : en }
  readonly property var locale: {
    var l = String(value("locale") || uiLang || "")
    return l !== "" ? Qt.locale(l) : Qt.locale()
  }
  FileView {
    path: root.home + "/.config/omarchy/customizer.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.uiLang = String(JSON.parse(text() || "{}").lang || "") } catch (e) { root.uiLang = "" }
    }
    onFileChanged: reload()
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || "{}"))
        root.raw = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {}
      } catch (e) {
        console.warn("widgets.json: " + e)
      }
    }
    onLoadFailed: root.raw = {}
    onFileChanged: reload()
  }

  FileView {
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var out = {}
      var lines = String(text() || "").split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["'](#[0-9A-Fa-f]{6})["']/)
        if (m) out[m[1]] = m[2]
      }
      root.palette = out
    }
    onFileChanged: reload()
  }

  // ── Плеер: играющий, иначе первый ─────────────────────────────────────
  readonly property var player: {
    var list = Mpris.players.values
    for (var i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i]
    return list.length > 0 ? list[0] : null
  }
  readonly property bool playing: player !== null && player.isPlaying
  // position у MPRIS не обновляется сам — дёргаем раз в секунду, пока играет.
  Timer {
    interval: 1000
    repeat: true
    running: root.playing && (root.flag("media") || root.dashboardOpen)
    onTriggered: if (root.player) root.player.positionChanged()
  }

  // ── cava ───────────────────────────────────────────────────────────────
  readonly property int bars: Math.max(8, Math.min(128, Math.round(num("visualizerBars"))))
  property var levels: []
  // cava нужна визуализатору, дашборду и плитке cava домашнего экрана (пока он виден).
  readonly property bool homeCava: homeAny && String(value("homeLayout")) === "glyph" && /(^|[\s,])cava([\s,]|$)/.test(String(value("homeWidgets")))
  readonly property bool cavaWanted: (flag("visualizer") || dashboardOpen || homeCava) && (playing || flag("visualizerIdle"))
  readonly property string cavaConfig: [
    "[general]", "bars = " + bars, "framerate = 30", "sleep_timer = 2",
    "[input]", "method = pipewire", "source = auto",
    "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii",
    "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10",
    "[smoothing]", "noise_reduction = 77", ""
  ].join("\n")

  Process {
    id: cava
    running: root.cavaWanted
    command: ["bash", "-c", "exec cava -p <(printf '%s' \"$1\")", "omarchy-widgets-cava", root.cavaConfig]
    onRunningChanged: if (!running) root.levels = []
    stdout: SplitParser {
      onRead: data => {
        var parts = data.split(";")
        var out = []
        for (var i = 0; i < parts.length; i++) if (parts[i] !== "") out.push(Number(parts[i]) / 100)
        root.levels = out
      }
    }
  }
  // Смена числа полос — перезапуск с новым конфигом.
  onCavaConfigChanged: if (cava.running) { cava.running = false; Qt.callLater(() => cava.running = root.cavaWanted) }

  // ── Система: CPU, RAM, температура, батарея ───────────────────────────
  property real cpu: 0
  property real mem: 0
  property real temp: 0
  property real memUsedGb: 0          // занято памяти, ГБ (домашний экран glyph)
  property real disk: 0               // занято на /, доля
  property int battery: -1
  property string batteryStatus: ""
  property var cpuPrev: null
  // История для графиков дашборда (по точке раз в 2 с).
  readonly property int historyLength: 60
  property var cpuHistory: []
  property var memHistory: []
  property string netIface: ""
  property real rxRate: 0
  property real txRate: 0
  property var netPrev: null
  property var rxHistory: []
  property var txHistory: []

  // ── Дашборд и панель настроек ──────────────────────────────────────────
  property bool dashboardOpen: false
  property bool settingsOpen: false
  property string settingsSection: ""   // раздел, который SettingsPanel раскроет при открытии
  // Меню выключения (PowerMenu.qml). Открытие одного закрывает другое.
  property bool powerOpen: false
  onPowerOpenChanged: if (powerOpen) { dashboardOpen = false; settingsOpen = false; overviewOpen = false; dashStyle.refresh() }
  // Обзор рабочих столов (Overview.qml).
  property bool overviewOpen: false
  onOverviewOpenChanged: if (overviewOpen) { dashboardOpen = false; settingsOpen = false; powerOpen = false }
  onSettingsOpenChanged: {
    if (settingsOpen) { dashboardOpen = false; powerOpen = false; overviewOpen = false }
    settingsFlag.setText(settingsOpen ? "1\n" : "0\n")
  }
  // Флаг для kamradsmeshnyavy.notifications: пока открыто меню Super+M (там же история), тосты не показываются.
  FileView {
    id: settingsFlag
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-settings-open"
    printErrors: false
    Component.onCompleted: setText("0\n")
  }
  IpcHandler {
    target: "widgets"
    function toggleDashboard(): void { root.dashboardOpen = !root.dashboardOpen }
    function openDashboard(): void { root.dashboardOpen = true }
    function closeDashboard(): void { root.dashboardOpen = false }
    function toggleSettings(): void { root.settingsOpen = !root.settingsOpen }
    function openSettings(): void { root.settingsOpen = true }
    function closeSettings(): void { root.settingsOpen = false }
    // Панель настроек сразу с раскрытым разделом: wifi | bt | audio.
    function openSettingsSection(name: string): void { root.settingsSection = name; root.settingsOpen = true }
    function togglePower(): void { root.powerOpen = !root.powerOpen }
    function openPower(): void { root.powerOpen = true }
    function closePower(): void { root.powerOpen = false }
    function toggleOverview(): void { root.overviewOpen = !root.overviewOpen }
    function openOverview(): void { root.overviewOpen = true }
    function closeOverview(): void { root.overviewOpen = false }
    function toggleEdit(): void { root.editMode = !root.editMode }
    function toggleDeck(): void { root.deckOn = root.deckOn !== "" ? "" : (root.focusedScreen ? String(root.focusedScreen.name) : "") }
    function openEdit(): void { root.editMode = true }
    function closeEdit(): void { root.editMode = false }
    // Открепить / вернуть виджет: clock media sysinfo network todo quote photo.
    function detach(name: string): void { root.detach(name) }
    function dock(name: string): void { root.dock(name) }
  }
  onDashboardOpenChanged: if (dashboardOpen) { settingsOpen = false; powerOpen = false; overviewOpen = false; dashStyle.refresh(); weatherFetcher.refreshIfStale() }

  // Экран под курсором / с фокусом — дашборд открывается там.
  readonly property var focusedScreen: {
    var m = Hyprland.focusedMonitor
    var list = Quickshell.screens
    for (var i = 0; m && i < list.length; i++) if (list[i].name === m.name) return list[i]
    return list.length > 0 ? list[0] : null
  }

  // Стиль дашборда и меню выключения: как у бара или свой (BarStyle.qml, ключи dash* в widgets.json).
  BarStyle {
    id: dashStyle
    follow: root.value("dashFollowBar") !== false
    attach: String(root.value("dashAttach"))
    background: String(root.value("dashBackground"))
    alpha: root.num("dashAlpha")
    radius: root.num("dashRadius")
    border: root.flag("dashBorder")
  }
  readonly property var panelStyle: dashStyle

  // Подложки виджетов рабочего стола (WidgetCard): материал и токены стиля, фон — цвет фона темы.
  BarStyle {
    id: deskStyle
    follow: false
    attach: "floating"
    background: "background"
    alpha: 0.9
    radius: 18
    border: true
  }
  readonly property var deskStyle: deskStyle

  // Погода: open-meteo (без ключа), раз в 20 минут, только пока открыт дашборд.
  QtObject {
    id: weatherFetcher
    property double fetchedAt: 0
    property string fetchedFor: ""
    function refreshIfStale() {
      var city = String(root.value("weatherCity") || "").trim()
      if (city === "") { root.weather = null; return }
      var key = city + "|" + root.value("weatherUnits")
      if (key === fetchedFor && Date.now() - fetchedAt < 20 * 60 * 1000) return
      fetchedFor = key
      fetchedAt = Date.now()
      get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=" + (root.ru ? "ru" : "en") +
          "&name=" + encodeURIComponent(city), function(geo) {
        var place = geo && geo.results && geo.results[0]
        if (!place) { root.weather = { error: root.tr("City not found: ", "Город не найден: ") + city }; return }
        get("https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude +
            "&current=temperature_2m,weather_code,wind_speed_10m,apparent_temperature" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset&forecast_days=4&timezone=auto" +
            "&temperature_unit=" + root.value("weatherUnits"), function(f) {
          if (!f || !f.current) { root.weather = { error: root.tr("No weather data", "Нет данных о погоде") }; return }
          root.weather = {
            city: place.name, temp: f.current.temperature_2m, feels: f.current.apparent_temperature,
            code: f.current.weather_code, wind: f.current.wind_speed_10m,
            max: f.daily.temperature_2m_max[0], min: f.daily.temperature_2m_min[0],
            // Deck: восход / закат сегодня и прогноз на 4 дня
            sunrise: f.daily.sunrise ? f.daily.sunrise[0] : "", sunset: f.daily.sunset ? f.daily.sunset[0] : "",
            days: (f.daily.time || []).map(function(t, i) {
              return { date: t, code: f.daily.weather_code ? f.daily.weather_code[i] : 3,
                       max: f.daily.temperature_2m_max[i], min: f.daily.temperature_2m_min[i] }
            })
          }
        })
      })
    }
    function get(url, done) {
      var xhr = new XMLHttpRequest()
      xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        var data = null
        try { data = JSON.parse(xhr.responseText) } catch (e) {}
        if (xhr.status !== 200) { weatherFetcher.fetchedAt = 0; root.weather = { error: root.tr("Weather unavailable", "Погода недоступна") }; return }
        done(data)
      }
      xhr.open("GET", url)
      xhr.send()
    }
  }
  property var weather: null

  Dashboard {
    host: root
  }

  DotMatrixDashboard {
    host: root
  }

  SettingsPanel {
    host: root
  }

  EdgeHotzones {
    host: root
  }

  PowerMenu {
    host: root
  }

  Overview {
    host: root
  }

  Process {
    id: sysProbe
    command: ["bash", "-c",
      "read -r _ u n s i w q sq st _ < /proc/stat; echo \"cpu $((u+n+s+i+w+q+sq+st)) $((i+w))\";" +
      "awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2} END{print \"\"}' /proc/meminfo | sed 's/^/mem /';" +
      (root.homeAny || root.deckOn !== "" ? "df -P / 2>/dev/null | awk 'NR==2{sub(\"%\",\"\",$5); print \"disk\", $5}';" : "") +
      "t=; for z in /sys/class/thermal/thermal_zone*; do case $(<$z/type) in x86_pkg_temp|TCPU|cpu*|k10temp) t=$(<$z/temp); break;; esac; done;" +
      "echo \"temp ${t:-$(</sys/class/thermal/thermal_zone0/temp)}\";" +
      "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { echo \"bat $(<$b/capacity) $(<$b/status)\"; break; }; done;" +
      // Скорость сети нужна дашборду DOT-MATRIX и виджету «Сеть».
      (!root.dotmatrixDash && !root.flag("network") && !root.homeAny && root.deckOn === "" ? "" :
      "dev=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}');" +
      "[ -n \"$dev\" ] && [ -r \"/sys/class/net/$dev/statistics/rx_bytes\" ] && echo \"net $dev $(</sys/class/net/$dev/statistics/rx_bytes) $(</sys/class/net/$dev/statistics/tx_bytes)\""
      )]
    stdout: StdioCollector {
      onStreamFinished: {
        var nowMs = Date.now()
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].trim().split(/\s+/)
          if (f[0] === "cpu" && f.length >= 3) {
            var total = Number(f[1]), idle = Number(f[2])
            if (root.cpuPrev) {
              var dt = total - root.cpuPrev.total
              root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - root.cpuPrev.idle) / dt)) : root.cpu
            }
            root.cpuPrev = { total: total, idle: idle }
            root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-root.historyLength)
          } else if (f[0] === "mem" && f.length >= 3) {
            root.mem = Number(f[1]) > 0 ? 1 - Number(f[2]) / Number(f[1]) : 0
            root.memUsedGb = Math.max(0, Number(f[1]) - Number(f[2])) / 1048576
          } else if (f[0] === "disk" && f.length >= 2) {
            root.disk = Number(f[1]) / 100
            root.memHistory = root.memHistory.concat([root.mem]).slice(-root.historyLength)
          } else if (f[0] === "temp" && f.length >= 2) {
            root.temp = Number(f[1]) / 1000
          } else if (f[0] === "bat" && f.length >= 2) {
            root.battery = Number(f[1])
            root.batteryStatus = f[2] || ""
          } else if (f[0] === "net" && f.length >= 4) {
            var iface = f[1], rx = Number(f[2]), tx = Number(f[3])
            root.netIface = iface
            if (root.netPrev && root.netPrev.iface === iface && nowMs > root.netPrev.ts) {
              var elapsed = (nowMs - root.netPrev.ts) / 1000
              root.rxRate = Math.max(0, (rx - root.netPrev.rx) / elapsed)
              root.txRate = Math.max(0, (tx - root.netPrev.tx) / elapsed)
            } else {
              root.rxRate = 0
              root.txRate = 0
            }
            root.netPrev = { iface: iface, rx: rx, tx: tx, ts: nowMs }
            root.rxHistory = root.rxHistory.concat([root.rxRate]).slice(-44)
            root.txHistory = root.txHistory.concat([root.txRate]).slice(-44)
          }
        }
      }
    }
  }
  Timer {
    interval: 2000
    repeat: true
    triggeredOnStart: true
    running: root.flag("sysinfo") || root.flag("network") || root.dashboardOpen || root.homeAny || root.deckOn !== ""
    onTriggered: if (!sysProbe.running) sysProbe.running = true
  }

  // ── Окна ───────────────────────────────────────────────────────────────
  // Обычный слой виджетов (Bottom) на каждом экране и слой «поверх окон» — только пока есть
  // открепленные виджеты с <name>Float (лишних поверхностей и копий виджетов не держим).
  // desktopWidgets = false прячет виджеты на якорях, но не расставленные руками и не открепленные
  // поверх окон; режим правки показывает всё — иначе нечего расставлять.
  readonly property var layerScreens: root.value("screens") === "primary" ? Quickshell.screens.slice(0, 1) : Quickshell.screens

  Variants {
    model: !root.deskOff || root.editMode || root.anyFree ? root.layerScreens : []
    delegate: Component {
      DesktopLayer { host: root }
    }
  }
  Variants {
    model: root.flag("deck") ? Quickshell.screens : []
    delegate: Component {
      Deck { host: root }
    }
  }
  Variants {
    model: root.flag("home") ? root.layerScreens : []
    delegate: Component {
      HomeScreen { host: root }
    }
  }
  Variants {
    model: root.anyFloat ? root.layerScreens : []
    delegate: Component {
      DesktopLayer { host: root; floating: true }
    }
  }
}
