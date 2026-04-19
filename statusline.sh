#!/bin/bash
input=$(cat)

# ── ANSI helpers ────────────────────────────────────────────────────────────
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'

# 256-colour foreground
c()  { printf '\033[38;5;%sm' "$1"; }
# 256-colour background
bg() { printf '\033[48;5;%sm' "$1"; }

# Palette
CYAN=$(c 51)
MAGENTA=$(c 213)
WHITE=$(c 255)
YELLOW=$(c 220)
ORANGE=$(c 208)
RED=$(c 196)
GREEN=$(c 82)
BLUE=$(c 75)
GREY=$(c 240)
SILVER=$(c 250)
GOLD=$(c 214)
PURPLE=$(c 135)

# ── Visible-length helper (strips ANSI escape codes) ─────────────────────────

# ── Working directory ─────────────────────────────────────────────────────────
RAW_CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
# Fall back to shell cwd if JSON gave us nothing
[ -z "$RAW_CWD" ] && RAW_CWD=$(pwd)

# Replace $HOME prefix with ~
SHORT_CWD="${RAW_CWD/#$HOME/~}"

# Truncate to last 2 path components if more than 2 deep (after ~ substitution)
# Count components by stripping leading ~ or /
_stripped="${SHORT_CWD#\~}"   # remove leading ~
_stripped="${_stripped#/}"    # remove leading /
_count=$(echo "$_stripped" | awk -F'/' '{print NF}')
if [ "$_count" -gt 2 ]; then
  _last2=$(echo "$_stripped" | awk -F'/' '{print $(NF-1)"/"$NF}')
  SHORT_CWD="…/${_last2}"
fi

# Directory: warm pink/rose — visually distinct from branch
CWD_SEG=$(printf "${bold}$(c 204)${SHORT_CWD}${reset}")

# ── Git branch + status ──────────────────────────────────────────────────────
GIT_BRANCH=$(git --git-dir="$RAW_CWD/.git" --work-tree="$RAW_CWD" branch --show-current 2>/dev/null)
GIT_SEG=""
if [ -n "$GIT_BRANCH" ]; then
  GIT_SEG=$(printf "${bold}$(c 51)⎇${reset} ${bold}$(c 117)${GIT_BRANCH}${reset}")

  # Dirty: count staged + unstaged changed files (not untracked)
  DIRTY=$(git --git-dir="$RAW_CWD/.git" --work-tree="$RAW_CWD" status --porcelain 2>/dev/null | grep -c '^[^?]')
  if [ "$DIRTY" -gt 0 ]; then
    GIT_SEG="${GIT_SEG} ${bold}$(c 208)✎${DIRTY}${reset}"
  fi

  # Ahead/behind remote
  UPSTREAM=$(git --git-dir="$RAW_CWD/.git" --work-tree="$RAW_CWD" rev-parse --abbrev-ref "@{u}" 2>/dev/null)
  if [ -n "$UPSTREAM" ]; then
    AHEAD=$(git --git-dir="$RAW_CWD/.git" --work-tree="$RAW_CWD" rev-list --count "@{u}..HEAD" 2>/dev/null)
    BEHIND=$(git --git-dir="$RAW_CWD/.git" --work-tree="$RAW_CWD" rev-list --count "HEAD..@{u}" 2>/dev/null)
    [ "${AHEAD:-0}" -gt 0 ]  && GIT_SEG="${GIT_SEG} ${bold}$(c 82)↑${AHEAD}${reset}"
    [ "${BEHIND:-0}" -gt 0 ] && GIT_SEG="${GIT_SEG} ${bold}$(c 196)↓${BEHIND}${reset}"
  fi
fi

# ── Model name ───────────────────────────────────────────────────────────────
MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

if [ -n "$EFFORT" ]; then
  MODEL_COLORED=$(printf "${bold}${CYAN}${MODEL}${reset}${GREY} · ${reset}${bold}${SILVER}${EFFORT}${reset}")
else
  MODEL_COLORED=$(printf "${bold}${CYAN}${MODEL}${reset}")
fi

# ── Context bar ─────────────────────────────────────────────────────────────
PCT_RAW=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
PCT=$(printf '%.0f' "$PCT_RAW")

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))

# Full spectrum gradient: green → chartreuse → yellow → amber → orange → red → deep red
BAR_COLORED=""
for i in $(seq 1 $BAR_WIDTH); do
  if [ "$i" -le "$FILLED" ]; then
    if   [ "$i" -le 1  ]; then COL=$(c 46)   # bright green
    elif [ "$i" -le 2  ]; then COL=$(c 82)   # lime
    elif [ "$i" -le 3  ]; then COL=$(c 118)  # chartreuse
    elif [ "$i" -le 4  ]; then COL=$(c 154)  # yellow-green
    elif [ "$i" -le 5  ]; then COL=$(c 220)  # yellow
    elif [ "$i" -le 6  ]; then COL=$(c 214)  # amber
    elif [ "$i" -le 7  ]; then COL=$(c 208)  # orange
    elif [ "$i" -le 8  ]; then COL=$(c 202)  # dark orange
    elif [ "$i" -le 9  ]; then COL=$(c 196)  # red
    else                        COL=$(c 160)  # deep red
    fi
    BAR_COLORED="${BAR_COLORED}${COL}${bold}■${reset}"
  else
    BAR_COLORED="${BAR_COLORED}${GREY}□${reset}"
  fi
done

# Colour the percentage itself: green < 50, yellow 50-74, orange 75-89, red 90+
if   [ "$PCT" -lt 50 ]; then PCT_COL=$GREEN
elif [ "$PCT" -lt 75 ]; then PCT_COL=$YELLOW
elif [ "$PCT" -lt 90 ]; then PCT_COL=$ORANGE
else                          PCT_COL=$RED
fi
PCT_COLORED=$(printf "${bold}${PCT_COL}%3d%%${reset}" "$PCT")

# ── Rate limits ──────────────────────────────────────────────────────────────
FIVE_H=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage  // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage  // empty')

# Mini bar helper: draws a 10-cell filled/empty bar
rate_bar() {
  local pct="$1"
  local width=10
  local filled=$((pct * width / 100))
  local bar=""
  local col
  if   [ "$pct" -lt 50 ]; then col=$(c 82)    # green
  elif [ "$pct" -lt 75 ]; then col=$(c 220)   # yellow
  else                          col=$(c 208)   # amber/orange
  fi
  for i in $(seq 1 $width); do
    if [ "$i" -le "$filled" ]; then
      bar="${bar}${col}▪${reset}"
    else
      bar="${bar}${GREY}·${reset}"
    fi
  done
  printf "%s" "$bar"
}

RATE_STR=""
if [ -n "$FIVE_H" ]; then
  FH_USED=$(printf '%.0f' "$FIVE_H")
  FH_INT=$((100 - FH_USED))
  if   [ "$FH_INT" -gt 60 ]; then FH_COL=$(c 82);  FH_ICOL=$(c 82)
  elif [ "$FH_INT" -gt 40 ]; then FH_COL=$(c 154); FH_ICOL=$(c 154)
  elif [ "$FH_INT" -gt 25 ]; then FH_COL=$YELLOW;  FH_ICOL=$YELLOW
  elif [ "$FH_INT" -gt 10 ]; then FH_COL=$ORANGE;  FH_ICOL=$ORANGE
  else                             FH_COL=$RED;     FH_ICOL=$RED
  fi
  FH_BAR=""
  FH_FILLED=$((FH_INT * 10 / 100))
  for _i in $(seq 1 10); do
    if [ "$_i" -le "$FH_FILLED" ]; then FH_BAR="${FH_BAR}${FH_ICOL}▮${reset}"
    else                                  FH_BAR="${FH_BAR}${GREY}▯${reset}"
    fi
  done
  if   [ "$FH_INT" -gt 75 ]; then FH_SYM="●"
  elif [ "$FH_INT" -gt 50 ]; then FH_SYM="◕"
  elif [ "$FH_INT" -gt 25 ]; then FH_SYM="◑"
  elif [ "$FH_INT" -gt 0  ]; then FH_SYM="◔"
  else                             FH_SYM="○"
  fi
  FH_ICON=$(printf "${FH_ICOL}${FH_SYM}${reset}")
  FH_SEG=$(printf "${FH_ICON} ${bold}$(c 250)5h${reset} ${FH_BAR} ${bold}${FH_COL}${FH_INT}%%${reset}")
fi

# ── Reset countdowns ─────────────────────────────────────────────────────────
MUTED_CYAN=$(c 73)

fmt_reset() {
  local ts="$1"
  python3 -c "
import time
diff = int($ts) - int(time.time())
if diff > 0:
    d = diff // 86400
    h = (diff % 86400) // 3600
    m = (diff % 3600) // 60
    if d > 0:
        print(f'{d}d {h}h')
    else:
        print(f'{h}h {m}m')
" 2>/dev/null
}

# Attach 5h reset inline to 5h segment
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RATE_STR=""
if [ -n "$FH_SEG" ]; then
  RATE_STR="$FH_SEG"
  if [ -n "$FIVE_H_RESET" ]; then
    R=$(fmt_reset "$FIVE_H_RESET")
    [ -n "$R" ] && RATE_STR="${RATE_STR} $(c 244)⏱${reset} ${bold}${MUTED_CYAN}${R}${reset}"
  fi
fi

# Build 7d segment and attach its reset inline
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
if [ -n "$SEVEN_D" ]; then
  SD_USED=$(printf '%.0f' "$SEVEN_D")
  SD_INT=$((100 - SD_USED))
  if   [ "$SD_INT" -gt 60 ]; then SD_COL=$(c 82);  SD_ICOL=$(c 82)
  elif [ "$SD_INT" -gt 40 ]; then SD_COL=$(c 154); SD_ICOL=$(c 154)
  elif [ "$SD_INT" -gt 25 ]; then SD_COL=$YELLOW;  SD_ICOL=$YELLOW
  elif [ "$SD_INT" -gt 10 ]; then SD_COL=$ORANGE;  SD_ICOL=$ORANGE
  else                             SD_COL=$RED;     SD_ICOL=$RED
  fi
  SD_BAR=""
  SD_FILLED=$((SD_INT * 10 / 100))
  for _i in $(seq 1 10); do
    if [ "$_i" -le "$SD_FILLED" ]; then SD_BAR="${SD_BAR}${SD_ICOL}▮${reset}"
    else                                 SD_BAR="${SD_BAR}${GREY}▯${reset}"
    fi
  done
  if   [ "$SD_INT" -gt 75 ]; then SD_SYM="●"
  elif [ "$SD_INT" -gt 50 ]; then SD_SYM="◕"
  elif [ "$SD_INT" -gt 25 ]; then SD_SYM="◑"
  elif [ "$SD_INT" -gt 0  ]; then SD_SYM="◔"
  else                             SD_SYM="○"
  fi
  SD_ICON=$(printf "${SD_ICOL}${SD_SYM}${reset}")
  SD_SEG=$(printf "${SD_ICON} ${bold}$(c 250)7d${reset} ${SD_BAR} ${bold}${SD_COL}${SD_INT}%%${reset}")
  if [ -n "$SEVEN_D_RESET" ]; then
    R=$(fmt_reset "$SEVEN_D_RESET")
    [ -n "$R" ] && SD_SEG="${SD_SEG} $(c 244)⏱${reset} ${bold}${MUTED_CYAN}${R}${reset}"
  fi
fi

# ── Token counts ─────────────────────────────────────────────────────────────
TOT_IN=$(echo "$input"  | jq -r '.context_window.total_input_tokens  // 0')
TOT_OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Format with k suffix when >= 1000
fmt_tok() {
  local n="$1"
  if [ "$n" -ge 1000 ]; then
    python3 -c "print(f'{$n/1000:.1f}k')" 2>/dev/null || echo "${n}"
  else
    echo "$n"
  fi
}

TOK_SEG=""
if [ "$TOT_IN" -gt 0 ] || [ "$TOT_OUT" -gt 0 ]; then
  IN_FMT=$(fmt_tok "$TOT_IN")
  OUT_FMT=$(fmt_tok "$TOT_OUT")
  # ⬇ in / ⬆ out as directional icons to distinguish at a glance
  TOK_SEG=$(printf "$(c 244)⬇ ${reset}${bold}${BLUE}${IN_FMT}${reset} $(c 244)⬆ ${reset}${bold}${MAGENTA}${OUT_FMT}${reset}")
fi

# ── Separators ───────────────────────────────────────────────────────────────
SEP=$(printf "${GREY} │ ${reset}")
# Chevron-style separator used between model·effort and location on line 2
SEP2=$(printf " $(c 238)∷${reset} ")

# ── Assemble line bodies (no labels) ─────────────────────────────────────────
# Line 1 — context bar + token counts
LINE1="${bold}${PCT_COL}❮${reset}${BAR_COLORED}${bold}${PCT_COL}❯${reset}  ${PCT_COLORED}"
[ -n "$TOK_SEG" ] && LINE1="${LINE1}  ${TOK_SEG}"

# Line 2 — model · effort  ⟫  directory  ⎇ branch
LOC_SEG="${CWD_SEG}"
[ -n "$GIT_SEG" ] && LOC_SEG="${LOC_SEG}  ${GIT_SEG}"
LINE2="${MODEL_COLORED}${SEP2}${LOC_SEG}"

# Line 3 — 5h rate limit
LINE3="${RATE_STR}"

# Line 4 — 7d rate limit
LINE4="${SD_SEG}"

if [ -n "$LINE3" ] && [ -n "$LINE4" ]; then
  printf "%b\n%b\n%b\n%b\n" "$LINE1" "$LINE2" "$LINE3" "$LINE4"
elif [ -n "$LINE3" ]; then
  printf "%b\n%b\n%b\n" "$LINE1" "$LINE2" "$LINE3"
else
  printf "%b\n%b\n" "$LINE1" "$LINE2"
fi
