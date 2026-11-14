# Omarchy Desktop Widgets

[🇬🇧 English](README.md)

Виджеты рабочего стола, дашборд, меню выключения и обзор рабочих столов для [Omarchy](https://omarchy.org)
в стиле твоего бара. Один плагин типа `service`: cava, MPRIS и опрос `/proc` работают один раз на все мониторы.

| Часть | Что делает | Открыть |
|---|---|---|
| Виджеты | часы (5 стилей: … `vitreus` — цифры-трубки из стекла, часы над минутами с чертой, `clockVitreusLayout` rule / pipe / digital; + `dotmatrix` Doto), карточка «сейчас играет» (с LED-обложкой `DotScreen` в стиле `dotmatrix`), визуализатор cava (bars/mirror/wave + точки `dotmatrix`), кольца или 28-LED шкалы CPU/RAM/температуры/батареи (`sysinfoStyle: "vitreus"` — карточка-монитор Vitreus: хост и аптайм, три кольца CPU / память / видеокарта или температура, зеркальный график сети из 120 столбиков), график вкладов GitHub (`"contrib": true` + `"githubUser"`; публичному github-contributions-api.jogruber.de уходит только это имя; клик — профиль) — на слое Bottom, под окнами | всегда |
| Дашборд | `default` (плеер, календарь, погода, графики CPU/RAM) или `dotmatrix` (часы Doto, LED-обложка MPRIS, 24×6 спектр, 28-LED циферблаты CPU/RAM/°C, LED-осциллограф сети rx/tx) | `omarchy-shell widgets toggleDashboard` |
| Панель настроек | правая чёрная аппаратная панель DOT-MATRIX: 3×2 круглых тумблера (Wi-Fi, Bluetooth, звук, микрофон, DND, ночной свет), 24-сегментные LED-слайдеры, списки Wi-Fi/BT/аудио, история уведомлений и действия сессии с подтверждением | `omarchy-shell widgets toggleSettings` |
| Quick | при `"settingsPanel": "quick"` та же клавиша открывает Quick из [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice): карточка справа внизу — часы, пилюли Wi-Fi / Bluetooth (правый клик — сети со строкой пароля / устройства для сопряжения), круглые плитки (не беспокоить, ночной свет, авиарежим, не засыпать, микрофон, запись экрана — правый клик: область / экран, звук системы / микрофона, камера — режим чтения, пипетка), слайдеры яркости и громкости из точек, профили питания (если есть power-profiles-daemon), мини-плеер и последние уведомления (replay; clear all — повторное нажатие за 3 с, история удаляется насовсем). Настройки записи — в `~/.config/omarchy/quick.json` | `omarchy-shell widgets toggleSettings` |
| Shot | скриншот из [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice): экран замирает и гаснет, белая рамка 1 px с точками по углам и размером цифрами Doto, лупа из точек с цветом пикселя; режимы область / окно (Space) / экран / запись (Tab), таймер 3 / 13 с (T). Снимок — в `$OMARCHY_SCREENSHOT_DIR` или `~/Pictures/Screenshots` и в буфер; в углу выезжает карточка — клик открывает правку: перо, стрелка, рамка, пикселизация, текст, 4 цвета, 3 толщины, Ctrl+Z, Enter сохраняет и копирует. Запись — стоковой `omarchy-capture-screenrecording` с выбранной областью (звук и камера — из Quick) | `omarchy-shell widgets shot` · Print |
| Панели из бара | у стиля `liquid` (пресеты Vitreus) дашборд (`"dashAnimation": "liquid"`), панель настроек и меню выключения растут из своей кнопки бара — часов, звука / сети, питания (бар пишет `$XDG_RUNTIME_DIR/omarchy-bar-geom.json`, его читает `BarGeom.qml`) — у любого края. К бару во всю длину края (full, frame) панель прилипает вплотную, одним куском: у стекла — перешеек вдоль всей стороны с вогнутыми изгибами (`DrawerGeom.qml`), панель у кромки рамки прилипает и к ней («крылья»); у пластиковых основ (Retro, Doodle, …) на слитых сторонах нет контура, углы — вогнутые с контуром (`MergeFillet.qml`). У плавающей пилюли — зазор и узкий перешеек-капля . **Перенос панелей.** Дашборд, панель настроек и меню выключения отрывают от бара за верхнюю полосу или красный язычок основы Retro и носят по столу (`DrawerPull.qml`, `PullGrip.qml`): перешеек тянется и рвётся, отпущенная у своего места панель прилипает обратно, ближе 32 px к кромке рамки / бара — встаёт к ней вплотную и сливается. Место запоминается (`~/.config/omarchy/panel-places.json`) — следующее открытие сразу там; двойной клик по ручке возвращает панель к бару. Так же и карточки виджетов стола (`"edgeMerge": true`, по умолчанию): карточка с якорем у кромки бара / рамки или отпущенная ближе 32 px встаёт вплотную и сливается, а рамка на стыке разрывает свой контур (места стыков виджеты пишут бар-плагину в `$XDG_RUNTIME_DIR/omarchy-merge-widgets-<экран>.json`). | клавиша самой панели |
| Меню выключения | блокировка, сон, гибернация, выход, перезагрузка, выключение — три последних со второго нажатия за 3 с | `omarchy-shell widgets togglePower` |
| Меню выключения glyph · Clip | `"powerStyle": "glyph"` — меню выключения glyph-rice вместо полосы у края: почти чёрный экран, столбец слов Doto, выбранное крупно с красной точкой, кольцо аптайма из 60 точек; ↑↓ / j k, Enter. `"clipboardPanel": "glyph"` — Super+Ctrl+V открывает Clip из glyph-rice вместо стокового менеджера: история cliphist слева, запись целиком справа (текст, код, ссылка, образец цвета, картинка точками), фильтры все / текст / ссылки / картинки (Tab), Ctrl+P — закрепить, Del — удалить, Enter — скопировать | `togglePower` · `omarchy-shell widgets clip` |
| Prefs | быстрые настройки активного райса в виде Prefs из glyph-rice, своими шрифтами, скруглениями и акцентом райса (prefs/PTheme.qml): слева столбец слов Doto, справа раздел «предметом» — HOME (макет бенто 3 × 3, клик по плитке или чипу добавляет / убирает), DECK (экран с панелью у края, секции по порядку, кольцо задержки), BAR (части трея и заголовок окна раскладки `glyph-rice`), LOOK (точки / серое / цвет, кольца шага точек и яркости, glyph-dark / light, переключатель обоев), WINDOWS (кольца зазоров, рамки, скругления), IDLE (минуты до заставки и блокировки — в `idle` shell.json), SHELL (какие части из glyph: Super+M, меню выключения, буфер, picker обоев, лаунчер, лок). Пишет те же файлы, что Customizer, его бэкендом | `omarchy-shell widgets togglePrefs` · Super+Alt+I |
| Обзор | сетка рабочих столов с обоями и живыми превью окон; клик — перейти, перетащить окно — перенести | `omarchy-shell widgets toggleOverview` |
| Режим правки | виджеты рабочего стола перетаскиваются куда угодно (сетка 8 px, прилипание к отступу от края); ПКМ — поверх окон, вернуть на место, скрыть; Esc / Enter — готово | `omarchy-shell widgets toggleEdit` |

**Стиль бара.** Дашборд и меню выключения следуют бару (`~/.config/omarchy/bar-skin.json` из
[omarchy-bar-skins](https://github.com/KamradSmeshnyavy/omarchy-bar-skins), без него — стоковые цвета):
со сплошным баром у края (`frame`, `hug`, `full`) они вырастают из-под него с вогнутыми углами; с прозрачным
или плавающим баром — плавающая карточка с отступом и тенью. У стеклянного бара — стеклянная панель
(с размытием, если оно включено в Hyprland). Всё можно задать вручную.

**Токены стиля.** `~/.config/omarchy/style.json` (пишет
[omarchy-customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) → Пресеты → Стиль) настраивает панели поверх
бара: `elevation` 0–2 (тени), `motion` (множитель скорости анимаций, 0 — без них), `material` (`auto` / `solid` /
`glass`), `cornerScale` (0 — прямые углы), `typeface` (`shell` — шрифт Omarchy, `profile` — sans из
`~/.config/omarchy/fonts.json`, `hand` — рукописный Caveat; иконки всегда в шрифте Omarchy). `material` `paper` / `soft` /
`brutal` / `bevel` / `glow` рисует плавающие панели через `StyleCard.qml`: лист бумаги (рваный край, тайл `texture`, скотч),
неоморфный рельеф, толстая рамка с жёсткой тенью, ретро-кант, неоновое свечение. Нет файла — вид как раньше.

![Дашборд в стилях Стекло, Бумага и DOT-MATRIX](screenshots/dashboard.webp)

| Обзор столов | Меню выключения |
| :---: | :---: |
| ![Обзор](screenshots/overview.webp) | ![Меню выключения](screenshots/power.webp) |

<!-- Demo video: repo-videos/omarchy-desktop-widgets.mp4 — drag it here when editing this file on GitHub -->

## Установка

```sh
omarchy plugin add https://github.com/KamradSmeshnyavy/omarchy-desktop-widgets --enable
omarchy restart shell
```

Необязательно: `cava` (визуализатор). Клавиши и размытие для Hyprland (Lua-конфиг) — как в английском README.

## Требования

Omarchy 4 (Quattro) с его оболочкой. Проверено на Omarchy 4.0.6 и Quickshell 0.3.2.

- Необязательно: `cava` (визуализатор), `zenity` (правка заметки или цитаты), `brightnessctl` (яркость в быстрых настройках, есть в Omarchy).
- Необязательно: [Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) — его стили (Flat, Glass, Fluent, DOT-MATRIX) пишут `~/.config/omarchy/style.json`, плагин их подхватывает; без него — значения по умолчанию.
- Дизайны DOT-MATRIX используют шрифты из [Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) (Doto, Space Grotesk, Space Mono); без них — шрифт Omarchy.

## Удаление

```sh
omarchy plugin remove kamradsmeshnyavy.widgets
omarchy restart shell
```

Настройки остаются в `~/.config/omarchy/widgets.json`, `~/.config/omarchy/widgets-todo.json` — удалите их вручную, если не нужны.

## Настройки

`~/.config/omarchy/widgets.json`, применяются на лету (нет файла — значения по умолчанию).
[Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) правит его в Рабочий стол → Виджеты / Дашборд.
Ключи и значения — в [README.md](README.md#settings).

**Части следуют райсу.** `homeLayout`, `homeCards`, `deckLayout`, `deckCards`, `settingsPanel`, `powerStyle` и `clipboardPanel` по умолчанию `auto` (встроенные стили тоже пишут `auto`): виджет сам выбирает вид по активному райсу — `"rice"` в `~/.config/omarchy/style.json`, его пишет вкладка Customizer **Райсы**, — а без райса по id стиля. У Glyph — свои дом, Deck, Quick, меню выключения и Clip; у DOT-MATRIX — дом и Deck glyph с панелью-шторкой; у Vitreus (и стиля `liquid`) — дом minimal, Deck во весь экран в материале основы и панели из бара; у остальных стилей — дом и Deck glyph в материале стиля. Явное значение важнее `auto`.

**Домашний экран** (раскладка `glyph` повторяет вид [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice) — у него
GPL-3.0, поэтому код написан с нуля, а не скопирован): на пустом столе (на мониторе нет окон). Раскладки:
`glyph` — огромные точечные часы, «дата · неделя», приветствие в две строки и бенто из круглых и квадратных плиток;
`classic` — часы и плитки 3×3 в материале стиля; `minimal` — часы и приветствие в углу. Ключи: `"home": true`,
`"homeLayout"`, `"homeScale"`, `"homeWidgets"` (бенто glyph по порядку: `weather` `calendar` `cpu` `ram` `battery` `temp`
`disk` `cava` — одна клетка, `player` `network` — две, `system` — три; не влезшая в три ряда плитка не показывается),
`"homeCards"` (`glyph` — плоские карточки как в glyph-rice, `style` — материал стиля), `"homeGreeting"`, `"homeDate"`,
`"homeMeta"`, `"homeBlink"` (мигающее двоеточие), `"homeName"` (имя в приветствии, пусто — `$USER`), `"homeDots"`
(точечная сетка), `"homeHideWidgets"` (прятать виджеты на якорях, пока он виден; свободные и плавающие остаются).
Customizer → Рабочий стол → Виджеты → Домашний экран.

**Deck** (вид [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice), код свой): курсор задержался на полосе 2 px у
нижнего края (150 мс) — выезжает дашборд: часы с точками светового дня, восходом и закатом, погода с прогнозом на 4 дня,
кольца CPU / памяти / температуры с процессами и матрицей CPU, сеть с матрицей приёма, плеер с точечной обложкой;
прячется через 300 мс, как курсор ушёл; над полноэкранными окнами не срабатывает. Ключи: `"deck": true`,
`"deckSections"` (по порядку: `clock` `weather` `perf` `net` `media`), `"deckCards"` (`glyph` · `style`), `"deckScale"`,
`"deckDelay"`, `"deckLayout"` (`panel` — секции в одной карточке, как в glyph-rice · `compact` — тонкая полоска: время,
три мини-кольца, трек с кнопкой, сеть · `full` — весь экран: затемнение `"deckDim"`, крупные часы и секции отдельными
карточками; закрывается кликом мимо или Esc), `"deckTrigger"` (`dwell` — задержаться у края · `bump` — толчок: коснуться
края, чуть отвести курсор и снова в край за 0,6 с; «давить» в край не отличить от «стоять» — Hyprland держит курсор у края
и событий движения не шлёт). IPC: `omarchy-shell widgets toggleDeck`. При включённом Deck нижняя зона `edgeHover` (лаунчер) выключена.
Customizer → Рабочий стол → Виджеты → Deck.

**Открепляемые виджеты** (идея из [Vitreus](https://github.com/natepayn3/Vitreus), код свой). Super+Ctrl+W
(`omarchy-shell widgets toggleEdit`) — режим правки: виджеты перетаскиваются мышью, ПКМ — «Поверх окон», «Вернуть
на место», «Скрыть». Перетащенный виджет получает `"<имя>Anchor": "free"` и `"<имя>Pos": { "cx", "cy", "screen" }` —
центр в долях экрана, так раскладка переживает смену разрешения; прежний якорь хранится в `<имя>AnchorDocked`.
`"<имя>Float": true` выносит свободный виджет на отдельный слой **поверх окон** (namespace `omarchy-widgets-float`,
создаётся, только пока такой виджет есть) — как плавающее окно. Кнопка-булавка на плеере дашборда
(`omarchy-shell widgets detach media`) отправляет карточку туда; `omarchy-shell widgets dock <имя>` возвращает. При наведении на плавающий виджет — две кнопки: «переместить» (режим правки) и «вернуть на место».
Имена: `clock` `media` `sysinfo` `network` `todo` `quote` `photo`. При `"desktopWidgets": false` виджеты на якорях
скрыты, но свободные и плавающие показываются, а режим правки показывает всё.

Правки QML — после `omarchy restart shell`. `BarStyle.qml` и `StyleCard.qml` общие с
[omarchy-edge-osd](https://github.com/KamradSmeshnyavy/omarchy-edge-osd) и
[omarchy-drawer-notifications](https://github.com/KamradSmeshnyavy/omarchy-drawer-notifications).

## Лицензия

GPL-3.0 (см. [LICENSE](LICENSE); прежние версии — MIT), авторы заимствований — в [NOTICE](NOTICE). Quick и Shot
(`QuickPanel.qml`, `glyph/`) — из [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice) (GPL-3.0).
