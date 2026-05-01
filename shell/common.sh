# ghq + fzf でリポジトリ移動
function cdp() {
  local selected_dir=$(ghq list -p | fzf --reverse)
  if [[ -n "$selected_dir" ]]; then
    cd "$selected_dir"
  fi
}

# メモ関数
m(){
  local ts
  ts="$(date '+%F %H:%M')"
  __MEMO_MD+="## ${ts}"$'\n'
  __MEMO_MD+="$(cat)"$'\n\n'
}
m1(){
  local ts
  ts="$(date '+%F %H:%M')"
  __MEMO_MD+="## ${ts}"$'\n'
  __MEMO_MD+="$*"$'\n\n'
}
ml(){ printf "%s" "$__MEMO_MD"; }
mc(){ __MEMO_MD=""; }
ms(){ printf "%s" "$__MEMO_MD" >> "${1:-$HOME/memo.md}"; }
msc(){ ms "$1"; mc; }
