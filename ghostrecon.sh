#!/usr/bin/env bash

APP='Ghost Recon'
APP_VERSION=0.0.2

ProgressBarInterface() {
  if type -t ProgressBar.sh >/dev/null; then ProgressBar.sh $*; else cat; fi
}

NmapProgressBar() {
  sed -u -n -r '/About/s/([^:]+): About ([0-9]+).[0-9]+%.*/\2 \1/p' - | ProgressBarInterface -z
}

WpscanProgressBar() {
  grep '[+]' | ProgressBarInterface -s normal
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
    ln -sf "$HOME/.local/progressbar/ProgressBar.sh" "$dir/ProgressBar.sh"
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
  echo ' ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
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
  while getopts ":d:v:" opt; do
    case $opt in
         d) domain=$OPTARG;;
         v) [[ $OPTARG == 'v' ]] && verbose=1;;
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
    sudo service tor start > /dev/null
    sudo anonsurf start > /dev/null
    clear

    banner
    for t in $selection; do
      sudo anonsurf change > /dev/null
      case $t in
        nmap)
          # Nmap scan
          if type -t nmap >/dev/null; then
            tool=nmap
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Varredura de Portas NMAP${CReset}\n"
            logfile="$logdir/${dtreport}nmap.log"
            NMAP_OPT='-sS -sV -Pn -vv'
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
            wpscan --url "$domain" --random-user-agent --ignore-main-redirect --no-banner --api-token WgHJqB4r2114souaMB5aDGG5eulIJSz8RyJQ9FCKqdI --force --enumerate u | tee "$logfile" | WpscanProgressBar
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
          if type -t paramspider.py > /dev/null; then
            tool=ParamSpider
            logfile="$logdir/${dtreport}paramspider.log"
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando ParamSpider${CReset}\n"
            paramspider.py -d "$domain" --quiet --subs True --level high -o "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        subfinder)
          #Subfinder
          if type -t subfinder > /dev/null; then
            tool=Subfinder
            logfile="$logdir/${dtreport}subfinder.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Subfinder${CReset}\n"
            subfinder -d "$domain" -all -silent -o "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        sublist3r)
          #Subfinder
          if type -t subfinder > /dev/null; then
            tool=Sublist3r
            logfile="$logdir/${dtreport}sublist3r.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Sublist3r${CReset}\n"
            sublist3r -d "$domain" -t 20 -o "$logfile" | ProgressBarInterface -s normal
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        httpx)
          #Httpx
          if type -t httpx > /dev/null; then
            tool=Httpx
            logfile="$logdir/${dtreport}httpx.log";
            printf "${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Httpx${CReset}\n"
            httpx -nf -silent | ProgressBarInterface
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        gau)
          #Gau
          if type -t subfinder sublist3r httpx gau > /dev/null; then
            tool=Gau
            logfile="$logdir/${dtreport}gau.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando Conjunto Otimizado de Ferramentas.${CReset}\n"
            printf "\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Subfinder${CReset}\n"
            subfinder -d "$domain" -all -silent -o "$logdir/${dtreport}subfinder.log"
            printf "${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Sublist3r${CReset}\n"
            sublist3r -d "$domain" -t 20 -o "$logdir/${dtreport}sublist3r.log" | ProgressBarInterface -s normal
            printf "${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Httpx e Gau${CReset}\n"
            httpx -nf -l <(sort -u "$logdir/${dtreport}"{subfinder,sublist3r}.log) -silent | gau -v -subs -o "$logfile" | ProgressBarInterface
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        gitdumper)
          if type -t gitdumper.sh > /dev/null; then
            tool=GitDumper
            logfile="$logdir/${dtreport}gitdumper.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] GitDumper${CReset}\n"
            gitdumper.sh https://$domain/.git/
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        theHarvest)
          if type -t theHarvester > /dev/null; then
            tool=theHarvester
            logfile="$logdir/${dtreport}theHarvester.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] theHarvester${CReset}\n"
            sudo anonsurf stop > /dev/null
            theHarvester -d $domain -l 500 -b all -g -s
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        dirsearch)
          if type -t dirsearch > /dev/null; then
            tool=Dirsearch
            logfile="$logdir/${dtreport}dirsearch.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Dirsearch${CReset}\n"
            dicc=$(realpath $(command -v dirsearch))
            dirsearch -u "https://$domain" -w /usr/share/dirsearch/db/dicc.txt -i 200,300-399 -x 400-499,500-599 -t 50 -q -o "$logfile"
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
        karma)
          if type -t karma > /dev/null; then
            tool=Karma
            logfile="$logdir/${dtreport}karma.log";
            printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Karma${CReset}\n"
            echo 'Repositório inválido'
            printf 'Relatório de %s salvo em %s\n=====\n\n' "$tool" "$logfile"
          fi
          ;;
      esac
    done
    sudo anonsurf stop > /dev/null
    return
  fi
  clear
}

main() {
  init "$@"
  run
}

APP_PATH=${BASH_SOURCE[0]%/*}
BASENAME=${BASH_SOURCE[0]##*/}
[[ $1 == @(-h|--help|help) ]] && { usage; exit 1; }
[[ $1 == @(-V|--version) ]] && { echo "$APP_VERSION"; exit 0; }
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  printf '%s: ERROR: Necessário shell %s %s ou superior.\n' "$BASENAME" 'bash' '4.0' 1>&2
  exit 1
fi
check_dependencies

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
  [theHarvest]='Ferramenta reúne e-mails, nomes, subdomínios, IPs e URLs'
  [karma]='Busca de e-mails e senhas'
  [gau]='Ferramenta de descoberta de subdomínios'
)
mapfile -t dg_options < <(for tool in "${!tools[@]}"; do printf '%s\n%s\non\n' "$tool" "${tools[$tool]}"; done)

[[ ${BASH_SOURCE[0]} == $0 ]] && main "$@"
