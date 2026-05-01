#!/bin/bash

# 入力を標準入力から取得
input=$(cat)

# jqを使用して必要な値を抽出
model_name=$(echo "$input" | jq -r '.model.display_name')
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
project_name=$(basename "$project_dir" 2>/dev/null)
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# ANSI カラーコード
reset="\033[0m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"

# キャッシュ設定
CACHE_FILE="/tmp/statusline-git-cache-$(echo "$cwd" | md5 -q 2>/dev/null || echo "$cwd" | md5sum 2>/dev/null | cut -d' ' -f1)"
CACHE_MAX_AGE=5  # 秒

cache_is_stale() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 0
    fi
    local now file_age age
    now=$(date +%s)
    file_age=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
    age=$(( now - file_age ))
    [ "$age" -ge "$CACHE_MAX_AGE" ]
}

# git情報を取得（gitリポジトリの場合のみ）
git_branch=""
git_remote_url=""
git_staged=""
git_modified=""

if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # リモートURLを取得（クリッカブルリンク用 — 変更頻度が低いのでキャッシュ外）
    remote_url=$(git -C "$cwd" --no-optional-locks remote get-url origin 2>/dev/null)
    if [ -n "$remote_url" ]; then
        if echo "$remote_url" | grep -q "^git@"; then
            git_remote_url=$(echo "$remote_url" | sed 's|git@\([^:]*\):\(.*\)\.git|https://\1/\2|' | sed 's|git@\([^:]*\):\(.*\)|https://\1/\2|')
        else
            git_remote_url=$(echo "$remote_url" | sed 's|\.git$||')
        fi
    fi

    # キャッシュが古い場合のみ git status / branch を実行
    if cache_is_stale; then
        git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
        cached_staged=$(git -C "$cwd" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        cached_modified=$(git -C "$cwd" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "${git_branch}|${cached_staged}|${cached_modified}" > "$CACHE_FILE"
    fi

    # キャッシュから読み込み
    if [ -f "$CACHE_FILE" ]; then
        IFS='|' read -r git_branch git_staged git_modified < "$CACHE_FILE"
    fi
fi

# プログレスバーを構築（10文字、▓=使用済み、░=残り）
build_progress_bar() {
    local pct=${1:-0}
    local filled=$(( pct * BAR_WIDTH / 100 ))
    [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
    local empty=$(( BAR_WIDTH - filled ))

    # 使用率に応じてバー全体の色を決定
    local bar_color
    if [ "$pct" -le 40 ]; then
        bar_color="38;5;28"        # 深緑
    elif [ "$pct" -le 50 ]; then
        bar_color="38;5;46"        # 緑（文字側がレインボー）
    elif [ "$pct" -le 60 ]; then
        bar_color="38;5;220"       # 黄色
    elif [ "$pct" -le 70 ]; then
        bar_color="38;5;208"       # オレンジ
    else
        bar_color="38;5;196"       # 赤
    fi

    local bar="\033[${bar_color}m"
    [ "$filled" -gt 0 ] && bar="${bar}$(printf "%${filled}s" | tr ' ' '▓')"

    [ "$empty" -gt 0 ] && bar="${bar}${reset}$(printf "%${empty}s" | tr ' ' '░')"
    bar="${bar}${reset}"
    printf "%b" "$bar"
}
BAR_WIDTH=10

# OSC 8 クリッカブルリンクを構築
make_link() {
    local url=$1
    local text=$2
    printf '\e]8;;%s\a%s\e]8;;\a' "$url" "$text"
}

# ---- 1行目: [model] 📁 {project} | 🌿 {branch}{git-status} ----
line1=""
line1="${line1}[${model_name}]"

if [ -n "$project_name" ]; then
    if [ -n "$git_remote_url" ]; then
        project_display=$(make_link "$git_remote_url" "$project_name")
    else
        project_display="$project_name"
    fi
    line1="${line1} 📁 ${project_display}"
    # current_dirがproject_dirと異なる場合に表示
    if [ -n "$cwd" ] && [ "$cwd" != "$project_dir" ]; then
        cwd_name=$(basename "$cwd")
        line1="${line1} → ${yellow}${cwd_name}${reset}"
    fi
fi

if [ -n "$git_branch" ]; then
    # ブランチ名の後にgitステータスインジケーター（ファイル数付き）を付与
    status_indicators=""
    [ "$git_staged" -gt 0 ] 2>/dev/null && status_indicators="${status_indicators}${green}+${git_staged}${reset}"
    [ "$git_modified" -gt 0 ] 2>/dev/null && status_indicators="${status_indicators}${yellow}~${git_modified}${reset}"

    if [ -n "$git_remote_url" ]; then
        branch_display=$(make_link "${git_remote_url}/tree/${git_branch}" "$git_branch")
    else
        branch_display="$git_branch"
    fi
    line1="${line1} | 🌿 ${branch_display}"
    if [ -n "$status_indicators" ]; then
        line1="${line1} ${status_indicators}"
    fi
fi

# セッション変更行数
lines_display=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
    lines_display=" | ${green}+${lines_added}${reset} ${red}-${lines_removed}${reset}"
fi
line1="${line1}${lines_display}"

# ---- 2行目: Context window usage プログレスバー + Rate Limit ----
pct=$(echo "$used_percentage" | cut -d. -f1)
if [ -n "$pct" ] && [ "$pct" -ge 0 ] 2>/dev/null; then
    bar=$(build_progress_bar "$pct")
    line2="Context: ${bar} ${pct}%"
else
    line2="Context: --"
fi

# Rate Limit (5h) 表示を追加
if [ -n "$rate_5h" ]; then
    rate_pct=$(echo "$rate_5h" | cut -d. -f1)
    # 適正ペースを超過しているか判定してバーの色を上書き
    rate_bar=$(build_progress_bar "$rate_pct")
    if [ -n "$resets_at" ]; then
        now_epoch=$(date +%s)
        remaining=$(( resets_at - now_epoch ))
        if [ "$remaining" -gt 0 ] && [ "$remaining" -le 18000 ]; then
            elapsed=$(( 18000 - remaining ))
            ideal_pct=$(( elapsed * 100 / 18000 ))
            diff_pct=$(( rate_pct - ideal_pct ))
            if [ "$diff_pct" -gt 20 ]; then
                bar_override_color="31"  # 赤
            else
                bar_override_color="32"  # 緑
            fi
            filled=$(( rate_pct * BAR_WIDTH / 100 ))
            [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
            empty=$(( BAR_WIDTH - filled ))
            rate_bar="\033[${bar_override_color}m"
            [ "$filled" -gt 0 ] && rate_bar="${rate_bar}$(printf "%${filled}s" | tr ' ' '▓')"
            [ "$empty" -gt 0 ] && rate_bar="${rate_bar}${reset}$(printf "%${empty}s" | tr ' ' '░')"
            rate_bar="${rate_bar}${reset}"
        fi
    fi
    rate_display="5h: ${rate_bar} ${rate_pct}%"

    if [ -n "$resets_at" ]; then
        reset_time=$(date -r "$resets_at" '+%H:%M' 2>/dev/null)
        if [ -n "$reset_time" ]; then
            rate_display="${rate_display} →${reset_time}"
        fi
    fi

    line2="${line2}  ${rate_display}"
fi

printf "%b\n%b\n" "$line1" "$line2"
