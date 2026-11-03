# Omarchy Desktop Widgets

[🇬🇧 English](README.md)

Виджеты рабочего стола, дашборд, меню выключения и обзор рабочих столов для [Omarchy](https://omarchy.org)
в стиле твоего бара. Один плагин типа `service`: cava, MPRIS и опрос `/proc` работают один раз на все мониторы.

| Часть | Что делает | Открыть |
|---|---|---|
| Виджеты | часы (4 стиля + `nihil` Doto), карточка «сейчас играет» (с LED-обложкой `DotScreen` в стиле `nihil`), визуализатор cava (bars/mirror/wave + точки `nihil`), кольца или 28-LED шкалы CPU/RAM/температуры/батареи — на слое Bottom, под окнами | всегда |
| Дашборд | `default` (плеер, календарь, погода, графики CPU/RAM) или `nihil` (часы Doto, LED-обложка MPRIS, 24×6 спектр, 28-LED циферблаты CPU/RAM/°C, LED-осциллограф сети rx/tx) | `omarchy-shell widgets toggleDashboard` |
| Панель настроек | правая чёрная аппаратная панель NIHIL: 3×2 круглых тумблера (Wi-Fi, Bluetooth, звук, микрофон, DND, ночной свет), 24-сегментные LED-слайдеры, списки Wi-Fi/BT/аудио, история уведомлений и действия сессии с подтверждением | `omarchy-shell widgets toggleSettings` |
| Меню выключения | блокировка, сон, гибернация, выход, перезагрузка, выключение — три последних со второго нажатия за 3 с | `omarchy-shell widgets togglePower` |
| Обзор | сетка рабочих столов с обоями и живыми превью окон; клик — перейти, перетащить окно — перенести | `omarchy-shell widgets toggleOverview` |

**Стиль бара.** Дашборд и меню выключения следуют бару (`~/.config/omarchy/bar-skin.json` из
[omarchy-bar-skins](https://github.com/KamradSmeshnyavy/omarchy-bar-skins), без него — стоковые цвета):
со сплошным баром у края (`frame`, `hug`, `full`) они вырастают из-под него с вогнутыми углами; с прозрачным
или плавающим баром — плавающая карточка с отступом и тенью. У стеклянного бара — стеклянная панель
(с размытием, если оно включено в Hyprland). Всё можно задать вручную.

## Установка

```sh
git clone https://github.com/KamradSmeshnyavy/omarchy-desktop-widgets ~/.config/omarchy/plugins/kamradsmeshnyavy.widgets
omarchy-shell shell rescanPlugins
omarchy plugin enable kamradsmeshnyavy.widgets
```

Необязательно: `cava` (визуализатор). Клавиши и размытие для Hyprland (Lua-конфиг) — как в английском README.

## Настройки

`~/.config/omarchy/widgets.json`, применяются на лету (нет файла — значения по умолчанию).
[Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) правит его в Рабочий стол → Виджеты / Дашборд.
Ключи и значения — в [README.md](README.md#settings).

Правки QML — после `omarchy restart shell`. `BarStyle.qml` общий с
[omarchy-edge-osd](https://github.com/KamradSmeshnyavy/omarchy-edge-osd) и
[omarchy-drawer-notifications](https://github.com/KamradSmeshnyavy/omarchy-drawer-notifications).

## Лицензия

MIT
