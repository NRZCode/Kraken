#!/usr/bin/env bash
#
APP='Ghost Recon'
APP_VERSION=0.0.5

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

cfg_listsections() {
  local file=$1
  grep -oP '(?<=^\[)[^]]+' "$file"
}

read_package_ini() {
  local sec url script post_exec
  cfg_parser "$inifile"
  while read sec; do
    unset description anonsurf depends command
    cfg_section_$sec 2>&-
    descriptions[${sec,,}]="$sec|$description"
    tools[${sec,,}]="$sec|$depends|$anonsurf|$command"
  done < <(cfg_listsections "$inifile")
}

check_dependencies() {
  local pkg='git'
  local ver='2.17.1'
  local bindir=$homedir/.local/bin

  if ! command -v ${basename%.*} &> /dev/null; then
    ln -sf "$script" /usr/local/bin/${basename%.*}
  fi

  if ! type -t $pkg >/dev/null; then
    printf '%s: ERROR: Necessário pacote %s %s ou superior.\n' "$basename" "$pkg" "$ver" 1>&2
    exit 1
  fi
  if ! type -t ProgressBar.sh >/dev/null; then
    if [[ ! -d "$homedir/.local/NRZCode/progressbar" ]]; then
      git clone -q https://github.com/NRZCode/progressbar.git "$homedir/.local/NRZCode/progressbar"
    fi
    mkdir -p "$bindir"
    [[ "$bindir" == @(${PATH//:/|}) ]] || export PATH="$PATH:$bindir"
    ln -sf "$homedir/.local/NRZCode/progressbar/ProgressBar.sh" "$bindir/ProgressBar.sh"
  fi

  if [[ ! -f "$workdir/resources/report.tpl" ]]; then
    mkdir -p "$workdir/resources"
    if [[ -r "$dirname/resources/report.tpl" ]]; then
      cp "$dirname/resources/report.tpl" "$workdir/resources/report.tpl"
    else
      wget -qO "$workdir/resources/report.tpl" https://github.com/NRZCode/GhostRecon/raw/master/resources/report.tpl
    fi
  fi

  if [[ ! -f "$homedir/.local/NRZCode/bash-ini-parser/bash-ini-parser" ]]; then
    git clone -q https://github.com/NRZCode/bash-ini-parser  "$homedir/.local/NRZCode/bash-ini-parser"
  fi
  source "$homedir/.local/NRZCode/bash-ini-parser/bash-ini-parser"
  if [[ ! -f "$inifile" ]]; then
    if [[ -r "$dirname/package.ini" ]]; then
      cp "$dirname/package.ini" "$inifile"
    else
      wget -qO "$inifile" https://github.com/NRZCode/GhostRecon/raw/master/package.ini
    fi
  fi
}

update_tools() {
  echo 'Aguarde um momento...'
  wget -qO "$workdir/resources/report.tpl" https://github.com/NRZCode/GhostRecon/raw/master/resources/report.tpl
  for dir in /usr/local/*; do
    if [[ -d "$dir/.git" ]]; then
      git -C "$dir" pull -q origin master
    fi
  done
}

mklogdir() {
  local logdir=$1
  mkdir -p "$logdir"
  export dtreport=$(date '+%Y%m%d%H%M')
}

dg_menu() {
  dg=(dialog --stdout --title "$title" --backtitle "$backtitle" --checklist "$text" 0 "$width" 0)
  selection=$("${dg[@]}" "${dg_options[@]}")
}

report() {
  local tbody http_domain
  http_domain=($(httprobe <<< "$domain"))
  while read d; do
    tbody+=$(printf "<tr><td><a href='%s'>%s</a></td><td><a href='%s'>%s</a></td></tr>" "$d" "$d" "$http_domain" "$http_domain")
  done < <(sort -u "$logdir/${dtreport}"{sublist3r,subfinder}.log|httprobe)
  datetime=$(date -d "$(sed -E 's/^.{10}/&:/;s/^.{8}/& /;s/^.{6}/&-/;s/^.{4}/&-/;' <<< "$dtreport")")
  dig=$(dig "$domain"|sed -z 's/\n/\\n/g')
  host=$(host "$domain"|sed -z 's/\n/\\n/g')
  whois=$(whois "$domain"|sed -z 's/\n/\\n/g')
  nmap=$(sed -z 's/\n/\\n/g' "$logdir/${dtreport}nmap.log")
  sed "s|{{domain}}|$domain|g;
    s|{{datetime}}|$datetime|;
    s|{{subdomains}}|$tbody|;
    s|{{dig}}|$dig|;
    s|{{host}}|$host|;
    s|{{whois}}|$whois|;
    s|{{nmap}}|$nmap|;" "$workdir/resources/report.tpl" > "$logdir/${dtreport}report.html"
  xdg-open "$logdir/${dtreport}report.html"
}

banner() {
  echo " ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
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
╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
    A Reconaissance Tool's Collection.
------------------------------------------
https://t.me/PeakyBlindersW
https://github.com/NRZCode/GhostRecon
                            version: $APP_VERSION
------------------------------------------
"|/usr/games/lolcat
  [[ $domain ]] && echo "Domain: $domain"
}

usage() { printf "${*:+$*\n}  Usar: $basename -d domain.com\n" 1>&2; return 1; }

init() {
  local OPTIND OPTARG
  load_ansi_colors
  while getopts ":d:v:u" opt; do
    case $opt in
         d) domain=$OPTARG;;
         v) [[ $OPTARG == 'v' ]] && verbose_mode=1;;
         u) ;;
         :) usage "Opção -$OPTARG requer parâmetro.";;
      \?|*) usage "Opção -$OPTARG desconhecida (?)";;
    esac
  done
  shift $((OPTIND - 1))

  while [ -z "$domain" ]; do
    banner
    read -p 'Enter domain: ' domain
#    if ! checkArgType domain domain "$domain"; then echo "$domain INVALIDO"; domain=''; fi
  done
  export domain="$(shopt -s extglob; echo ${domain#http?(s)://})"

  if [ -z "$domain" ]; then
    usage; exit 1;
  fi
}

run() {
  export logdir=${logdir:-$workdir/$domain}
  export logerr="$workdir/${basename%.*}.err"
  mklogdir "$logdir"

  backtitle="Reconnaissence tools [$APP]"
  title="Reconhecimento do alvo [$domain]"
  text='Selecione as ferramentas:'
  width=0
  if dg_menu checklist; then
    clear
    anonsurf start &> /dev/null

    banner
    # Tools for report
    for tool in sublist3r subfinder nmap ${selection,,}; do
      anonsurf change &> /dev/null
      IFS='|' read app depends anon cmd <<< ${tools[$tool]}
      if type -t $depends > /dev/null; then
        [[ ${anon,,} == @(off|0|false) ]] && { anonsurf stop &> /dev/null; sleep 8; }
        printf "\n\n${CBold}${CFGYellow}[${CFGRed}+${CFGYellow}] Iniciando ${app}${CReset}\n"
        export logfile="$logdir/${dtreport}${tool}.log"
        result=$(bash -c "$cmd 2>>$logerr") | ProgressBar.sh -s slow
        printf 'Relatório de %s salvo em %s\n=====\n' "$tool" "$logfile"
        [[ ${anon,,} == @(off|0|false) ]] && anonsurf start &> /dev/null
      fi
    done
    anonsurf stop &> /dev/null
    report
    return
  fi

  clear
}

main() {
  script=$(realpath $BASH_SOURCE)
  dirname=${script%/*}
  readonly basename=${0##*/}
  [[ $1 == @(-h|--help|help) ]] && { usage; exit 0; }
  [[ $1 == @(-V|--version) ]] && { echo "$APP_VERSION"; exit 0; }
  if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    printf '%s: ERROR: Necessário shell %s %s ou superior.\n' "$basename" 'bash' '4.0' 1>&2
    exit 1
  fi
  if [[ 0 != $EUID ]]; then
    printf 'This script must be run as root!\nRun as:\n$ sudo ./%s\n' "$basename $*"
    exit 1
  fi
  homedir=$HOME
  if [[ $SUDO_USER ]]; then
    SUDO_OPT="-H -E -u $SUDO_USER"
    homedir=$(getent passwd $SUDO_USER|cut -d: -f6)
  fi
  workdir=$homedir/.local/${basename%.*}
  inifile="$workdir/package.ini"
  check_dependencies

  read_package_ini
  unset descriptions[nmap] descriptions[sublist3r] descriptions[subfinder]
  mapfile -t dg_options < <(for tool in "${!descriptions[@]}"; do IFS='|' read t d <<< "${descriptions[$tool]}"; printf '%s\n%s\nON\n' "$t" "$d"; done)

  [[ $1 == @(-u|--update) ]] && update_tools
  init "$@"
  run
}

declare -A tools
declare -A descriptions
[[ $BASH_SOURCE == $0 ]] && main "$@"
