# Docker Desktop
if [ -f "$HOME/.docker/init-zsh.sh" ]; then
    source "$HOME/.docker/init-zsh.sh" || true
fi


# UUIDv4（小文字変換 + クリップボードコピー）
alias uuidgen='uuidgen | tr "[:upper:]" "[:lower:]" | tr -d "\n" | tee >(pbcopy)'
