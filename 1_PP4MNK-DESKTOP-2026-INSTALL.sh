#!/bin/bash
# PP4MNK DESKTOP 2026 - ONE CLICK INSTALLER
# Premium Clean style for XFCE_FUSILLI / DevuanPup / Puppy XFCE
# by pp4mnk

set -u

APPNAME="PP4MNK DESKTOP 2026"
BACKUP_DIR="$HOME/PP4MNK_DESKTOP_BACKUP_$(date +%Y%m%d_%H%M%S)"
LOGFILE="/tmp/pp4mnk-desktop-2026.log"
WALLDIR="$HOME/Pictures/PP4MNK-Wallpapers"
THEME_DIR="$HOME/.themes"
ICON_DIR="$HOME/.icons"
AUTOSTART_DIR="$HOME/.config/autostart"
XFCE_PANEL_DIR="$HOME/.config/xfce4/panel"
XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
PLANK_DIR="$HOME/.config/plank/dock1"

mkdir -p "$WALLDIR" "$THEME_DIR" "$ICON_DIR" "$AUTOSTART_DIR"
: > "$LOGFILE"

msg() {
  echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOGFILE"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_dialog() {
  if have_cmd yad; then
    yad --center --title="$APPNAME" --width=520 --height=280 \
      --text="<b>PP4MNK DESKTOP 2026</b>\n\nElige qué quieres hacer:" \
      --button="Instalar Premium Clean:0" \
      --button="Solo aplicar ajustes XFCE:2" \
      --button="Restaurar último backup:3" \
      --button="Salir:1"
    return $?
  else
    echo ""
    echo "===== $APPNAME ====="
    echo "1) Instalar Premium Clean"
    echo "2) Solo aplicar ajustes XFCE"
    echo "3) Restaurar último backup"
    echo "4) Salir"
    read -r -p "Opción: " op
    case "$op" in
      1) return 0 ;;
      2) return 2 ;;
      3) return 3 ;;
      *) return 1 ;;
    esac
  fi
}

backup_config() {
  msg "Creando backup en $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  for p in \
    "$HOME/.config/xfce4" \
    "$HOME/.config/plank" \
    "$HOME/.config/gtk-3.0" \
    "$HOME/.gtkrc-2.0" \
    "$HOME/.config/autostart/plank.desktop" \
    "$HOME/.config/autostart/pp4mnk-ram-widget.desktop"; do
    [ -e "$p" ] && cp -a "$p" "$BACKUP_DIR/" 2>/dev/null
  done
  echo "$BACKUP_DIR" > "$HOME/.pp4mnk_desktop_last_backup"
}

restore_backup() {
  if [ -f "$HOME/.pp4mnk_desktop_last_backup" ]; then
    LAST="$(cat "$HOME/.pp4mnk_desktop_last_backup")"
  else
    LAST="$(ls -dt "$HOME"/PP4MNK_DESKTOP_BACKUP_* 2>/dev/null | head -n1 || true)"
  fi

  if [ -z "${LAST:-}" ] || [ ! -d "$LAST" ]; then
    msg "No se encontró ningún backup."
    notify "No hay backup para restaurar."
    exit 1
  fi

  msg "Restaurando backup desde $LAST"
  [ -d "$LAST/xfce4" ] && rm -rf "$HOME/.config/xfce4" && cp -a "$LAST/xfce4" "$HOME/.config/"
  [ -d "$LAST/plank" ] && rm -rf "$HOME/.config/plank" && cp -a "$LAST/plank" "$HOME/.config/"
  [ -d "$LAST/gtk-3.0" ] && rm -rf "$HOME/.config/gtk-3.0" && cp -a "$LAST/gtk-3.0" "$HOME/.config/"
  [ -f "$LAST/.gtkrc-2.0" ] && cp -a "$LAST/.gtkrc-2.0" "$HOME/"
  xfce4-panel -r >/dev/null 2>&1 || true
  notify "Backup restaurado. Reinicia sesión para verlo perfecto."
}

notify() {
  if have_cmd yad; then
    yad --center --title="$APPNAME" --width=420 --text="$1" --button="OK:0" >/dev/null 2>&1 || true
  elif have_cmd notify-send; then
    notify-send "$APPNAME" "$1" || true
  else
    echo "$1"
  fi
}

install_if_possible() {
  # Puppy/DevuanPup normally uses apt only if available. This installer never forces it.
  if have_cmd plank; then
    msg "Plank ya está instalado."
  else
    msg "Plank no encontrado. Si tienes apt, intento instalarlo."
    if have_cmd apt-get; then
      apt-get update && apt-get install -y plank || msg "No se pudo instalar Plank automáticamente."
    else
      msg "No hay apt-get. Instala Plank manualmente si lo quieres."
    fi
  fi

  if ! have_cmd xfconf-query; then
    msg "Aviso: xfconf-query no encontrado. Algunos ajustes se omitirán."
  fi
}

create_wallpaper() {
  WALL="$WALLDIR/PP4MNK_FUSILLI_PREMIUM_CLEAN.svg"
  cat > "$WALL" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <radialGradient id="g1" cx="70%" cy="35%" r="70%">
      <stop offset="0%" stop-color="#303238"/>
      <stop offset="45%" stop-color="#18191d"/>
      <stop offset="100%" stop-color="#0b0c0f"/>
    </radialGradient>
    <linearGradient id="red" x1="0" x2="1">
      <stop offset="0" stop-color="#b71c1c"/>
      <stop offset="1" stop-color="#ff3939"/>
    </linearGradient>
    <filter id="blur"><feGaussianBlur stdDeviation="18"/></filter>
  </defs>
  <rect width="1920" height="1080" fill="url(#g1)"/>
  <circle cx="1470" cy="260" r="360" fill="#ffffff" opacity="0.035"/>
  <circle cx="1420" cy="260" r="260" fill="#ffffff" opacity="0.025"/>
  <path d="M1180 80 C1420 260 1370 490 1650 690" stroke="#ff3030" stroke-width="8" opacity="0.35" fill="none" filter="url(#blur)"/>
  <path d="M1160 120 C1410 270 1330 500 1640 745" stroke="#e53935" stroke-width="3" opacity="0.65" fill="none"/>
  <path d="M1120 210 C1370 360 1330 560 1570 810" stroke="#ffffff" stroke-width="2" opacity="0.14" fill="none"/>
  <g transform="translate(320,285)">
    <text x="0" y="0" fill="#f3f4f6" font-family="Noto Sans, DejaVu Sans, Arial" font-size="70" letter-spacing="6">XFCE_<tspan fill="#ef3939">FUSILLI</tspan></text>
    <text x="7" y="58" fill="#cfd2d8" font-family="Noto Sans, DejaVu Sans, Arial" font-size="27">by <tspan fill="#ef3939">pp4mnk</tspan></text>
    <line x1="0" y1="92" x2="560" y2="92" stroke="#ef3939" stroke-width="2" opacity="0.75"/>
    <text x="0" y="150" fill="#ffffff" font-family="Noto Sans, DejaVu Sans, Arial" font-size="32">Education runs faster in <tspan fill="#ef3939" font-weight="bold">RAM</tspan> 🚀</text>
    <text x="0" y="198" fill="#aeb4be" font-family="Noto Sans, DejaVu Sans, Arial" font-size="22">Minimal · Fast · Stable · Secure</text>
  </g>
  <g transform="translate(330,725)" opacity="0.95">
    <rect x="0" y="0" width="640" height="90" rx="18" fill="#111217" opacity="0.68" stroke="#ffffff" stroke-opacity="0.14"/>
    <text x="32" y="55" fill="#f4f4f4" font-family="Noto Sans, DejaVu Sans, Arial" font-size="25">“Not just a lightweight system — it’s an idea flying in RAM 🚀”</text>
  </g>
  <text x="1720" y="990" fill="#ef3939" font-family="DejaVu Sans, Arial" font-style="italic" font-size="34">pp4mnk</text>
</svg>
SVG
  msg "Wallpaper creado: $WALL"
}

apply_xfce_settings() {
  msg "Aplicando ajustes XFCE Premium Clean"
  mkdir -p "$HOME/.config/gtk-3.0"

  cat > "$HOME/.gtkrc-2.0" <<'EOFGTK2'
gtk-theme-name="Orchis-Dark-Compact"
gtk-icon-theme-name="Newaita-dark"
gtk-font-name="Noto Sans 11"
gtk-cursor-theme-size=48
EOFGTK2

  cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOFGTK3'
[Settings]
gtk-theme-name=Orchis-Dark-Compact
gtk-icon-theme-name=Newaita-dark
gtk-font-name=Noto Sans 11
gtk-application-prefer-dark-theme=true
gtk-cursor-theme-size=48
EOFGTK3

  if have_cmd xfconf-query; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "Orchis-Dark-Compact" 2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Newaita-dark" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 11" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/theme -s "Orchis-Dark-Compact" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_font -s "Noto Sans Bold 10" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/button_layout -s "O|HMC" 2>/dev/null || true
  fi
}

apply_wallpaper() {
  WALL="$WALLDIR/PP4MNK_FUSILLI_PREMIUM_CLEAN.svg"
  if have_cmd xfconf-query; then
    for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image || true); do
      xfconf-query -c xfce4-desktop -p "$prop" -s "$WALL" 2>/dev/null || true
    done
    for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep image-style || true); do
      xfconf-query -c xfce4-desktop -p "$prop" -s 5 2>/dev/null || true
    done
  fi
  msg "Wallpaper aplicado si XFCE lo permite."
}

configure_plank() {
  msg "Configurando Plank"
  mkdir -p "$PLANK_DIR/launchers" "$AUTOSTART_DIR"

  cat > "$PLANK_DIR/settings" <<'EOFPLANK'
[PlankDockPreferences]
CurrentWorkspaceOnly=false
IconSize=52
HideMode=1
UnhideDelay=0
HideDelay=250
Monitor=
DockItems=launchers
Position=3
Offset=0
Theme=Default
Alignment=3
ItemsAlignment=3
LockItems=false
PressureReveal=false
PinnedOnly=false
ZoomEnabled=true
ZoomPercent=115
EOFPLANK

  cat > "$AUTOSTART_DIR/plank.desktop" <<'EOFPLANKDESK'
[Desktop Entry]
Type=Application
Name=Plank Dock
Exec=sh -c "sleep 2; plank"
Icon=plank
Terminal=false
X-GNOME-Autostart-enabled=true
EOFPLANKDESK

  if have_cmd plank; then
    pkill plank >/dev/null 2>&1 || true
    nohup plank >/dev/null 2>&1 &
  fi
}

create_ram_widget() {
  msg "Creando mini widget RAM pp4mnk"
  mkdir -p "$HOME/.local/bin" "$AUTOSTART_DIR"
  cat > "$HOME/.local/bin/pp4mnk-ram-widget" <<'EOFRAM'
#!/bin/bash
while true; do
  RAM=$(free | awk '/Mem:/ {printf("%.0f", $3/$2*100)}')
  if command -v yad >/dev/null 2>&1; then
    yad --notification --image=utilities-system-monitor --text="PP4MNK RAM Beast: ${RAM}%" --command="xfce4-taskmanager" --listen < <(while true; do echo "tooltip:PP4MNK RAM Beast: ${RAM}%"; sleep 20; done)
    exit
  fi
  sleep 60
done
EOFRAM
  chmod +x "$HOME/.local/bin/pp4mnk-ram-widget"

  cat > "$AUTOSTART_DIR/pp4mnk-ram-widget.desktop" <<'EOFRAMDESK'
[Desktop Entry]
Type=Application
Name=PP4MNK RAM Widget
Exec=/root/.local/bin/pp4mnk-ram-widget
Icon=utilities-system-monitor
Terminal=false
X-GNOME-Autostart-enabled=true
EOFRAMDESK
  sed -i "s|Exec=/root|Exec=$HOME|" "$AUTOSTART_DIR/pp4mnk-ram-widget.desktop"
}

fusilli_fast_hint() {
  msg "Nota Fusilli: los ajustes visuales del plugin se mantienen seguros."
  cat > "$HOME/PP4MNK_FUSILLI_FAST_MODE_NOTES.txt" <<'EOFNOTE'
PP4MNK FUSILLI FAST MODE - ajustes recomendados manuales si quieres afinar desde ccsm/fusilli:

ACTIVAR:
- Animations
- Fade
- Cube
- Expo
- Scale
- Shadows
- Opacity

SUAVE:
- Wobbly Windows muy bajo o desactivado para uso serio.

DESACTIVAR para look premium:
- Firepaint / fuego
- Rain / nieve / efectos decorativos pesados

Velocidad recomendada:
- Fade: 100-140 ms
- Minimize: 120-160 ms
- Desktop switch: rápido, sin pausa larga

Idea clave:
Tiene que parecer rápido, no solamente bonito.
EOFNOTE
}

install_full() {
  backup_config
  install_if_possible
  create_wallpaper
  apply_xfce_settings
  apply_wallpaper
  configure_plank
  create_ram_widget
  fusilli_fast_hint
  xfce4-panel -r >/dev/null 2>&1 || true
  notify "Instalación completada. Reinicia sesión o pulsa Ctrl+Alt+Backspace y vuelve a entrar para verlo perfecto.\n\nBackup: $BACKUP_DIR\nNotas: $HOME/PP4MNK_FUSILLI_FAST_MODE_NOTES.txt"
}

install_xfce_only() {
  backup_config
  create_wallpaper
  apply_xfce_settings
  apply_wallpaper
  xfce4-panel -r >/dev/null 2>&1 || true
  notify "Ajustes XFCE aplicados. Backup: $BACKUP_DIR"
}

main() {
  run_dialog
  choice=$?
  case "$choice" in
    0) install_full ;;
    2) install_xfce_only ;;
    3) restore_backup ;;
    *) msg "Salida." ;;
  esac
}

main "$@"
