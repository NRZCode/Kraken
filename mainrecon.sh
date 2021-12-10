#!/usr/bin/env bash
NmapProgressBar() {
  sed -u -n -r '/About/s/([^:]+): About ([0-9]+).[0-9]+%.*/\2 \1/p' - | if type -t ProgressBar.sh >/dev/null; then ProgressBar.sh -z; fi
}

WpscanProgressBar() {
  tee "$logfile" | grep '[+]' | if type -t ProgressBar.sh >/dev/null; then ProgressBar.sh -s normal; fi
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

mklogdir() {
  mkdir -p "$1"
  dtreport=$(date '+%Y%m%d%H%M')
}

dg_menu() {
  dg=(dialog --stdout --title "$title" --backtitle "$backtitle" --checklist "$text" 0 "$width" 0)
  selection=$("${dg[@]}" "${dg_options[@]}")
  clear
}

usage() { printf "${*:+$*\n}  Usar: ${BASH_SOURCE} -d domain.com" 1>&2; return 1; }

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
    echo "$banner"
    read -p 'Enter domain: ' domain
  done

  if [ -z "$domain" ]; then
    usage; exit 1;
  fi
}

run() {
  local logfile logdir tool

  logdir="$HOME/.local/${BASENAME%%.*}/$domain"
  mklogdir "$logdir"

  backtitle='Reconnaissence tools [mainrecon]'
  title='Reconhecimento do alvo'
  text='Selecione as ferramentas:'
  width=0
  dg_menu checklist

  # Nmap scan
  if type -t nmap >/dev/null; then
    tool=nmap
    printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Varredura de Portas${CReset}\n"
    logfile="$logdir/${dtreport}nmap.log"
    NMAP_OPT='-sS -sV -Pn -p- -vv'
    sudo nmap $NMAP_OPT $domain -oN $logfile --stats-every 1s 2>&- | NmapProgressBar
    cat "$logfile"
    printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
  fi

  # Wpscan
  if type -t wpscan >/dev/null; then
    tool=wpscan
    logfile="$logdir/${dtreport}wpscan.log"
    wpscan --url "$domain" --ignore-main-redirect --no-banner --api-token WgHJqB4r2114souaMB5aDGG5eulIJSz8RyJQ9FCKqdI --force --enumerate u | WpscanProgressBar
    cat "$logfile"
    printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
  fi

  # Knockpy
  if type -t knockpy >/dev/null; then
    tool=knockpy
    printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Knock${CReset}\n"
    knockpy "$domain" --no-http-code 400 404 500 530 -th 50 -o "$logdir"
  fi
  #while :; do
  #  signal='/ - \ |'
  #  for s in $signal; do
  #    printf "${CBold}${CFGBlue}[${CFGPurple}%s${CFGBlue}] Iniciando varredura de Sub-diretorios! Este processo pode demorar muito.\r" "$s"
  #    sleep .08
  #  done
  #  ((i++ > 30)) && break
  #done
}

main() {
  init "$@"
  run
}

APP_PATH=${BASH_SOURCE[0]%/*}
BASENAME=${BASH_SOURCE[0]##*/}
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  printf '%s: ERROR: Necessário shell %s %s ou superior.\n' "$BASENAME" 'bash' '4.0' 1>&2
  exit 1
fi

banner='██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║
██║   ██║██╔══██║██║   ██║╚════██║   ██║
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝

██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝'

#/**
# * Tools list
# */
declare -A tools=(
  [nmap]='Ferramenta de exploração de Rede e Rastreio de Segurança / Portas'
  [httpx]='Breve descrição'
  [dirsearch]='Breve descrição'
  [subfinder]='Breve descrição'
  [sublist3r]='Breve descrição'
  [dirb]='Web Content Scanner'
  [knockpy]='Breve descrição'
  [paramspider]='Breve descrição'
  [gitdumper]='Breve descrição'
  [wpscan]='WordPress Security Scanner'
  [theHarvest]='Breve descrição'
  [karma]='Breve descrição'
)
mapfile -t dg_options < <(for tool in "${!tools[@]}"; do printf '%s\n%s\non\n' "$tool" "${tools[$tool]}"; done)

[[ ${BASH_SOURCE[0]} == $0 ]] && main "$@"
