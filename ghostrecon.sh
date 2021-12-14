#!/usr/bin/env bash
ProgressBarInterface() {
  if type -t ProgressBar.sh >/dev/null; then ProgressBar.sh $*; else cat; fi
}

NmapProgressBar() {
  sed -u -n -r '/About/s/([^:]+): About ([0-9]+).[0-9]+%.*/\2 \1/p' - | ProgressBarInterface -z
}

WpscanProgressBar() {
  tee "$logfile" | grep '[+]' | ProgressBarInterface -s normal
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

check_dependencies() {
  local pkg='git'
  local ver='2.17.1'
  local dir=$HOME/.local/bin
  if ! type -t $pkg >/dev/null; then
    printf '%s: ERROR: Necessário pacote %s %s ou superior.\n' 'link.sh' "$pkg" "$ver" 1>&2
    exit 1
  fi
  if ! type -t ProgressBar.sh > /dev/null; then
    if [[ ! -d "$HOME/.local/progressbar" ]]; then
      git clone https://github.com/NRZCode/progressbar.git "$HOME/.local/progressbar"
    fi
    mkdir -p "$dir"
    [[ "$dir" == @(${PATH//:/|}) ]] || export PATH="$PATH:$dir"
    ln -sf "$HOME/.local/progressbar/ProgressBar.sh" "$dir"
  fi
}

mklogdir() {
  mkdir -p "$1"
  dtreport=$(date '+%Y%m%d%H%M')
}

dg_menu() {
  dg=(dialog --stdout --title "$title" --backtitle "$backtitle" --checklist "$text" 0 "$width" 0)
  selection=$("${dg[@]}" "${dg_options[@]}")
}

#/**
# * checkArgType
# * @param $1 tipo para validação
# * @param $2 parâmetro
# * @param $3 valor
# * @return TRUE|FALSE
# */
checkArgType() {
  # valor de um parâmetro (arg: 3) não pode começar com - 'hifen'
  if [[ -z $3 || "$3" =~ ^- ]]; then
    echo "Opção $2 requer parâmetro." >&2
    return 1
  fi
  case $1 in
    bool) re='^(on|off|true|false|1|0)$';;
    string) re='^[[:print:]]+$';;
    int) re='^[-+]?[[:digit:]]+$';;
    float) re='^[-+]?[0-9]+([.,][0-9]+)?$';;
    domain) re='^(([^:/?#]+):)?(//((([^:/?#]+)@)?([^:/?#]+)(:([0-9]+))?))?(/([^?#]*))(\?([^#]*))?(#(.*))?';;
  esac
  [[ ${3,,} =~ $re ]]
}

banner() {
  echo '██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
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
  [[ $domain ]] && echo "Domain: $domain"
}

usage() { printf "${*:+$*\n}  Usar: $BASENAME -d domain.com\n" 1>&2; return 1; }

init() {
  local OPTIND OPTARG
  load_ansi_colors
  while getopts ":d:" opt; do
    case $opt in
         d) domain=$OPTARG;;
         q) verbose=1;;
         :) usage "Opção -$OPTARG requer parâmetro.";;
      \?|*) usage "Opção -$OPTARG desconhecida (?)";;
    esac
  done
  shift $((OPTIND - 1))

  while [ -z "$domain" ]; do
    banner
    read -p 'Enter domain: ' domain
#    if ! checkArgType domain domain "$domain"; then
#      echo "$domain INVALIDO"
#      domain=''
#    fi
  done
  domain="$(shopt -s extglob; echo ${domain#http?(s)://})"

  if [ -z "$domain" ]; then
    usage; exit 1;
  fi
}

run() {
  local logfile logdir tool

  logdir=${logdir:-$HOME/.local/${BASENAME%%.*}/$domain}
  mklogdir "$logdir"

  backtitle="Reconnaissence tools [$APP]"
  title="Reconhecimento do alvo [$domain]"
  text='Selecione as ferramentas:'
  width=0
  if dg_menu checklist; then
    sudo anonsurf start > /dev/null
    clear

    banner
    for t in $selection; do
      sudo anonsurf change
      sudo anonsurf myip
      case $t in
        nmap)
          # Nmap scan
          if type -t nmap >/dev/null; then
            tool=nmap
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Varredura de Portas NMAP${CReset}\n"
            logfile="$logdir/${dtreport}nmap.log"
            NMAP_OPT='-sS -sV -Pn -p- -vv'
            sudo nmap $NMAP_OPT $domain -oN $logfile --stats-every 1s 2>&- | NmapProgressBar
            [[ 1 == $verbose ]] && cat "$logfile"
            sed '/^PORT/,/^Service Info:/!d' "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        wpscan)
          # Wpscan
          if type -t wpscan >/dev/null; then
            tool=wpscan
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando WpScan${CReset}\n"
            logfile="$logdir/${dtreport}wpscan.log"
            wpscan --url "$domain" --random-user-agent --ignore-main-redirect --no-banner --api-token WgHJqB4r2114souaMB5aDGG5eulIJSz8RyJQ9FCKqdI --force --enumerate u | WpscanProgressBar
            [[ 1 == $verbose ]] && cat "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        knockpy)
          # Knockpy
          if type -t knockpy >/dev/null; then
            tool=knockpy
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Knock${CReset}\n"
            knockpy "$domain" --no-http-code 400 404 500 530 -th 50 -o "$logdir"
          fi
          ;;
        dirb)
          # dirb
          if type -t dirb >/dev/null; then
            tool=dirb
            logfile="$logdir/${dtreport}dirb.log"
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Dirb${CReset}\n"
            dirb "https://$domain" -N 404 -S -R -o "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        paramspider)
          #Paramspider
          paramspider.py() {
            python3 $HOME/.local/paramspider/paramspider.py "$@"
          }
          if type -t paramspider.py > /dev/null; then
            tool=ParamSpider
            logfile="$logdir/${dtreport}paramspider.log"
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando ParamSpider${CReset}\n"
            paramspider.py -d $domain --quiet --subs True --level high -o "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
      esac
    done
    sudo anonsurf stop
    return
  fi
  clear
}

main() {
  init "$@"
  run
}

APP='Ghost Recon'
APP_PATH=${BASH_SOURCE[0]%/*}
APP_VERSION=0.0.1
BASENAME=${BASH_SOURCE[0]##*/}
[[ $1 == @(-h|--help|help) ]] && { usage; exit 1; }
[[ $1 == @(-v|--version) ]] && { echo "$APP_VERSION"; exit 0; }
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  printf '%s: ERROR: Necessário shell %s %s ou superior.\n' "$BASENAME" 'bash' '4.0' 1>&2
  exit 1
fi
check_dependencies

shopt -s expand_aliases

#/**
# * Tools list
# */
declare -A tools=(
  [nmap]='Ferramenta de exploração de Rede e Rastreio de Segurança / Portas'
  [httpx]='Retornará URLs com status testado'
  [dirsearch]='Scanner de diretórios da web'
  [subfinder]='Ferramenta de descoberta de subdomínio otimizado'
  [sublist3r]='Ferramenta de descoberta de subdomínio'
  [dirb]='Web Content Scanner'
  [knockpy]='Enumerar rapidamente subdomínios'
  [paramspider]='Encontra parâmetros de subdomínios e arquivos web.'
  [gitdumper]='Ferramenta para despejar um repositório git de um site'
  [wpscan]='WordPress Security Scanner'
  [theHarvest]='Breve descrição'
  [karma]='Busca de e-mails e senhas'
)
mapfile -t dg_options < <(for tool in "${!tools[@]}"; do printf '%s\n%s\non\n' "$tool" "${tools[$tool]}"; done)

[[ ${BASH_SOURCE[0]} == $0 ]] && main "$@"
