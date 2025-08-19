source ~/.local/share/omarchy/default/bash/rc

xdg_desktop_list() {
  local xdh="${XDG_DATA_HOME:-$HOME/.local/share}"
  local xds="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  local locale="${LC_ALL:-${LC_MESSAGES:-$LANG}}"
  local lang_full="${locale%%[.@]*}"     # e.g. en_US
  local lang_base="${lang_full%%_*}"     # e.g. en

  local -a roots=("$xdh/applications")
  local IFS=:
  for d in $xds; do roots+=("$d/applications"); done
  unset IFS

  {
    for root in "${roots[@]}"; do
      [ -d "$root" ] || continue
      find "$root" -type f -name '*.desktop' -print0 |
      while IFS= read -r -d '' f; do
        rel="${f#"$root/"}"; id="${rel%.desktop}"
        printf '%s\t%s\n' "$f" "$id"
      done
    done
  } | awk -F'\t' '!seen[$2]++ {print $1}' |
    while IFS= read -r path; do
      name="$(
        awk -v lang1="$lang_full" -v lang2="$lang_base" '
          BEGIN {insec=0; best=""; mid=""; def=""}
          $0=="[Desktop Entry]" {insec=1; next}
          /^\[/ {if (insec) insec=0}
          insec && match($0,/^Name\[([A-Za-z]{2}(_[A-Za-z]{2})?)\]=(.*)$/,m){
            if (m[1]==lang1 && best=="") best=m[3];
            else if (m[1]==lang2 && mid=="") mid=m[3];
            next
          }
          insec && def=="" && match($0,/^Name=(.*)$/,m){def=m[1]}
          END{ if(best!="") print best; else if(mid!="") print mid; else print def }
        ' "$path"
      )"
      printf '%s (%s)\n' "$path" "${name:-${path##*/}}"
    done
}

