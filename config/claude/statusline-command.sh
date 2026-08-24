#!/bin/bash

# 入力を標準入力から取得
input=$(cat)

# jqを使用して必要な値を抽出
model_name=$(echo "$input" | jq -r '.model.display_name')
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
project_name=$(basename "$project_dir" 2>/dev/null)
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# ANSI カラーコード
reset="\033[0m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
cyan="\033[36m"

# キャッシュ設定
cache_id=$(echo "$cwd" | md5 -q 2>/dev/null || echo "$cwd" | md5sum 2>/dev/null | cut -d' ' -f1)
CACHE_FILE="/tmp/statusline-git-cache-${cache_id}"
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
git_ahead=""
git_behind=""

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
        # untracked（新規ファイル）は git diff には現れないため ls-files で別途数える
        cached_untracked=$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        # upstream との差分（behind=未pull / ahead=未push）。upstream 未設定なら空
        cached_ahead=""
        cached_behind=""
        ahead_behind=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
        if [ -n "$ahead_behind" ]; then
            cached_behind=$(echo "$ahead_behind" | cut -f1)
            cached_ahead=$(echo "$ahead_behind" | cut -f2)
        fi
        echo "${git_branch}|${cached_staged}|${cached_modified}|${cached_untracked}|${cached_ahead}|${cached_behind}" > "$CACHE_FILE"
    fi

    # キャッシュから読み込み
    if [ -f "$CACHE_FILE" ]; then
        IFS='|' read -r git_branch git_staged git_modified git_untracked git_ahead git_behind < "$CACHE_FILE"
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

# ---- 1行目: [model] 📁 {project} → {cwd} | 🌿 {branch} {push} ----
# 端末幅に応じて付加要素を間引く。Claude Code は COLUMNS をセットする（v2.1.153+。
# 各行は幅で truncate され折り返さないため、溢れる前に優先度の低い要素を落とす）。
# COLUMNS 未設定（旧版）なら 999 として全要素を表示。絵文字 📁 🌿 は 2 幅で概算。
avail=$(( ${COLUMNS:-999} - 1 ))

# モデル名の冗長な "(1M context)" は " 1M" に圧縮（1M である事実は残す）
model_disp="${model_name/ (1M context)/ 1M}"

# push（未push/未pull）のプレーン表記（幅見積もり用）
push_plain=""
[ "$git_ahead" -gt 0 ] 2>/dev/null && push_plain="↑${git_ahead}"
[ "$git_behind" -gt 0 ] 2>/dev/null && push_plain="${push_plain}↓${git_behind}"

# 未コミット内訳マーカー（+staged ~modified ?untracked）。色なしのプレーン文字列
git_marker=""
[ "$git_staged" -gt 0 ] 2>/dev/null && git_marker="${git_marker} +${git_staged}"
[ "$git_modified" -gt 0 ] 2>/dev/null && git_marker="${git_marker} ~${git_modified}"
[ "$git_untracked" -gt 0 ] 2>/dev/null && git_marker="${git_marker} ?${git_untracked}"

# cwd suffix（current_dir が project_dir と異なる場合のみ）
cwd_name=""
if [ -n "$cwd" ] && [ "$cwd" != "$project_dir" ]; then
    cwd_name=$(basename "$cwd")
fi

# 必須要素（モデル + ブランチ + push）の概算幅
branch_w=0
if [ -n "$git_branch" ]; then
    branch_w=$(( 6 + ${#git_branch} ))                       # " | 🌿 <branch>"
    [ -n "$git_marker" ] && branch_w=$(( branch_w + ${#git_marker} ))
    [ -n "$push_plain" ] && branch_w=$(( branch_w + 1 + ${#push_plain} ))
fi
used=$(( 2 + ${#model_disp} + branch_w ))                    # "[<model>]" + 必須ブランチ
# 必須すら溢れるならモデル名を先頭語だけに短縮（例: "Opus 4.8" → "Opus"）
if [ "$used" -gt "$avail" ]; then
    model_disp="${model_disp%% *}"
    used=$(( 2 + ${#model_disp} + branch_w ))
fi

# 残り幅で付加要素を優先順（project > cwd suffix）に採用
show_project=0; show_cwd=0
if [ -n "$project_name" ] && [ $(( used + 4 + ${#project_name} )) -le "$avail" ]; then
    show_project=1; used=$(( used + 4 + ${#project_name} ))  # " 📁 <project>"
fi
if [ -n "$cwd_name" ] && [ "$show_project" -eq 1 ] && [ $(( used + 3 + ${#cwd_name} )) -le "$avail" ]; then
    show_cwd=1                                               # " → <cwd>"
fi

# --- 視覚順に組み立て ---
line1="[${model_disp}]"

if [ "$show_project" -eq 1 ]; then
    if [ -n "$git_remote_url" ]; then
        project_display=$(make_link "$git_remote_url" "$project_name")
    else
        project_display="$project_name"
    fi
    line1="${line1} 📁 ${project_display}"
    if [ "$show_cwd" -eq 1 ]; then
        line1="${line1} → ${yellow}${cwd_name}${reset}"
    fi
fi

if [ -n "$git_branch" ]; then
    # ブランチ名の色で未コミットの有無を示す（緑=clean / 黄=staged・modified・untracked いずれかあり）
    if [ "$git_staged" -gt 0 ] 2>/dev/null || [ "$git_modified" -gt 0 ] 2>/dev/null || [ "$git_untracked" -gt 0 ] 2>/dev/null; then
        branch_color="$yellow"
    else
        branch_color="$green"
    fi

    if [ -n "$git_remote_url" ]; then
        branch_text=$(make_link "${git_remote_url}/tree/${git_branch}" "$git_branch")
    else
        branch_text="$git_branch"
    fi
    # ブランチ名のみクリッカブルにし、内訳マーカー（+staged ~modified ?untracked）は外側に同色で添える
    line1="${line1} | 🌿 ${branch_color}${branch_text}${git_marker}${reset}"

    # ローカル↔リモートのズレ（↑=未push / ↓=未pull）。upstream 未設定なら無表示
    push_status=""
    [ "$git_ahead" -gt 0 ] 2>/dev/null && push_status="${cyan}↑${git_ahead}${reset}"
    [ "$git_behind" -gt 0 ] 2>/dev/null && push_status="${push_status}${red}↓${git_behind}${reset}"
    [ -n "$push_status" ] && line1="${line1} ${push_status}"
fi

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
