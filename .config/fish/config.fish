# Auto-start tmux
if status is-interactive
    and not set -q TMUX
    exec tmux
end
alias vim='nvim'
function fish_user_key_bindings
  fish_vi_key_bindings
  bind -M insert -m default jk backward-char force-repaint
end

