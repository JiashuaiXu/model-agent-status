#!/usr/bin/env bash
# model-agent-status: GitCode model/agent statusline for Claude Code.
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    printf "Claude %b|%b jq missing" '\033[2m' '\033[0m'
    exit 0
fi

blue='\033[38;2;88;166;255m'
green='\033[38;2;81;207;102m'
teal='\033[38;2;63;199;178m'
yellow='\033[38;2;235;190;80m'
orange='\033[38;2;255;166;87m'
red='\033[38;2;255;91;91m'
white='\033[38;2;220;225;230m'
dim='\033[2m'
reset='\033[0m'
sep=" ${dim}│${reset} "

cache_dir="${MODEL_AGENT_STATUS_CACHE_DIR:-/tmp/claude/model-agent-status}"
cookie_file="${GITCODE_COOKIE_FILE:-$HOME/.claude/.gitcode_session_cookie}"
usage_url="${GITCODE_TOKEN_USAGE_URL:-https://web-api.gitcode.com/widget/api/v1/token_usage}"
agent_url="${GITCODE_AGENT_DETAIL_URL:-https://web-api.gitcode.com/aihub/api/v1/mo-fix-agent/detail}"
cache_ttl="${MODEL_AGENT_STATUS_CACHE_TTL:-60}"
mkdir -p "$cache_dir" 2>/dev/null

json_get() {
    printf '%s' "$input" | jq -r "$1" 2>/dev/null
}

safe_int() {
    local value="${1:-}" fallback="${2:-0}"
    value="${value%%.*}"
    case "$value" in
        ""|null|*[!0-9-]*) printf "%s" "$fallback" ;;
        *) printf "%s" "$value" ;;
    esac
}

json_int() {
    safe_int "$(json_get "$1")" "${2:-0}"
}

color_for_pct() {
    local pct="${1:-0}"
    if [ "$pct" -ge 95 ] 2>/dev/null; then printf "$red"
    elif [ "$pct" -ge 80 ] 2>/dev/null; then printf "$orange"
    elif [ "$pct" -ge 60 ] 2>/dev/null; then printf "$yellow"
    else printf "$green"
    fi
}

bar() {
    local pct="${1:-0}" width="${2:-8}"
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local color filled_s="" empty_s=""
    color=$(color_for_pct "$pct")
    for ((i=0; i<filled; i++)); do filled_s+="●"; done
    for ((i=0; i<empty; i++)); do empty_s+="○"; done
    printf "%b%s%b%s%b" "$color" "$filled_s" "$dim" "$empty_s" "$reset"
}

duration() {
    local seconds="${1:-0}"
    [ "$seconds" -lt 0 ] 2>/dev/null && seconds=0
    if [ "$seconds" -ge 3600 ]; then
        printf "%dh%02dm" "$((seconds / 3600))" "$(((seconds % 3600) / 60))"
    elif [ "$seconds" -ge 60 ]; then
        printf "%dm" "$((seconds / 60))"
    else
        printf "%ds" "$seconds"
    fi
}

human_int() {
    awk -v n="${1:-0}" 'BEGIN {
        if (n >= 1000000000) printf "%.1fB", n / 1000000000;
        else if (n >= 1000000) printf "%.1fM", n / 1000000;
        else if (n >= 1000) printf "%.1fk", n / 1000;
        else printf "%d", n;
    }'
}

iso_to_epoch() {
    local value="$1"
    [ -z "$value" ] || [ "$value" = "null" ] && return 1
    date -d "$value" +%s 2>/dev/null && return 0
    local stripped="${value%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    date -d "${stripped/T/ }" +%s 2>/dev/null
}

time_label() {
    local iso="$1" epoch label
    epoch=$(iso_to_epoch "$iso") || return 0
    label=$(date -d "@$epoch" +"%H:%M" 2>/dev/null)
    printf "%s" "$label"
}

cache_fresh() {
    local file="$1"
    [ -f "$file" ] || return 1
    local mtime now age
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null) || return 1
    now=$(date +%s)
    age=$((now - mtime))
    [ "$age" -lt "$cache_ttl" ]
}

read_cookie() {
    [ -f "$cookie_file" ] || return 1
    sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$cookie_file" | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

fetch_gitcode() {
    local name="$1"
    local url="$2"
    local cache_file="$cache_dir/$name.json"
    if cache_fresh "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    local cookie response
    cookie=$(read_cookie) || return 1
    response=$(curl -fsS --max-time 5 \
        -H "Accept: application/json, text/plain, */*" \
        -H "Referer: https://ai.gitcode.com/" \
        -H "Origin: https://ai.gitcode.com" \
        -H "x-app-channel: gitcode-fe" \
        -H "x-app-version: 0" \
        -H "x-platform: web" \
        -H "Cookie: $cookie" \
        "$url" 2>/dev/null) || return 1

    if printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
        printf '%s' "$response" >"$cache_file"
        printf '%s' "$response"
        return 0
    fi
    return 1
}

model=$(json_get '.model.display_name // .model.name // "Claude"')
[ -z "$model" ] || [ "$model" = "null" ] && model="Claude"
cwd=$(json_get '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
dir=$(basename "$cwd")

size=$(json_int '.context_window.context_window_size // 200000' 200000)
[ "$size" -eq 0 ] 2>/dev/null && size=200000
input_tokens=$(json_int '.context_window.current_usage.input_tokens // 0')
cache_create=$(json_int '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(json_int '.context_window.current_usage.cache_read_input_tokens // 0')
used_tokens=$((input_tokens + cache_create + cache_read))
context_pct=$((used_tokens * 100 / size))

branch=""
dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ] && dirty="*"
fi

session=""
session_start=$(json_get '.session.start_time // empty')
if [ -n "$session_start" ]; then
    start_epoch=$(iso_to_epoch "$session_start")
    if [ -n "$start_epoch" ]; then
        session=$(duration "$(( $(date +%s) - start_epoch ))")
    fi
fi

effort="default"
settings="$HOME/.claude/settings.json"
[ -f "$settings" ] && effort=$(jq -r '.effortLevel // .permissions.defaultMode // "default"' "$settings" 2>/dev/null)

context_color=$(color_for_pct "$context_pct")
line="${blue}${model}${reset}${sep}"
line+="ctx ${context_color}${context_pct}%${reset}${sep}"
line+="${teal}${dir}${reset}"
[ -n "$branch" ] && line+=" ${green}${branch}${red}${dirty}${reset}"
[ -n "$session" ] && line+="${sep}${white}${session}${reset}"
line+="${sep}${dim}${effort}${reset}"

usage_data=$(fetch_gitcode "usage" "$usage_url")
agent_data=$(fetch_gitcode "agent" "$agent_url")

usage_line=""
if [ -n "$usage_data" ]; then
    usage=$(safe_int "$(printf '%s' "$usage_data" | jq -r '.usage // 0')" 0)
    max_usage=$(safe_int "$(printf '%s' "$usage_data" | jq -r '.max_usage // 0')" 0)
    if [ "$max_usage" -gt 0 ] 2>/dev/null; then
        usage_pct=$((usage * 100 / max_usage))
        usage_bar_pct=$usage_pct
        [ "$usage_bar_pct" -gt 100 ] && usage_bar_pct=100
        usage_color=$(color_for_pct "$usage_bar_pct")
        usage_line="${white}tokens${reset} $(bar "$usage_bar_pct" 10) ${usage_color}${usage_pct}%${reset} ${dim}$(human_int "$usage")/$(human_int "$max_usage")${reset}"
    fi
elif [ ! -f "$cookie_file" ]; then
    usage_line="${dim}gitcode cookie missing${reset}"
fi

agent_line=""
if [ -n "$agent_data" ]; then
    remaining=$(safe_int "$(printf '%s' "$agent_data" | jq -r '.remaining_seconds // 0')" 0)
    expected=$(safe_int "$(printf '%s' "$agent_data" | jq -r '.expected_duration_seconds // 0')" 0)
    can_renewal=$(printf '%s' "$agent_data" | jq -r '.can_renewal // false')
    expire_time=$(printf '%s' "$agent_data" | jq -r '.expire_time // empty')
    agent_pct=0
    if [ "$expected" -gt 0 ] 2>/dev/null; then
        agent_pct=$(((expected - remaining) * 100 / expected))
        [ "$agent_pct" -lt 0 ] && agent_pct=0
        [ "$agent_pct" -gt 100 ] && agent_pct=100
    fi
    agent_color=$(color_for_pct "$agent_pct")
    renew_tag=""
    [ "$can_renewal" = "true" ] && renew_tag=" ${green}renew${reset}"
    agent_line="${white}agent ${reset} $(bar "$agent_pct" 10) ${agent_color}$(duration "$remaining") left${reset}"
    expire_label=$(time_label "$expire_time")
    [ -n "$expire_label" ] && agent_line+=" ${dim}until ${expire_label}${reset}"
    agent_line+="$renew_tag"
fi

printf "%b" "$line"
if [ -n "$usage_line" ] || [ -n "$agent_line" ]; then
    printf "\n\n"
    [ -n "$usage_line" ] && printf "%b" "$usage_line"
    [ -n "$usage_line" ] && [ -n "$agent_line" ] && printf "\n"
    [ -n "$agent_line" ] && printf "%b" "$agent_line"
fi
