#!/usr/bin/python3
"""Бэкенд панели настроек Sheet (порт его Settings из github.com/elifouts/Dotfiles, GPL-3.0 — у него hypr-settings.py).

Ключи панели:
  config.<раздел>.<опция>…  опция Hyprland. Те, что ведёт Customizer (зазоры, рамка, скругление), — через его твики;
                            остальные — в ~/.config/omarchy/sheet.json, сразу `hyprctl eval hl.config(...)`, а для
                            перезагрузок Hyprland пишется ~/.config/omarchy/sheet.lua (подключает hypr/looknfeel.lua
                            после хука Customizer — как его overrides.lua после стиля).
  animation.*               его анимации: кривая, скорость, вид окон и столов (preset — имя набора).
  w.<ключ>                  настройка виджетов (widgets.json) — твиком Customizer.
  look.<ключ>               вид обоев (wallpaper-look.json).
  idle.lock / idle.screensaver   минуты (в shell.json — секунды).
  part.picker / part.launcher / part.lock   стиль пикера, скин лаунчера, дизайн лока — `apply` Customizer.
  bar.tray.<часть> / bar.title / bar.titleLength   раскладка бара glyph-rice в shell.json (как прежняя Prefs).

  sheet.py state KEY…       → JSON {values, missing, caps, lists, active}
  sheet.py set KEY=JSON…    (null — сбросить)
  sheet.py do rice|preset|font|bar|theme|world|save VALUE…
"""
import json
import re
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOME = Path.home()
CFG = HOME / ".config/omarchy"
SHEET = CFG / "sheet.json"
SHEET_LUA = CFG / "sheet.lua"
CZ = CFG / "plugins/kamradsmeshnyavy.customizer/backend/run.py"
LOOK = CFG / "wallpaper-look.json"
SHELL = CFG / "shell.json"
WIDGETS = CFG / "widgets.json"

# опции Hyprland, которыми владеет Customizer (его windows.json): панель меняет их его твиком
OWNED = {"config.general.gaps_in": "windowGapsIn", "config.general.gaps_out": "windowGapsOut",
         "config.general.border_size": "windowBorder", "config.decoration.rounding": "windowDecoRounding"}

# его overrides.lua: листья анимаций и их базовая скорость
LEAVES = [("windows", 4, "W"), ("windowsOut", 3.5, "W"), ("windowsMove", 3, None), ("fade", 4, None), ("border", 6, None),
          ("workspaces", 4, "S"), ("specialWorkspace", 4, "S"), ("layers", 3, "popin 80%")]


def load(p, d):
    try:
        return json.loads(Path(p).read_text())
    except (OSError, ValueError):
        return d


def write(p, data):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    t = p.with_name(p.name + ".sheet-tmp")
    t.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    t.replace(p)


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def cz(*args):
    return run("/usr/bin/python3", "-I", str(CZ), *args)


def getopt(key):
    """config.a.b.c → (значение, есть ли опция)."""
    out = run("hyprctl", "-j", "getoption", ":".join(key.split(".")[1:]))
    try:
        d = json.loads(out)
    except ValueError:
        return None, False
    for t in ("bool", "int", "float", "str"):
        if t in d:
            v = d[t]
            return (round(v, 4) if isinstance(v, float) else v), True
    if "css" in d:  # зазоры: «4 4 4 4»
        try:
            return int(str(d["css"]).split()[0]), True
        except (ValueError, IndexError):
            return None, True
    if "custom" in d:
        return d["custom"], True
    return None, False


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x) for x in v) + " }"
    return "{ " + ", ".join(f"[{json.dumps(k)}] = {lua(x)}" for k, x in sorted(v.items())) + " }"


def nest(flat):
    """{"general.snap.enabled": true} → {"general": {"snap": {"enabled": true}}}"""
    out = {}
    for k, v in flat.items():
        cur, parts = out, k.split(".")
        for p in parts[:-1]:
            cur = cur.setdefault(p, {})
        cur[parts[-1]] = v
    return out


def anim_lua(a):
    if not a or not a.get("curve"):
        return ""
    c, mult = a["curve"], max(0.1, float(a.get("speed") or 1))
    win, ws = a.get("window") or "popin 90%", a.get("workspace") or "slide"
    lines = [f'hl.curve("sheet", {{ type = "bezier", points = {{ {{ {c[0]}, {c[1]} }}, {{ {c[2]}, {c[3]} }} }} }})']
    for leaf, base, style in LEAVES:
        st = win if style == "W" else ws if style == "S" else style
        s = f', style = {json.dumps(st)}' if st else ""
        lines.append(f'hl.animation({{ leaf = "{leaf}", enabled = true, speed = {round(base / mult, 3)}, bezier = "sheet"{s} }})')
    return "\n".join(lines)


def write_lua(s):
    body = []
    if s.get("config"):
        body.append("hl.config(" + lua(nest(s["config"])) + ")")
    if s.get("animation"):
        body.append(anim_lua(s["animation"]))
    SHEET_LUA.write_text("-- Панель настроек Sheet (kamradsmeshnyavy.widgets/sheet): пишется sheet.py, руками не править.\n"
                         + "\n".join(b for b in body if b) + "\n")


def eval_lua(code):
    if code.strip():
        run("hyprctl", "eval", code)


TRAY = ["wifi", "bluetooth", "sound", "battery"]
TITLE_SRC = "~/.config/omarchy/plugins/kamradsmeshnyavy.bar/modules/GlyphTitle.qml"


def bar_entry(sh, eid):
    for row in ((sh.get("bar") or {}).get("layout") or {}).values():
        for e in row if isinstance(row, list) else []:
            if isinstance(e, dict) and e.get("id") == eid:
                return e
    return None


# ── state ──
def state(keys):
    s = load(SHEET, {})
    cfg, anim = s.get("config", {}), s.get("animation", {})
    wid = load(WIDGETS, {})
    look = load(LOOK, {})
    idle = (load(SHELL, {}).get("idle") or {})
    values, missing = {}, []
    hk = [k for k in keys if k.startswith("config.")]
    with ThreadPoolExecutor(12) as ex:
        got = dict(zip(hk, ex.map(getopt, hk)))
    for k in keys:
        if k in got:
            v, ok = got[k]
            if not ok:
                missing.append(k)
            elif v is not None:
                values[k] = v
        elif k.startswith("animation."):
            n = k.split(".", 1)[1]
            if n in anim:
                values[k] = anim[n]
        elif k.startswith("w."):
            n = k[2:]
            if n in wid:
                values[k] = wid[n]
        elif k.startswith("look."):
            n = k[5:]
            if n in look:
                values[k] = look[n]
        elif k.startswith("idle."):
            n = k[5:]
            if n in idle:
                values[k] = round(int(idle[n] or 0) / 60)
    if "animation" in s and s["animation"].get("preset"):
        values["animation.preset"] = s["animation"]["preset"]
    picker = load(CFG / "image-picker.json", {}).get("style", "slices")
    launcher = load(CFG / "extensions/menu-skin.json", {}).get("skin", "")
    lockd = load(CFG / "lock-design.json", {}).get("design", "")
    values.update({"part.picker": picker, "part.launcher": launcher, "part.lock": lockd})
    sh = load(SHELL, {})
    tray, title = bar_entry(sh, "glyph-tray"), bar_entry(sh, "glyph-title")
    if tray:
        parts = [x for x in str(tray.get("parts") or ",".join(TRAY)).replace(" ", "").split(",") if x]
        for t in TRAY:
            values["bar.tray." + t] = t in parts
        values["bar.title"] = bool(title)
        values["bar.titleLength"] = int((title or {}).get("length") or 220)

    devices = load_cmd(["hyprctl", "devices", "-j"]) or {}
    mons = load_cmd(["hyprctl", "monitors", "-j"]) or []
    caps = {"touchpad": any("touchpad" in m.get("name", "") for m in devices.get("mice", [])),
            "multimonitor": len(mons) > 1, "glyphBar": bool(tray)}
    # Retro CRT: шрифт и размер текста (его retro.font / retro.size) — crt.json → ui
    ui = (load(CFG / "crt.json", {}) or {}).get("ui") or {}
    for k in ("font", "size"):
        if ui.get(k) not in (None, ""):
            values["ui." + k] = ui[k]
    # Retro CRT: ручки шейдера и фильтра — у темы с трубкой (tube.json — темы crt-*)
    caps["crt"] = (HOME / ".local/state/omarchy/current/theme/tube.json").exists()
    if caps["crt"] and any(k.startswith(("crt.", "filter.")) for k in keys):
        knobs = load_cmd(["omarchy-crt-shader", "get"]) or {}
        values.update({"crt." + k: v for k, v in knobs.items()})
        cur = (HOME / ".local/state/hypr/screen-shader")
        values["crt.on"] = cur.exists() and "retro-crt.frag" in cur.read_text()
        values.update({"filter." + k: v for k, v in (load_cmd(["omarchy-crt-filter", "--get"]) or {}).items()})
    style = load(CFG / "style.json", {})
    return {"values": values, "missing": missing, "caps": caps, "lists": lists(),
            "active": {"rice": style.get("rice") or "", "style": style.get("id") or "", "preset": active_preset()}}


def active_preset():
    f = HOME / ".local/state/omarchy-customizer/active-preset"
    try:
        return f.read_text().strip()
    except OSError:
        return ""


def load_cmd(cmd):
    try:
        return json.loads(run(*cmd))
    except ValueError:
        return None


def rows(cat):
    out = []
    for line in cz("list", cat).splitlines():
        f = line.split("\t")
        if len(f) < 2:
            continue
        out.append({"label": f[0], "value": f[1], "cur": len(f) > 3 and f[3] == "1",
                    "note": f[4] if len(f) > 4 else "", "header": len(f) > 5 and f[5] == "header"})
    return out


def themes():
    """Установленные темы Omarchy и их цвета (colors.toml) — вкладка COLORS у не-Space райсов."""
    out = []
    for base in (CFG / "themes", Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "themes"):
        if not base.is_dir():
            continue
        for d in sorted(base.iterdir()):
            f = d / "colors.toml"
            if not f.is_file() or any(t["id"] == d.name for t in out):
                continue
            c = {}
            for ln in f.read_text(errors="ignore").splitlines():
                if "=" in ln and '"#' in ln:
                    k, v = ln.split("=", 1)
                    c[k.strip()] = v.strip().strip('"')[:7]
            # ключи colors.toml: color1…5 или именованные (темы райсов — red, green, …)
            alias = {"color1": "red", "color2": "green", "color3": "yellow", "color4": "blue", "color5": "magenta"}
            sw = [c.get(k) or c.get(alias.get(k, "")) for k in ("background", "color1", "color2", "color3", "color4", "color5", "accent")]
            sw = [x for x in sw if x]
            if len(sw) >= 4:
                out.append({"id": d.name, "c": sw})
    return out


CZP = CFG / "plugins/kamradsmeshnyavy.customizer"
USER_PRESETS = CFG / "customizer/presets"


def cur_rice():
    s = load(CFG / "style.json", {})
    return str(s.get("rice") or "")


def rice_entry(rid):
    for r in (load(CZP / "rices.json", {}) or {}).get("rices", []):
        if r.get("id") == rid:
            return r
    return None


def profiles(rid):
    """Профили райса для страницы PROFILES: его (rices.json → profiles / variants) и свои (поле rice в пресете)."""
    out, r = [], rice_entry(rid)
    if not r:
        return out
    for stem in (r.get("profiles") or [v["preset"] for v in r.get("variants", [])]):
        d = load(CZP / "presets" / f"{stem}.json", {})
        out.append({"id": stem, "name": d.get("name") or stem, "name_ru": d.get("name_ru") or "", "mine": False,
                    "path": str(CZP / "presets" / f"{stem}.json")})
    if USER_PRESETS.is_dir():
        for f in sorted(USER_PRESETS.glob("*.json")):
            d = load(f, {})
            if d.get("rice") == rid:
                out.append({"id": f.stem, "name": d.get("name") or f.stem, "name_ru": "", "mine": True, "path": str(f)})
    return out


def rice_themes(rid):
    """Темы своего райса (из его пресетов) — COLORS у райсов без своей палитры показывает только их."""
    out = []
    for p in profiles(rid):
        t = load(Path(p["path"]), {}).get("theme")
        if t and t not in out:
            out.append(t)
    return out


def lists():
    cur = (HOME / ".local/state/omarchy/current/theme.name")
    rid = cur_rice()
    l = {"rices": rows("rices"), "presets": rows("presets"), "fonts": rows("fonts"), "bars": rows("bar-skins"),
         "themes": themes(), "theme": cur.read_text().strip() if cur.exists() else "",
         "rice": rid, "profiles": profiles(rid), "riceThemes": rice_themes(rid)}
    if rid == "crt":
        l["barLayouts"] = [r for r in rows("bar-layouts") if r["label"] in ("crt", "crt-boxes", "crt-zen")]
    if rid == "modern":
        # его пять видов бара: раскладка + скин парой (Settings → Profile → Waybar)
        l["barLayouts"] = [r for r in rows("bar-layouts") if r["label"].startswith("modern")]
        l["modernColors"] = load_cmd(["omarchy-modern-colors", "--list"]) or []
        l["modernState"] = load_cmd(["omarchy-modern-colors", "--dump"]) or {}
        # обои его библиотеки с палитрами pywal (индекс omarchy-crt-library — общий с Retro)
        idx = HOME / ".cache/omarchy/crt-walls/index.json"
        l["walls"] = load(idx, [])
        if not l["walls"]:
            subprocess.Popen(["omarchy-crt-library", "index"], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if rid == "crt":
        l["crtColors"] = load_cmd(["omarchy-crt-colors", "--list"]) or []
        l["monoFonts"] = sorted({x.split(",")[0].strip() for x in run("fc-list", ":spacing=mono", "family").splitlines()
                                 if x.strip() and not x.startswith(".")})
    return l


# ── set ──
def setv(pairs):
    s = load(SHEET, {})
    cfg, anim = s.setdefault("config", {}), s.setdefault("animation", {})
    live, reload_ = {}, False
    wid_tw, look = [], None
    crt_set, filt_set = [], []
    for k, raw in pairs:
        v = json.loads(raw)
        if k in OWNED:
            if v is not None:
                cz("tweak", OWNED[k], "set", str(v))  # твик окон Customizer сам применяет (window_after)
            continue
        if k.startswith("config."):
            n = k[7:]
            if v is None:
                cfg.pop(n, None)
                reload_ = True
            else:
                cfg[n] = v
                live[n] = v
        elif k == "animation" and v is None:
            s.pop("animation", None)
            anim = None
            reload_ = True
        elif k.startswith("animation."):
            if anim is None:
                anim = s.setdefault("animation", {})
            n = k.split(".", 1)[1]
            if v is None:
                anim.pop(n, None)
            else:
                anim[n] = v
        elif k.startswith("w."):
            wid_tw.append((k[2:], v))
        elif k.startswith("look."):
            look = look or load(LOOK, {"look": "color", "pitch": 10, "bright": 100})
            look[k[5:]] = v
        elif k.startswith("idle."):
            sh = load(SHELL, {})
            sh.setdefault("idle", {})[k[5:]] = int(v or 0) * 60
            write(SHELL, sh)
        elif k.startswith("bar."):
            sh = load(SHELL, {})
            tray, title = bar_entry(sh, "glyph-tray"), bar_entry(sh, "glyph-title")
            if k.startswith("bar.tray.") and tray:
                parts = [x for x in str(tray.get("parts") or ",".join(TRAY)).replace(" ", "").split(",") if x]
                part = k[9:]
                if v and part not in parts:
                    parts.append(part)
                elif not v and part in parts:
                    parts.remove(part)
                tray["parts"] = ",".join(parts)
            elif k == "bar.title":
                lay = sh.setdefault("bar", {}).setdefault("layout", {})
                if v and not title:
                    lay.setdefault("left", []).append({"id": "glyph-title", "type": "qml", "source": TITLE_SRC, "length": 220})
                elif not v:
                    for r in lay.values():
                        if isinstance(r, list):
                            r[:] = [e for e in r if not (isinstance(e, dict) and e.get("id") == "glyph-title")]
            elif k == "bar.titleLength" and title:
                title["length"] = int(v)
            write(SHELL, sh)
        elif k.startswith("ui."):
            c = load(CFG / "crt.json", {}) or {}
            u = c.setdefault("ui", {})
            if v is None:
                u.pop(k[3:], None)
            else:
                u[k[3:]] = v
            write(CFG / "crt.json", c)
        elif k == "crt.on":
            run(str(CZ.parent.parent / "scripts/crt-toggle.sh"), "on" if v else "off", *(["retro-crt"] if v else []))
        elif k.startswith("crt."):
            if v is not None:
                crt_set += [k[4:], str(v)]
        elif k.startswith("filter."):
            if v is not None:
                filt_set += [k[7:], "1" if v is True else "0" if v is False else str(v)]
        elif k == "part.picker":
            cz("apply", "theme-switcher", "style:" + str(v))
        elif k == "part.launcher":
            cz("apply", "launcher", "skin:" + str(v))
        elif k == "part.lock":
            cz("apply", "lock", str(v))
    if not s.get("animation"):
        s.pop("animation", None)
    if not s.get("config"):
        s.pop("config", None)
    write(SHEET, s)
    write_lua(s)
    for k, v in wid_tw:
        cz("tweak", k, "set", json.dumps(v) if isinstance(v, (bool, list, dict)) else str(v))
    if look is not None:
        write(LOOK, look)
    if crt_set:
        run("omarchy-crt-shader", "set", *crt_set)
    if filt_set:
        subprocess.Popen(["omarchy-crt-filter", "--set", *filt_set, "--apply"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if reload_:
        run("hyprctl", "reload")
    else:
        if live:
            eval_lua("hl.config(" + lua(nest(live)) + ")")
        if s.get("animation") and any(k.startswith("animation.") for k, _ in pairs):
            eval_lua(anim_lua(s["animation"]))


def do(what, args):
    v = args[0] if args else ""
    if what == "rice" or what == "preset":
        cz("apply", "rices" if what == "rice" else "presets", v)
    elif what == "font":
        cz("apply", "fonts", v)
    elif what == "bar":
        cz("apply", "bar-skins", v)
    elif what == "barLayout":
        cz("apply", "bar-layouts", v)
    elif what == "theme":
        subprocess.Popen(["omarchy-theme-set", v], start_new_session=True)
    elif what == "world":  # тема, акцент, сид — мир Space
        subprocess.Popen(["omarchy-space-world"] + args, start_new_session=True)
    elif what == "profile":
        cz("apply", "presets", v if v.startswith("/") else str(CZP / "presets" / f"{v}.json"))
    elif what == "modernBar":  # вид бара Modern: раскладка и её скин
        cz("apply", "bar-layouts", v)
        if len(args) > 1:
            cz("apply", "bar-skins", args[1])
    elif what in ("modernColors", "modernWall"):  # его Themes: цвета (id, слот) / обои его библиотеки
        subprocess.Popen(["omarchy-modern-colors"] + (["--wallpaper", v] if what == "modernWall" else args),
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif what == "crtColors":  # его COLORS: id цветов и слот акцента
        subprocess.Popen(["omarchy-crt-colors"] + args, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif what == "delete" and re.fullmatch(r"[a-z0-9_-]+", v or ""):
        f = USER_PRESETS / f"{v}.json"
        if f.is_file() and load(f, {}).get("rice"):
            f.unlink()
    elif what == "save" and v.strip():
        # его «save as»: снимок Customizer под этим именем (без диалогов zenity)
        code = ("import sys; sys.path.insert(0, sys.argv[1]); from customizer import apply_ops, state; import os\n"
                "slug = apply_ops._slug(sys.argv[2]) or 'preset'\n"
                "os.makedirs(state.USER_PRESETS, exist_ok=True)\n"
                "apply_ops.snapshot(state.USER_PRESETS / (slug + '.json'), sys.argv[2], '')\n"
                "state.ACTIVE_PRESET.write_text(slug + '\\n')")
        run("/usr/bin/python3", "-I", "-c", code, str(CZ.parent), v.strip())
        # профиль райса: пометить райсом; у Retro CRT с цветами crt-live — состояние и сборка (тема собирается заново)
        slug = re.sub(r"[^a-z0-9_-]", "", v.strip().lower().replace(" ", "-")) or "preset"
        f = USER_PRESETS / f"{slug}.json"
        d = load(f, {})
        rid = cur_rice()
        if d and rid:
            d["rice"] = rid
            if d.get("theme") == "crt-live":
                d["crtState"] = load_cmd(["omarchy-crt-colors", "--dump"]) or {}
                d["build"] = ["omarchy-crt-colors", "--state", "{preset}"]
            elif d.get("theme") == "modern-live":
                d["modernState"] = load_cmd(["omarchy-modern-colors", "--dump"]) or {}
                d["build"] = ["omarchy-modern-colors", "--state", "{preset}"]
            write(f, d)


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "state":
        print(json.dumps(state(a[1:]), ensure_ascii=False))
    elif a[0] == "set":
        setv([x.split("=", 1) for x in a[1:] if "=" in x])
    elif a[0] == "do" and len(a) > 1:
        do(a[1], a[2:])


if __name__ == "__main__":
    main()
