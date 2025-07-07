# Auto-start tmux
if status is-interactive
    and not set -q TMUX
    and not string match -q "*ssh*" $SSH_CONNECTION
    exec tmux new-session -A -s main
end
alias vim='nvim'
function fish_user_key_bindings
  fish_vi_key_bindings
  bind -M insert -m default jk backward-char force-repaint
end

