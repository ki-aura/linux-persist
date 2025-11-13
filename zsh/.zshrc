# Lines configured by zsh-newuser-install
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=20000

# PATH ADDITIONS ------------------------------------------------------------
# SEE .zprofile
# PATH ADDITIONS ------------------------------------------------------------


# HELPER FUNCTIONS ------------------------------------------------------------

# Clone env for new shell
clone_terminal() {
    # Unique temp file for this clone (avoids collisions)
    local envfile="/tmp/current_env_$$"

    # Save exported environment variables
    export -p > "$envfile"

    # Append a cd command to restore current directory, safely quoted
    echo "cd $(printf %q "$PWD")" >> "$envfile"

    # Open a new iTerm2 split and source the environment
    osascript <<EOF
tell application "iTerm2"
    tell current window
        tell current session
            set newSession to split vertically with default profile
            tell newSession
                write text "source $envfile"
            end tell
        end tell
    end tell
end tell
EOF
}

# END OF FUNCTIONS ------------------------------------------------------------


# SET OPTIONS ------------------------------------------------------------

setopt autocd              # change directory just by typing its name
setopt interactivecomments # allow comments in interactive mode
setopt magicequalsubst     # enable filename expansion for arguments of the form ‘anything=expression’
setopt nonomatch           # hide error message if there is no match for the pattern
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
#setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt auto_list
setopt auto_menu
setopt menu_complete
setopt share_history
setopt inc_append_history

# Ignore rm and trash commands in history
HIST_IGNORE_PATTERN='(^rm |^trash )'

autoload -Uz compinit
compinit -d ~/.cache/zcompdump

WORDCHARS=${WORDCHARS//\/} # Don't consider certain characters part of the word

PROMPT_EOL_MARK=""

bindkey -e                                        # emacs key bindings
bindkey ' ' magic-space                           # do history expansion on space
bindkey '^[[3;5~' kill-word                       # ctrl + Supr
bindkey '^[[3~' delete-char                       # delete
bindkey '^[[1;5C' forward-word                    # ctrl + ->
bindkey '^[[1;5D' backward-word                   # ctrl + <-
bindkey '^[[5~' beginning-of-buffer-or-history    # page up
bindkey '^[[6~' end-of-buffer-or-history          # page down
bindkey '^[[H' beginning-of-line                  # home
bindkey '^[[F' end-of-line                        # end
bindkey '^[[Z' undo                               # shift + tab undo last action

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # case insensitive tab completion


# PROMPT ---------------------------------------------------------------

precmd() {
	#set prompt
	tBolt=⚡
	tRedApple=🍎
	tGreenApple=🍏
   #tUser=$'%B%F{%(#.red.blue)}%(#.'$tBolt$'%n'$tBolt$tRedApple$'%m.%n'$tGreenApple$'%m)%b'
	tUser=$'%B%F{%(#.red.blue)}%(#. '$tBolt$'%n '$tBolt'.%n'$tGreenApple$')%b'
	tPath=$'%F{%(#.red.blue)}%(4~.%-1~/…/%2~.%3~)'
	tCLine=$'%B%(#.%F{red}#.%F{blue}$)%b'
	tLineColor='%F{%(#.162.6)}'	#162 =cerise, 6=cyan
	tVenv=$'none'

    if [[ $PWD == /Users/matt/Projects || $PWD == /Users/matt/Projects/* ]]; then 
    	tProj='%F{green} PROJECT'
    elif [[ $PWD == /opt/homebrew || $PWD == /opt/homebrew/* ]]; then 
    	tProj='%F{5} <HOME BREW>'
    else
    	tProj='%F{%(#.162.6)}─'
    fi
	

	if [[ -n "${VIRTUAL_ENV-}" ]]; then
		tVenv=$'%B%(#.%F{red}.%F{blue})Virtual Env:%b '$VIRTUAL_ENV
		PROMPT=$'\n'$tLineColor$'('$tVenv$tLineColor$')\n('$tUser$tLineColor$') ['$tPath$tLineColor$']\n'$tCLine$'%F{reset} '
	else
	   #PROMPT=$'\n'$tLineColor$'('$tUser$tLineColor$') ['$tPath$tLineColor$']'$tProj$tLineColor$'\n'$tCLine$'%F{reset} '
		PROMPT=$'\n'$tLineColor$'┌───('$tUser$tLineColor$')───['$tPath$tLineColor$']'$tProj$tLineColor$'\n└─'$tCLine$'%F{reset} '
	fi
	unset tUser tPath tCLine tBolt tRedApple tGreenApple tLineColor tVenv tProj
}

chpwd() {
    if [[ "$PWD" == "/Users/matt/Projects" || "$PWD" == "/Users/matt/Projects"/* ]]; then 
    	#print -P "\n%F{green}<== PROJECT DIRECTORY ==>%F{reset}"
    fi
}

# END OF PROMPT -------------------------------------------------------------

# enable syntax-highlighting
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
	. /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
	ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
	ZSH_HIGHLIGHT_STYLES[default]=none
	ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red,bold
	ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
	ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
	ZSH_HIGHLIGHT_STYLES[global-alias]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
	ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
	ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
	ZSH_HIGHLIGHT_STYLES[path]=underline
	ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
	ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
	ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
	ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
	ZSH_HIGHLIGHT_STYLES[command-substitution]=none
	ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[process-substitution]=none
	ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
	ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
	ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
	ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
	ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
	ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta
	ZSH_HIGHLIGHT_STYLES[assign]=none
	ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
	ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
	ZSH_HIGHLIGHT_STYLES[named-fd]=none
	ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
	ZSH_HIGHLIGHT_STYLES[arg0]=fg=green
	ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
	ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
	ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
	ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
	ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
	ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
	ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
fi

# addins for zsh
#zsh-syntax-highlighting is above
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
source /opt/homebrew/etc/profile.d/autojump.sh

# for Homebrew, Python & git
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/opt/homebrew/share/zsh-syntax-highlighting/highlighters
if [ -z "$PKG_CONFIG_PATH_SET" ]; then
	export PKG_CONFIG_PATH="/opt/homebrew/opt/tcl-tk/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig:$PKG_CONFIG_PATH"
    export PKG_CONFIG_PATH_SET=1
fi

export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
export EDITOR=nano

alias ll="ls -lAhGO --color=always -D '[%b %d %H:%M]'"
alias grep='grep --color=always'
alias ls='ls -A --color=always'
alias diff='diff --color=always'
alias htop='sudo /opt/homebrew/bin/htop;sudo /usr/sbin/chown matt /Users/matt/.config/htop/htoprc'
