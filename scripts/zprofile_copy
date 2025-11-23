
eval "$(/opt/homebrew/bin/brew shellenv)"

add_to_path_front_if_missing () {
  case ":$PATH:" in
    *:"$1":*) ;;            # do nothing if already present
    *) PATH="$1:$PATH" ;;
  esac
}

add_to_path_end_if_missing () {
  case ":$PATH:" in
    *:"$1":*) ;;            # do nothing if already present
    *) PATH="$PATH:$1" ;;
  esac
}

add_to_path_front_if_missing "/opt/homebrew/bin"
add_to_path_front_if_missing "/opt/homebrew/opt/libtool/libexec/gnubin"
add_to_path_front_if_missing "/opt/homebrew/opt/llvm/bin"
add_to_path_front_if_missing "/Library/Frameworks/Python.framework/Versions/3.13/bin"
add_to_path_front_if_missing "/Users/matt/Library/Python/3.13/bin"
add_to_path_front_if_missing "/Users/matt/bin"
add_to_path_end_if_missing "/Users/matt/.local/bin"
#if you hit python issues, uncomment the following line to force it to the front of the path
#export PATH="/Library/Frameworks/Python.framework/Versions/3.13/bin:${PATH}"
#export PATH="$PATH:/Users/matt/Library/Python/3.13/bin"
#export PATH="$PATH:/Users/matt/.local/bin"

