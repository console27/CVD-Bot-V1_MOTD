#!/usr/bin/env bash
# ============================================================================
#  CVD BOT  -  Console VPS Deployment Bot  :  animated login (MOTD) installer
#  Created by Console - https://github.com/console27
#
#  Usage (run as root):
#    bash install-motd.sh              install the login screen, then preview it
#    bash install-motd.sh --preview    preview it without installing anything
#    bash install-motd.sh --uninstall  remove it and restore the default MOTD
#    bash install-motd.sh --purge      uninstall and also delete the settings file
#
#  KEEP_DEFAULT_MOTD=1 leaves the default Ubuntu/Debian MOTD in place.
#
#  How it works: a tiny hook in /etc/profile.d runs /usr/local/bin/cvdbot-motd
#  once per interactive login shell. It is skipped for scp/sftp/ssh-commands,
#  so nothing that is not a real terminal is ever touched. (The old pam_exec
#  approach cannot animate: PAM buffers all output and prints it in one go.)
# ============================================================================
set -Eeuo pipefail

BIN="/usr/local/bin/cvdbot-motd"
STUB="/etc/profile.d/cvdbot-motd.sh"
CONF="/etc/cvdbot-motd.conf"
MARK="# CVDBOT-DISABLED: "

# ---- installer UI -----------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_OK=$'\033[38;5;84m'; C_WARN=$'\033[38;5;220m'; C_ERR=$'\033[38;5;203m'
  C_ACC=$'\033[38;5;45m'; C_MUT=$'\033[38;5;245m'; C_VIO=$'\033[38;5;141m'
  BOLD=$'\033[1m'; NC=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_ERR=''; C_ACC=''; C_MUT=''; C_VIO=''; BOLD=''; NC=''
fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) G_OK='✔'; G_WARN='▲'; G_ERR='✖'; G_STEP='◆'; G_STAR='✦' ;;
  *) G_OK='[ok]'; G_WARN='[!]'; G_ERR='[x]'; G_STEP='==>'; G_STAR='*' ;;
esac
ok()   { printf '  %s%s%s %s\n' "$C_OK" "$G_OK" "$NC" "$*"; }
warn() { printf '  %s%s %s%s\n' "$C_WARN" "$G_WARN" "$*" "$NC"; }
die()  { printf '\n  %s%s ERROR%s %s\n\n' "$C_ERR" "$G_ERR" "$NC" "$*" >&2; exit 1; }
step() { printf '\n  %s%s%s %s%s%s\n' "$C_ACC" "$G_STEP" "$NC" "$BOLD" "$*" "$NC"; }
trap 'printf "\n"; warn "cancelled"; exit 130' INT

banner() {
  printf '\n  %s%sCVD BOT%s  %sConsole VPS Deployment Bot%s\n' "$BOLD" "$C_ACC" "$NC" "$C_MUT" "$NC"
  printf '  %sAnimated login screen installer%s\n' "$C_MUT" "$NC"
  printf '  %s%s%s Created by %s%sConsole%s  %shttps://github.com/console27%s\n' \
    "$C_VIO" "$G_STAR" "$NC" "$BOLD" "$C_VIO" "$NC" "$C_MUT" "$NC"
}

usage() {
  banner
  printf '\n  %sUSAGE%s  (run as root)\n' "$BOLD" "$NC"
  printf '    %sbash install-motd.sh%s              install, then preview\n' "$C_ACC" "$NC"
  printf '    %sbash install-motd.sh --preview%s    preview without installing\n' "$C_ACC" "$NC"
  printf '    %sbash install-motd.sh --uninstall%s  remove and restore the default MOTD\n' "$C_ACC" "$NC"
  printf '    %sbash install-motd.sh --purge%s      uninstall and delete %s\n' "$C_ACC" "$NC" "$CONF"
  printf '\n  %sKEEP_DEFAULT_MOTD=1%s keeps the default Ubuntu/Debian MOTD.\n\n' "$C_ACC" "$NC"
}

# ---- payloads ---------------------------------------------------------------
write_renderer() { # write_renderer <path>
  cat > "$1" <<'CVD_RENDERER_EOF'
#!/usr/bin/env bash
# ============================================================================
#  CVD BOT  -  Console VPS Deployment Bot  :  animated login screen
#  Created by Console - https://github.com/console27
#
#  Installed by the CVD BOT MOTD installer. Replay it any time: cvdbot-motd
#  Options: --static (no animation)   --compact | --full   --help
#  Settings: /etc/cvdbot-motd.conf     Press any key during the intro to skip it.
# ============================================================================

# ---- defaults (override in /etc/cvdbot-motd.conf) ---------------------------
CVD_MOTD_ANIM=1            # 1 = animated intro, 0 = instant
CVD_MOTD_STYLE=auto        # auto | full (logo) | compact
CVD_SERVICE=cvdbot         # systemd unit of the bot
CVD_DIR=/opt/cvdbot        # bot checkout (shows the git revision)
CVD_GITHUB="https://github.com/console27"
CVD_DISCORD=""
CVD_WEBSITE=""
CVD_SUPPORT=""
CVD_TRUECOLOR=""           # set to 1 to force 24-bit color
if [ -r /etc/cvdbot-motd.conf ]; then . /etc/cvdbot-motd.conf; fi

usage() {
  cat <<'USAGE'
CVD BOT login screen
  cvdbot-motd [--static] [--compact | --full] [--help]

  --static    no animation          --compact   no logo (narrow terminals)
  --full      force the logo layout  Settings:   /etc/cvdbot-motd.conf
USAGE
}

ANIM="$CVD_MOTD_ANIM"; STYLE="$CVD_MOTD_STYLE"
for arg in "$@"; do
  case "$arg" in
    --static|--no-anim) ANIM=0 ;;
    --compact) STYLE=compact ;;
    --full) STYLE=full ;;
    -h|--help) usage; exit 0 ;;
  esac
done

# ---- terminal capabilities ---------------------------------------------------
IS_TTY=0; [ -t 1 ] && IS_TTY=1
COLOR=$IS_TTY
[ -n "${NO_COLOR:-}" ] && COLOR=0
[ "${TERM:-dumb}" = dumb ] && COLOR=0
TRUECOLOR=0
case "${COLORTERM:-}" in *truecolor*|*24bit*) TRUECOLOR=1 ;; esac
[ "$CVD_TRUECOLOR" = 1 ] && TRUECOLOR=1
UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) UTF8=1 ;; esac
if [ "$IS_TTY" != 1 ] || [ ! -t 0 ] || [ "${BASH_VERSINFO[0]:-3}" -lt 4 ]; then ANIM=0; fi

COLS="${COLUMNS:-}"
if ! [[ "$COLS" =~ ^[0-9]+$ ]]; then
  COLS=""
  if [ -t 0 ]; then read -r _ COLS < <(stty size 2>/dev/null); fi
  [[ "$COLS" =~ ^[0-9]+$ ]] || COLS=80
fi

if [ "$STYLE" = auto ]; then
  if [ "$UTF8" = 1 ] && [ "$COLOR" = 1 ] && [ "$COLS" -ge 78 ]; then STYLE=full; else STYLE=compact; fi
fi
if [ "$STYLE" = full ] && { [ "$UTF8" != 1 ] || [ "$COLOR" != 1 ]; }; then STYLE=compact; fi

# ---- palette & glyphs --------------------------------------------------------
if [ "$COLOR" = 1 ]; then RESET=$'\033[0m'; BOLD=$'\033[1m'; else RESET=; BOLD=; fi
mk() { # mk <VAR> <r> <g> <b> <256-color>
  if [ "$COLOR" != 1 ]; then printf -v "$1" ''
  elif [ "$TRUECOLOR" = 1 ]; then printf -v "$1" '\033[38;2;%s;%s;%sm' "$2" "$3" "$4"
  else printf -v "$1" '\033[38;5;%sm' "$5"; fi
}
mk C_CYAN 0 240 255 51
mk C_VIOLET 150 110 255 141
mk C_GREEN 80 250 123 84
mk C_YELLOW 255 214 10 220
mk C_RED 255 85 85 203
mk C_GRAY 125 138 156 245
mk C_DIM 58 68 84 238

if [ "$UTF8" = 1 ]; then
  G_BAR='━'; G_BAR_OFF='━'; G_DOT='●'; G_HOLLOW='○'; G_RULE='─'; G_SEP='·'; G_STAR='✦'; G_WARN='▲'; G_ELL='…'
  SPIN=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
else
  G_BAR='#'; G_BAR_OFF='.'; G_DOT='*'; G_HOLLOW='-'; G_RULE='-'; G_SEP='|'; G_STAR='*'; G_WARN='!'; G_ELL='~'
  SPIN=("|" "/" "-" "\\")
fi

# ---- layout ------------------------------------------------------------------
LOGO_W=26
if [ "$STYLE" = full ]; then LEFT=30; else LEFT=2; fi
IW=$(( COLS - LEFT )); [ "$IW" -gt 52 ] && IW=52; [ "$IW" -lt 30 ] && IW=30
RW=$IW; [ "$RW" -gt 46 ] && RW=46
printf -v RULE '%*s' "$RW" ''; RULE="${RULE// /$G_RULE}"

# ---- animation helpers -------------------------------------------------------
SKIP=0
nap() { # nap <seconds> : pause, but any key press skips the rest of the intro
  [ "$ANIM" = 1 ] && [ "$SKIP" = 0 ] || return 0
  local k
  if IFS= read -rsn1 -t "$1" k 2>/dev/null; then SKIP=1; fi
  return 0
}

grad() { # grad <index> <count> -> $GC  (cyan -> blue -> violet)
  if [ "$COLOR" != 1 ]; then GC=""; return 0; fi
  local i=$1 n=$2 t r g u idx
  local pal=(51 45 39 33 27 63 99)
  if [ "$n" -le 1 ]; then t=0; else t=$(( i * 100 / (n - 1) )); fi
  if [ "$TRUECOLOR" = 1 ]; then
    if [ "$t" -le 50 ]; then r=$(( 10 * t / 50 )); g=$(( 240 - 132 * t / 50 ))
    else u=$(( t - 50 )); r=$(( 10 + 140 * u / 50 )); g=$(( 108 + 2 * u / 50 )); fi
    printf -v GC '\033[38;2;%s;%s;255m' "$r" "$g"
  else
    idx=$(( t * 6 / 100 )); printf -v GC '\033[38;5;%sm' "${pal[idx]}"
  fi
}

print_title() { # gradient title, typed in
  local t="C V D   B O T" i ch n
  n=${#t}
  for (( i = 0; i < n; i++ )); do
    ch="${t:i:1}"
    if [ "$ch" = " " ]; then printf ' '; continue; fi
    grad "$i" "$n"; printf '%s%s%s' "$BOLD" "$GC" "$ch"; nap 0.025
  done
  printf '%s' "$RESET"
}

bar_run() { # bar_run <percent> : 12-cell bar that fills in
  local pct=$1 w=12 f i col
  f=$(( (pct * w + 50) / 100 ))
  if [ "$pct" -gt 0 ] && [ "$f" -lt 1 ]; then f=1; fi
  [ "$f" -gt "$w" ] && f=$w
  if [ "$pct" -ge 85 ]; then col=$C_RED; elif [ "$pct" -ge 60 ]; then col=$C_YELLOW; else col=$C_GREEN; fi
  printf '%s' "$col"
  for (( i = 0; i < f; i++ )); do printf '%s' "$G_BAR"; nap 0.012; done
  printf '%s' "$C_DIM"
  for (( i = f; i < w; i++ )); do printf '%s' "$G_BAR_OFF"; done
  printf '%s' "$RESET"
}

# ---- system facts (gathered in the background while the spinner runs) -------
TMP="$(mktemp "${TMPDIR:-/tmp}/cvdbot-motd.XXXXXX" 2>/dev/null)" || TMP=""
GPID=""
cleanup() {
  printf '%s' "$RESET"
  [ "$HIDDEN" = 1 ] && printf '\033[?25h'
  [ -n "$GPID" ] && kill "$GPID" 2>/dev/null
  [ -n "$TMP" ] && rm -f "$TMP"
}
HIDDEN=0
trap cleanup EXIT
trap 'exit 130' INT TERM

gather() {
  local host os kernel secs d h m up u1 n1 s1 i1 w1 q1 sq1 st1 u2 n2 s2 i2 w2 q2 sq2 st2
  local idle1 tot1 idle2 tot2 dt di cpu l1 l5 l15 cores mt mu mp dline du ds dp ip sess
  local dstate dcount dout bstate rev
  host="$(hostname 2>/dev/null)"
  os="$(grep -m1 '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')"
  [ -n "$os" ] || os="$(uname -s)"
  kernel="$(uname -r 2>/dev/null)"
  secs=0; if [ -r /proc/uptime ]; then read -r secs _ < /proc/uptime; secs=${secs%.*}; fi
  d=$(( secs / 86400 )); h=$(( secs % 86400 / 3600 )); m=$(( secs % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then up="${d}d ${h}h ${m}m"; elif [ "$h" -gt 0 ]; then up="${h}h ${m}m"; else up="${m}m"; fi

  read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
  sleep 0.25
  read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
  idle1=$(( i1 + w1 )); tot1=$(( u1 + n1 + s1 + i1 + w1 + q1 + sq1 + st1 ))
  idle2=$(( i2 + w2 )); tot2=$(( u2 + n2 + s2 + i2 + w2 + q2 + sq2 + st2 ))
  dt=$(( tot2 - tot1 )); di=$(( idle2 - idle1 ))
  if [ "$dt" -gt 0 ]; then cpu=$(( (100 * (dt - di) + dt / 2) / dt )); else cpu=0; fi
  read -r l1 l5 l15 _ < /proc/loadavg
  cores="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)"

  read -r mt mu < <(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%d %d", t/1024, (t-a)/1024}' /proc/meminfo)
  if [ "${mt:-0}" -gt 0 ]; then mp=$(( mu * 100 / mt )); else mp=0; fi
  dline="$(df -Ph / 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  read -r du ds dp <<< "$dline"; dp="${dp%\%}"

  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$ip" ] || ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
  sess="$(who 2>/dev/null | wc -l)"

  dstate=missing; dcount=""
  if command -v docker >/dev/null 2>&1; then
    if command -v systemctl >/dev/null 2>&1; then dstate="$(systemctl is-active docker 2>/dev/null || true)"; else dstate=active; fi
    [ -n "$dstate" ] || dstate=unknown
    if dout="$(timeout 3 docker ps -q 2>/dev/null)"; then dcount="$(printf '%s\n' "$dout" | grep -c . || true)"; fi
  fi
  bstate=missing; rev=""
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files "${CVD_SERVICE}.service" --no-legend 2>/dev/null | grep -q .; then
    bstate="$(systemctl is-active "$CVD_SERVICE" 2>/dev/null || true)"; [ -n "$bstate" ] || bstate=unknown
  fi
  if [ -d "$CVD_DIR/.git" ] && command -v git >/dev/null 2>&1; then
    rev="$(git -c safe.directory="$CVD_DIR" -C "$CVD_DIR" rev-parse --short HEAD 2>/dev/null)"
  fi
  {
    printf 'G_HOST=%q\nG_OS=%q\nG_KERNEL=%q\nG_UP=%q\n' "$host" "$os" "$kernel" "$up"
    printf 'G_CPU=%q\nG_L1=%q\nG_L5=%q\nG_L15=%q\nG_CORES=%q\n' "$cpu" "$l1" "$l5" "$l15" "$cores"
    printf 'G_MEMT=%q\nG_MEMU=%q\nG_MEMP=%q\n' "$mt" "$mu" "$mp"
    printf 'G_DISKU=%q\nG_DISKS=%q\nG_DISKP=%q\n' "$du" "$ds" "$dp"
    printf 'G_IP=%q\nG_SESS=%q\nG_DOCKER=%q\nG_DCOUNT=%q\nG_BOT=%q\nG_REV=%q\n' "$ip" "$sess" "$dstate" "$dcount" "$bstate" "$rev"
  } > "$TMP"
}

spinner() { # spinner <pid> : animated while the facts are collected
  local i=0 n=${#SPIN[@]} min=6
  if [ "$ANIM" != 1 ] || [ "$COLOR" != 1 ]; then wait "$1" 2>/dev/null; return 0; fi
  while kill -0 "$1" 2>/dev/null || [ "$i" -lt "$min" ]; do
    printf '\r %s%s%s %sScanning your VPS%s %s(any key skips the intro)%s' \
      "$C_CYAN" "${SPIN[i % n]}" "$RESET" "$RESET" "$C_GRAY" "$C_DIM" "$RESET"
    i=$(( i + 1 )); nap 0.08
    if [ "$SKIP" = 1 ]; then wait "$1" 2>/dev/null; break; fi
    [ "$i" -gt 50 ] && break
  done
  printf '\r\033[K'
}

# ---- logo (pixel art, rendered with half-block characters) -------------------
LOGO=(
  "............BB............"
  "...........BBBB..........."
  "...........BBBB..........."
  "...........BBBB..........."
  "............BB............"
  "............NN............"
  "............NN............"
  ".......NNNNNNNNNNNN......."
  ".....NNNNNNNNNNNNNNNN....."
  "....NNNWWWWWWWWWWWWNNN...."
  "....NNWWWWWWWWWWWWWWNN...."
  "...NNWWNNNNNNNNNNNNWWNN..."
  ".NNNNWWNNNNNNNNNNNNWWNNNN."
  ".NNNNWWNNWWNNNNWWNNWWNNNN."
  ".NNNNWWNNWWNNNNWWNNWWNNNN."
  ".NNNNWWNNWWNNNNWWNNWWNNNN."
  ".NNNNWWNNNNNNNNNNNNWWNNNN."
  "..NNNWWNNNNNNNNNNNNWWNNN.."
  "...NNWWWWWWWWWWWWWWWWNN..."
  ".....NNWWWWWWWWWWWWNN....."
  ".........................."
  "..NNNNNNNNNNNNNNNNNNCCC..."
  ".NNNNNNNNNNNNNNNNNNCCNNN.."
  "NNNCCNCCNNWWWWWWNNNN....N."
  "NNNCCNCCNNWWWWWWNNN..BB..."
  "NNNNNNNNNNNNNNNNNN..BBBB.."
  ".NNNNNNNNNNNNNNNN..BBBBBB."
  "..NNNNNNNNNNNNNN..BBBBBBBB"
  ".................BBBBBBBBB"
  "..NNNNNNNNNNNNNN.BBBBBBBBB"
  ".NNNNNNNNNNNNNNN....BBBB.."
  "NNNCCNCCNNWWWWWWNNN.BBBB.."
  "NNNCCNCCNNWWWWWWNNN.BBBB.."
  "NNNNNNNNNNNNNNNNNNN.BBBB.."
  ".NNNNNNNNNNNNNNNNNN.BBBB.."
  "..NNNNNNNNNNNNNNNNN.BBBB.."
)
LOGO_ROW=()
px_code() { # px_code <letter> <38|48> -> $PX
  local r g b n
  case "$1" in
    N) r=44;  g=78;  b=140; n=61 ;;
    W) r=240; g=247; b=255; n=231 ;;
    B) r=10;  g=108; b=255; n=27 ;;
    C) r=0;   g=240; b=255; n=51 ;;
  esac
  if [ "$TRUECOLOR" = 1 ]; then printf -v PX '\033[%s;2;%s;%s;%sm' "$2" "$r" "$g" "$b"
  else printf -v PX '\033[%s;5;%sm' "$2" "$n"; fi
}
build_logo() {
  local L r c t b line v w n=${#LOGO[@]}
  for L in N W B C; do
    px_code "$L" 38; printf -v "FG_$L" '%s' "$PX"
    px_code "$L" 48; printf -v "BG_$L" '%s' "$PX"
  done
  for (( r = 0; r < n; r += 2 )); do
    line=""
    for (( c = 0; c < LOGO_W; c++ )); do
      t="${LOGO[r]:c:1}"; b="${LOGO[r+1]:c:1}"
      if [ "$t" = . ] && [ "$b" = . ]; then line+="${RESET} "
      elif [ "$t" = . ]; then v="FG_$b"; line+="${RESET}${!v}▄"
      elif [ "$b" = . ]; then v="FG_$t"; line+="${RESET}${!v}▀"
      else v="FG_$t"; w="BG_$b"; line+="${RESET}${!v}${!w}▀"; fi
    done
    LOGO_ROW[r / 2]="${line}${RESET}"
  done
}

# ---- rows --------------------------------------------------------------------
clip() { # clip <string> <max>
  local s="$1" m="$2"
  if [ "${#s}" -gt "$m" ]; then s="${s:0:$(( m - 1 ))}${G_ELL}"; fi
  printf '%s' "$s"
}
lbl() { printf '%s%-9s%s' "$C_GRAY" "$1" "$RESET"; }
mb_h() { # megabytes -> 1.2G / 512M
  local m=$1 t
  if [ "$m" -ge 1024 ]; then t=$(( m * 10 / 1024 )); printf '%s.%sG' "$(( t / 10 ))" "$(( t % 10 ))"; else printf '%sM' "$m"; fi
}
state_row() { # state_row <state> <extra>
  local st=$1 extra=$2
  case "$st" in
    active)  printf '%s%s%s running' "$C_GREEN" "$G_DOT" "$RESET"
             if [ -n "$extra" ]; then printf ' %s%s %s%s' "$C_GRAY" "$G_SEP" "$extra" "$RESET"; fi ;;
    missing) printf '%s%s not installed%s' "$C_GRAY" "$G_HOLLOW" "$RESET" ;;
    inactive) printf '%s%s%s stopped' "$C_YELLOW" "$G_DOT" "$RESET" ;;
    *)       printf '%s%s%s %s' "$C_RED" "$G_DOT" "$RESET" "$st" ;;
  esac
}

info_row() {
  local plural=s cp=cores sp=sessions
  [ "${G_CORES:-}" = 1 ] && cp=core
  [ "${G_SESS:-}" = 1 ] && sp=session
  case "$1" in
    1) print_title ;;
    2) printf '%sConsole VPS Deployment Bot%s' "$C_GRAY" "$RESET" ;;
    3|15) printf '%s%s%s' "$C_DIM" "$RULE" "$RESET" ;;
    4) lbl Host;   clip "${G_HOST:-?}" $(( IW - 9 )) ;;
    5) lbl OS;     clip "${G_OS:-?}" $(( IW - 9 )) ;;
    6) lbl Kernel; clip "${G_KERNEL:-?}" $(( IW - 9 )) ;;
    7) lbl Uptime; clip "${G_UP:-?}" $(( IW - 9 )) ;;
    8) lbl CPU;    bar_run "$G_CPU"; printf ' %3s%%' "$G_CPU" ;;
    9) lbl Memory; bar_run "$G_MEMP"; printf ' %s / %s' "$(mb_h "$G_MEMU")" "$(mb_h "$G_MEMT")" ;;
    10) lbl Disk;  bar_run "$G_DISKP"; printf ' %s / %s' "$G_DISKU" "$G_DISKS" ;;
    11) lbl Load;  printf '%s %s %s %s(%s %s)%s' "$G_L1" "$G_L5" "$G_L15" "$C_GRAY" "$G_CORES" "$cp" "$RESET" ;;
    12) lbl IP;    printf '%s' "${G_IP:--}"
        printf ' %s%s %s %s%s' "$C_GRAY" "$G_SEP" "$G_SESS" "$sp" "$RESET" ;;
    13) lbl Docker
        [ "$G_DCOUNT" = 1 ] && plural=""
        state_row "$G_DOCKER" "${G_DCOUNT:+$G_DCOUNT container$plural}" ;;
    14) lbl Bot;   state_row "$G_BOT" "$G_REV" ;;
    16) if [ "$HEALTH" = ok ]; then printf '%s%s%s All systems operational' "$C_GREEN" "$G_DOT" "$RESET"
        else printf '%s%s%s %s' "$C_YELLOW" "$G_WARN" "$RESET" "$(clip "Attention: $HEALTH_MSG" $(( IW - 2 )))"; fi ;;
  esac
}

compute_health() {
  local -a issues=()
  : "${G_CPU:=0}" "${G_MEMP:=0}" "${G_DISKP:=0}" "${G_MEMT:=0}" "${G_MEMU:=0}" "${G_DOCKER:=missing}" "${G_BOT:=missing}"
  [ "$G_DISKP" -ge 90 ] 2>/dev/null && issues+=("disk ${G_DISKP}%")
  [ "$G_MEMP" -ge 90 ] 2>/dev/null && issues+=("memory ${G_MEMP}%")
  [ "$G_CPU" -ge 95 ] 2>/dev/null && issues+=("cpu ${G_CPU}%")
  case "$G_BOT" in active|missing) ;; *) issues+=("bot ${G_BOT}") ;; esac
  case "$G_DOCKER" in active|missing) ;; *) issues+=("docker ${G_DOCKER}") ;; esac
  local it; HEALTH_MSG=""
  for it in "${issues[@]}"; do HEALTH_MSG="${HEALTH_MSG:+$HEALTH_MSG, }$it"; done
  if [ -z "$HEALTH_MSG" ]; then HEALTH=ok; else HEALTH=warn; fi
}

footer() {
  local h greet user d
  h="$(date +%H 2>/dev/null)"; h=$(( 10#${h:-12} ))
  if [ "$h" -lt 12 ]; then greet="Good morning"; elif [ "$h" -lt 18 ]; then greet="Good afternoon"; else greet="Good evening"; fi
  user="${USER:-$(id -un 2>/dev/null)}"
  d="$(date '+%a %d %b %Y  %H:%M %Z' 2>/dev/null)"
  printf '\n'
  printf ' %s%s%s %s%s, %s%s   %s%s%s\n' "$C_CYAN" "$G_STAR" "$RESET" "$BOLD" "$greet" "$user" "$RESET" "$C_GRAY" "$d" "$RESET"; nap 0.04
  link() { [ -n "$2" ] || return 0; printf '   %s%-9s%s%s%s%s\n' "$C_GRAY" "$1" "$RESET" "$C_CYAN" "$2" "$RESET"; nap 0.04; }
  link GitHub "$CVD_GITHUB"; link Discord "$CVD_DISCORD"; link Website "$CVD_WEBSITE"; link Support "$CVD_SUPPORT"
  printf ' %s%s%s %sCVD BOT %s Created by %sConsole%s\n' "$C_VIOLET" "$G_STAR" "$RESET" "$C_GRAY" "$G_SEP" "$BOLD" "$RESET"
  printf '\n'
}

# ---- main --------------------------------------------------------------------
main() {
  if [ -z "$TMP" ]; then TMP="/tmp/cvdbot-motd.$$"; fi
  if [ "$ANIM" = 1 ] && [ "$COLOR" = 1 ]; then HIDDEN=1; printf '\033[?25l'; fi
  gather & GPID=$!
  if [ "$STYLE" = full ]; then build_logo; fi
  spinner "$GPID"
  wait "$GPID" 2>/dev/null; GPID=""
  # shellcheck disable=SC1090
  [ -s "$TMP" ] && . "$TMP"
  compute_health

  printf '\n'
  local r first=0 last=17
  if [ "$STYLE" = full ]; then
    for (( r = first; r <= last; r++ )); do
      printf ' %s   ' "${LOGO_ROW[r]}"; info_row "$r"; printf '%s\n' "$RESET"; nap 0.035
    done
  else
    for (( r = 1; r <= 16; r++ )); do
      printf '  '; info_row "$r"; printf '%s\n' "$RESET"; nap 0.03
    done
  fi
  footer
}
main
CVD_RENDERER_EOF
}

write_stub() {
  cat > "$STUB" <<'CVD_STUB_EOF'
# CVD BOT login screen - installed by the CVD BOT MOTD installer.
# Shown once per interactive login shell; never for scp/sftp or ssh commands.
case "$-" in *i*) ;; *) return 0 2>/dev/null ;; esac
if [ ! -t 0 ] || [ ! -t 1 ]; then return 0; fi
if [ -n "${CVDBOT_MOTD_SHOWN:-}" ] || [ -e "${HOME:-/nonexistent}/.hushlogin" ]; then return 0; fi
if [ ! -x /usr/local/bin/cvdbot-motd ]; then return 0; fi
CVDBOT_MOTD_SHOWN=1; export CVDBOT_MOTD_SHOWN
/usr/local/bin/cvdbot-motd
CVD_STUB_EOF
  chmod 644 "$STUB"
}

write_conf() {
  cat > "$CONF" <<'CVD_CONF_EOF'
# CVD BOT login screen settings. Edit, then reconnect (or run: cvdbot-motd)
CVD_MOTD_ANIM=1          # 1 = animated intro, 0 = instant
CVD_MOTD_STYLE=auto      # auto | full (logo) | compact
CVD_SERVICE=cvdbot       # systemd unit of the bot
CVD_DIR=/opt/cvdbot      # bot checkout (its git revision is shown)
CVD_GITHUB="https://github.com/console27"
CVD_DISCORD=""           # shown when set
CVD_WEBSITE=""           # shown when set
CVD_SUPPORT=""           # shown when set
CVD_CONF_EOF
  chmod 644 "$CONF"
}

# ---- default MOTD (reversible) ----------------------------------------------
disable_default_motd() {
  local f
  for f in /etc/pam.d/sshd /etc/pam.d/login; do
    [[ -f "$f" ]] || continue
    if grep -Eq '^[[:space:]]*session[[:space:]].*pam_motd\.so' "$f"; then
      [[ -e "$f.cvdbot.bak" ]] || cp -p "$f" "$f.cvdbot.bak"
      sed -i -E "s|^([[:space:]]*session[[:space:]].*pam_motd\.so.*)\$|${MARK}\1|" "$f"
      ok "turned off the default MOTD in $f (backup: $f.cvdbot.bak)"
    else
      ok "default MOTD already off in $f"
    fi
  done
  if [[ -f /etc/motd && ! -L /etc/motd && -s /etc/motd ]]; then
    [[ -e /etc/motd.cvdbot.bak ]] || cp -p /etc/motd /etc/motd.cvdbot.bak
    : > /etc/motd
    ok "emptied /etc/motd (backup: /etc/motd.cvdbot.bak)"
  fi
}

restore_default_motd() {
  local f
  for f in /etc/pam.d/sshd /etc/pam.d/login; do
    [[ -f "$f" ]] || continue
    if grep -q "^${MARK}" "$f"; then
      sed -i "s|^${MARK}||" "$f"
      ok "restored the default MOTD in $f"
    fi
    rm -f "$f.cvdbot.bak"
  done
  if [[ -f /etc/motd.cvdbot.bak ]]; then
    cp -p /etc/motd.cvdbot.bak /etc/motd && rm -f /etc/motd.cvdbot.bak
    ok "restored /etc/motd"
  fi
}

# ---- actions ----------------------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || die "run as root:  sudo bash $0 ${1:-}"; }

install_all() {
  need_root
  banner
  if (( BASH_VERSINFO[0] < 4 )); then warn "bash 4+ is needed for the animation; it will be skipped"; fi
  step "Installing the CVD BOT login screen"
  mkdir -p "$(dirname "$STUB")"
  write_renderer "$BIN.new"; chmod 755 "$BIN.new"; mv -f "$BIN.new" "$BIN"
  ok "installed $BIN"
  write_stub
  ok "installed the login hook $STUB"
  if [[ -e "$CONF" ]]; then ok "keeping your settings in $CONF"; else write_conf; ok "created $CONF"; fi

  if [[ "${KEEP_DEFAULT_MOTD:-0}" == "1" ]]; then
    warn "keeping the default MOTD (KEEP_DEFAULT_MOTD=1)"
  else
    step "Turning off the default MOTD"
    disable_default_motd
  fi

  step "Done"
  printf '    %sReconnect over SSH to see it live%s - no service restart needed.\n' "$BOLD" "$NC"
  printf '    %sReplay:%s cvdbot-motd    %sSettings:%s %s\n' "$C_MUT" "$NC" "$C_MUT" "$NC" "$CONF"
  printf '    %sRemove:%s  bash %s --uninstall\n' "$C_MUT" "$NC" "$(basename "$0")"
  if [[ -t 1 ]]; then
    step "Preview"
    "$BIN" || true
  fi
}

uninstall_all() {
  need_root "--uninstall"
  banner
  step "Removing the CVD BOT login screen"
  rm -f "$BIN" "$STUB"; ok "removed $BIN and $STUB"
  restore_default_motd
  if [[ "${1:-}" == "purge" ]]; then rm -f "$CONF"; ok "deleted $CONF"; else ok "kept $CONF (use --purge to delete it)"; fi
  printf '\n    %sThe default MOTD is back from your next login.%s\n\n' "$BOLD" "$NC"
}

preview() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/cvdbot-motd-preview.XXXXXX")"
  write_renderer "$tmp"
  bash "$tmp" || true
  rm -f "$tmp"
}

case "${1:-}" in
  ""|--install)   install_all ;;
  --preview)      preview ;;
  --uninstall)    uninstall_all ;;
  --purge)        uninstall_all purge ;;
  -h|--help)      usage ;;
  *) die "unknown option '$1' (use --help)" ;;
esac
