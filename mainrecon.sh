#!/usr/bin/env bash
NmapProgressBar() {
  sed -u -n -r '/About/s/([^:]+): About ([0-9]+).[0-9]+%.*/\2 \1/p' - | "$APP_PATH/src/ProgressBar.sh" -z
}

# ANSI Colors
function load_ansi_colors() {
  # @C FG Color
  #    |-- foreground color
  export CReset='\e[m' CFGBlack='\e[30m' CFGRed='\e[31m' CFGGreen='\e[32m' \
    CFGYellow='\e[33m' CFGBlue='\e[34m' CFGPurple='\e[35m' CFGCyan='\e[36m' \
    CFGWhite='\e[37m'
  # @C BG Color
  #    |-- background color
  export CBGBlack='\e[40m' CBGRed='\e[41m' CBGGreen='\e[42m' CBGYellow='\e[43m' \
    CBGBlue='\e[44m' CBGPurple='\e[45m' CBGCyan='\e[46m' CBGWhite='\e[47m'
  # @C Attribute
  #    |-- text attribute
  export CBold='\e[1m' CFaint='\e[2m' CItalic='\e[3m' CUnderline='\e[4m' \
    CSBlink='\e[5m' CFBlink='\e[6m' CReverse='\e[7m' CConceal='\e[8m' \
    CCrossed='\e[9m' CDoubleUnderline='\e[21m'
}

dg_menu() {
  local OPTIND OPTARG menu confirmation_continue
  #dialog --inputbox 'Informe o domain:' 0 0
  dg=(dialog --stdout --title "$title" --backtitle "$backtitle" --checklist "$text" 0 "$width" 0)
  selection=$("${dg[@]}" "${dg_options[@]}")
  return=$?
  clear
  if [[ $return == 0 ]]; then
    if [[ 'all-tools' == ${selection%% *} ]]; then
      selection="${tools[*]}"
    fi
  fi
}

usage() { printf "${*:+$*\n}  Usar: ${BASH_SOURCE} -d domain.com" 1>&2; exit 1; }

init() {
  local OPTIND OPTARG
  load_ansi_colors
  while getopts ":d:" opt; do
    case $opt in
         d) domain=$OPTARG;;
         :) usage "Opção -$OPTARG requer parâmetro.";;
      \?|*) usage "Opção -$OPTARG desconhecida (?)";;
    esac
  done
  shift $((OPTIND - 1))

  while [ -z "$domain" ]; do
    read -p 'Enter domain: ' domain
  done

  if [ -z "$domain" ]; then
    usage; exit 1;
  fi
}

run() {
  local log

  backtitle='Reconnaissence tools [mainrecon]'
  title='Reconhecimento do alvo'
  text='Selecione as ferramentas:'
  width=40
  dg_menu checklist

  # Nmap scan
  printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Varredura de Portas\n"
  log=$HOME/nmap.log
  NMAP_OPT='-sS -sV -Pn -p- -vv'
  sudo nmap $NMAP_OPT $domain -oN $log --stats-every 1s 2>&- | NmapProgressBar
  dialog --textbox "$log" 0 0

  # Wpscan
  wpscan --url "$domain" --ignore-main-redirect --no-banner --api-token WgHJqB4r2114souaMB5aDGG5eulIJSz8RyJQ9FCKqdI --force --enumerate u -o wpscan.txt

  while :; do
    signal='/ - \ |'
    for s in $signal; do
      printf "${CBold}${CFGBlue}[${CFGPurple}%s${CFGBlue}] Iniciando varredura de Sub-diretorios! Este processo pode demorar muito.\r" "$s"
      sleep .08
    done
    ((i++ > 30)) && break
  done
}

main() {
  init "$@"
  run
}

#/**
# * Tools list
# */
tools=(
  nmap
  httpx
  dirsearch
  subfinder
  sublist3r
  dirb
  knockpy
  paramspider
  gitdumper
  wpscan
  theHarvest
  karma
)
mapfile -t dg_options < <(printf '%s\n\noff\n' all-tools "${tools[@]}")

APP_PATH=${BASH_SOURCE[0]%/*}
[[ ${BASH_SOURCE[0]} == $0 ]] && main "$@"
