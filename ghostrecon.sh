#!/usr/bin/env bash
#
APP='Ghost Recon'
version=0.0.15

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

progressbar() {
  local progressbar="$workdir/vendor/NRZCode/progressbar/ProgressBar.sh"
  [[ -x "$progressbar" && -z $APP_DEBUG ]] && $progressbar "$@" || cat
}

elapsedtime() {
  code=$?

  printtime=$SECONDS
  [[ $1 == '-p' ]] && {
    ((printtime=SECONDS - partialtime))
    partialtime=$SECONDS
    shift
  }

  status=SUCCESS
  color=${CFGGreen}
  color_status='\e[92m'
  [[ $code -ne 0 ]] && {
    status=ERROR
    color=${CFGRed}
    color_status='\e[91m'
  }

  fmt='+%_Mmin %_Ss'
  [[ $printtime -ge 3600 ]] && fmt='+%_Hh %_Mmin %_Ss'
  elapsed_time=$(date -u -d "@$printtime" "$fmt")

  printf "${CBold}%b%s complete with %b%s%b in %s${CReset}\n" \
    "$color" \
    "$1" \
    "$color_status" \
    "$status" \
    "$color" \
    "${elapsed_time//  / }"
}

cfg_listsections() {
  local file=$1
  grep -oP '(?<=^\[)[^]]+' "$file"
}

read_package_ini() {
  cfg_parser "$inifile"
  while read sec; do
    unset description depends command
    cfg_section_$sec 2>&-
    if [[ $command ]]; then
      descriptions[${sec,,}]="$sec|$description"
      tools[${sec,,}]="$sec|$depends|$command"
    fi
  done < <(cfg_listsections "$inifile")
}

check_dependencies() {
  local pkg='git'
  local ver='2.17.1'

  if ! type -t $pkg >/dev/null; then
    printf '%s: ERROR: Necessário pacote %s %s ou superior.\n' "$basename" "$pkg" "$ver" 1>&2
    exit 1
  fi

  source "$workdir/vendor/NRZCode/bash-ini-parser/bash-ini-parser"
}

check_inifile() {
  if [[ ! -r "$inifile" ]]; then
    [[ -r "$workdir/package-dist.ini" ]] &&
      cp "$workdir"/package{-dist,}.ini ||
      wget -qO "$workdir/package.ini" https://github.com/NRZCode/GhostRecon/raw/master/package-dist.ini
  fi
  [[ -r "$inifile" ]] || exit 1
}

check_environments() {
  if [[ ! -r "$workdir/.env" ]]; then
    [[ -r "$workdir/.env-dist" ]] &&
      cp "$workdir"/.env{-dist,}
  fi
  [[ -r "$workdir/.env" ]] && source "$workdir/.env"
}

update_tools() {
  echo 'Aguarde um momento...'
  git -C "$workdir" pull --all
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

report_tools() {
  tools[mrx]='MRX|subfinder findomain-linux assetfinder|for log in "$logdir/"{assetfinder,findomain,sub{finder}}.log; do > "$log"; done; sleep 10;findomain-linux -t "$domain" -q -o "$logdir/findomain.log"; sleep 10; subfinder -d "$domain" -silent -o "$logdir/subfinder.log"; sleep 10; assetfinder -subs-only "$domain" > "$logdir/assetfinder.log"; sort -u "$logdir/"{assetfinder,findomain,sub{finder}}.log -o "$logfile"; httpx -silent < "$logfile" > "$logdir/${dtreport}httpx.log"'
  tools[dirsearch]='Dirsearch|dirsearch|xargs -L1 dirsearch -q -e php,asp,aspx,jsp,html,zip,jar -x 404-499,500-599 -w "$dicc" --timeout 3 --random-agent -t 50 -o "$logfile" -u < <(httpx -silent <<< "$domain")'
  tools[feroxbuster]='Feroxbuster|feroxbuster|feroxbuster -q -x php,asp,aspx,jsp,html,zip,jar -t 80 -r -k -w "$dicc" -o "$logfile" -u "$domain"'
  tools[whatweb]='Whatweb|whatweb|whatweb -a 3 -q --no-errors "$domain" --log-brief="$logfile"'
  tools[theHarvester]='TheHarvester|theHarvester|theHarvester -d "$domain" > "$logfile"'
  tools[owasp]='OWASP|httpx gau|httpx -l "$logdir/${dtreport}mrx.log" -silent | gau --subs -o "$logfile"'
  tools[curl]='cURL|curl|curl -s https://crt.sh/?q=%25.$domain&output=json | anew -q "$logfile"'
}

report() {
  local tbody
  datetime=$(date -d "$(sed -E 's/^.{10}/&:/;s/^.{8}/& /;s/^.{6}/&-/;s/^.{4}/&-/;' <<< "$dtreport")")
  download=${dtreport}${domain}.zip
  ##
  # Page reports
  side=1
  page=2
  while read paginate; do
    printf -v report '%sreport-%02d.html' $dtreport $page
    pagination+="<a style='margin-left: 1em' href='$report'>Página $((page++))</a>"
    (
      sed "s|{{datetime}}|$datetime|;
        s|{{download}}|$download|;
        s|{{domain}}|$domain|g" "$workdir/resources/pagereport.tpl"
      while read tools; do
        for t in $tools; do
          echo -n "<div><h2>$t</h2></div><pre>$(<${pagereports[$t]})</pre>"
        done
        ((side % 2)) && echo -n '</div></article><article class="post-container-right" itemscope="" itemtype="http://schema.org/BlogPosting"><header class="post-header"></header><div class="post-content clearfix" itemprop="articleBody">'
        ((side++))
      done < <(xargs -n3 <<< $paginate)
      echo '</div></article></div></div></div></body></html>'
    ) > "$logdir/$report"
  done < <(xargs -n6 <<< ${!pagereports[@]})
  [[ $pagination ]] && pagination="<a style='margin-left: 1em' href='report.html'>Página 1</a>$pagination"
  ##
  # Subdomains reports
  while read subdomain && [[ $subdomain ]]; do
    logfile="$logdir/${dtreport}${subdomain/:\/\//.}.log"
    n=$(($([[ -f "$logfile" ]] && wc -l < "$logfile" 2>&-)))
    href='#'
    if [[ $n -gt 0 ]]; then
      href="${dtreport}${subdomain/:\/\//.}.html"
      host=$(host "${subdomain#@(ht|f)tp?(s)://}"|sed -z 's/\n/\\n/g')
      nmap=$(sed -z 's/\n/\\n/g' "$logdir/${dtreport}${subdomain#@(ht|f)tp?(s)://}nmap.log")
      screenshots=$(
      for f in $logdir/screenshots/*${subdomain//./_}*png; do
        re="(https?)__${subdomain//./_}__(([0-9]+)__)?[[:alnum:]]+\.png"
        if [[ $f =~ $re ]]; then
          if [[ ${BASH_REMATCH[1]} == https ]]; then
            port=443
          elif [[ ${BASH_REMATCH[1]} == http ]]; then
            port=80
          fi
          port=${BASH_REMATCH[4]:-$port}
          printf '<div class="column">Port %d<a href="%s"><img src="%s"></a></div>' \
            "$port" \
            "screenshots/${f##*/}" \
            "screenshots/${f##*/}"
        fi
      done
      )
      response_headers=$(
      for f in "$logdir/"headers/*${subdomain//./_}*txt; do
        if [[ -f "$f" ]]; then
          printf "==> $f <==\n$(<$f)\n"
        fi
      done
      )
      (
        sed '1,/{{subdomains}}/!d; s/{{subdomains}}.*/\n/' "$workdir/resources/subreport.tpl"
        while read code method lines words chars url; do
          url=$(sed -E 's_((ht|f)tps?[^[:space:]]+)_<a href="\1" target="_blank">\1</a>_g' <<< "$url")
          printf '<tr><td>%s</td><td>%s</td><td>%s</td></tr>' "$code" "$lines $words $chars" "$url"
        done < <(grep -Ev '^(#|$)' "$logfile")
        sed '/{{subdomains}}/,$!d; s/.*{{subdomains}}/\n/' "$workdir/resources/subreport.tpl"
      ) > "$logdir/$href"
      sed -i "s|{{domain}}|$subdomain|g;
        s|{{datetime}}|$datetime|;
        s|{{screenshots}}|$screenshots|;
        s|{{response-headers}}|$response_headers|;
        s|{{nmap}}|$nmap|;
        s|{{host}}|$host|;" "$logdir/$href"
    fi
    tbody+=$(printf "<tr><td><a href='%s'>%s</a></td><td>%s</td></tr>" "$href" "$subdomain" "$n")
  done < "$logdir/${dtreport}httpx.log"
  ##
  # Domain report
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
    s|{{download}}|$download|;
    s|{{pagination}}|$pagination|;
    s|{{nmap}}|$nmap|;" "$workdir/resources/report.tpl" > "$logdir/${dtreport}report-01.html"
  ##
  # Compact reports
  cp $logdir/${dtreport}report-01.html $logdir/report.html
  cd "$logdir"
  zip -q -r ${dtreport}${domain}.zip ${dtreport}*html report.html screenshots/ headers/
  xdg-open "$logdir/${dtreport}report-01.html" &
  ##
  # Menu reports
  btview='<a href="%s" class="mdl-cell mdl-cell--6-col-desktop mdl-cell--4-col-tablet mdl-cell--2-col-phone"><button class="mdl-button mdl-js-button mdl-js-ripple-effect mdl-button--icon" data-upgraded=",MaterialButton,MaterialRipple"><i class="material-icons">insert_chart</i><span class="mdl-button__ripple-container"><span class="mdl-ripple"></span></span></button>Visualizar</a>'
  btdownload='<a href="%s" class="mdl-cell mdl-cell--6-col-desktop mdl-cell--4-col-tablet mdl-cell--2-col-phone"><button class="mdl-button mdl-js-button mdl-js-ripple-effect mdl-button--icon" data-upgraded=",MaterialButton,MaterialRipple"><i class="material-icons">file_download</i><span class="mdl-button__ripple-container"><span class="mdl-ripple"></span></span></button>Download</a>'
  rows=$(
  for domain in $workdir/log/*; do
    for report in $domain/*; do
      if [[ ${report##*/} =~ ^(([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})).* ]]; then
        echo  "${domain##*/}/${BASH_REMATCH[1]}"
      fi
    done
  done | sort -u
  )
  reports=$(
  while read report; do
    domain=${report%%/*}
    if [[ $report =~ (([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})) ]]; then
      printf -v bt1 "$btview" "$domain/${BASH_REMATCH[1]}report-01.html"
      printf -v bt2 "$btdownload" "$domain/${BASH_REMATCH[1]}.zip"
      printf '<tr><td><a href="%s">%s %s/%s/%s %s:%s</a></td><td>%s %s</td></tr>' \
        "$domain/${BASH_REMATCH[1]}report-01.html" \
        "$domain" "${BASH_REMATCH[4]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[5]}" "${BASH_REMATCH[6]}" \
        "$bt1" "$bt2"
    fi
  done <<< "$rows"
  )
  sed "s|{{reports}}|$reports|;" "$workdir/resources/menu.tpl" > "$workdir/log/menu.html"
  xdg-open "$workdir/log/menu.html" &
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
                            version: $version
------------------------------------------
    Discord Community
 https://discord.gg/Z2C2CyVZFU

Recode The Copyright Is Not Make You A Coder Dude
"|/usr/games/lolcat
  [[ $domain ]] && echo "Domain: $domain"
}

usage() {
  usage="  Usage: $basename [OPTIONS]

DESCRIPTION
  GhostRecon is a based script for reconaissance domains

OPTIONS
  General options:
    -d,--domain        Domain to find subdomains for
    -a,--anon          Setup usage of anonsurf change IP (Default: On)
    -V,--version       Print current version GhostRecon
    -u,--update        Update ghostrecon for better performance
    -h,--help          Show this help message and exit"
  printf "${*:+$*\n}$usage\n"
  return 1
}

init() {
  local OPTIND OPTARG
  load_ansi_colors

  while [ -z "$domain" ]; do
    banner
    read -p 'Enter domain: ' domain
#    if ! checkArgType domain domain "$domain"; then echo "$domain INVALIDO"; domain=''; fi
  done
  export domain=${domain#@(ht|f)tp?(s)://}

  if [ -z "$domain" ]; then
    usage; exit 1;
  fi
}

user_notification() {
  notify-send -u critical -i bash 'GhostRecon Reconnaissance' "Recon de $domain concluído"
}

run_tools() {
  for tool; do
    [[ $anon_mode == 1 ]] && anonsurf change &> /dev/null
    IFS='|' read app depends cmd <<< ${tools[$tool]}
    if type -t $depends > /dev/null; then
      printf "\n\n${CBold}${CFGCyan}[${CFGWhite}+${CFGCyan}] Starting ${app}${CReset}\n"
      export logfile="$logdir/${dtreport}${tool}.log"; > $logfile
      pagereports[$tool]="$logfile"
      result=$(bash -c "$cmd" 2>>$logerr) | progressbar -s slow -m "${tool^} $domain"
      elapsedtime -p "${tool^}"
    fi
  done
}

run() {
  export logdir=${logdir:-$workdir/log/$domain}
  export logerr="$workdir/${basename%.*}.err"
  mklogdir "$logdir"

  backtitle="Reconnaissence tools [$APP]"
  title="Target's Reconnaissence [$domain]"
  text='Select tools:'
  width=0
  if dg_menu checklist; then
    clear
    [[ $anon_mode == 1 ]] && anonsurf start &> /dev/null

    banner

    # Tools for report
    run_tools mrx nmap whatweb theHarvester curl owasp ${selection,,}

    ##
    # Search and report subdomains
    printf "\n\n${CBold}${CFGCyan}[${CFGWhite}+${CFGCyan}] Starting Scan on Subdomains${CReset}\n"
    aquatone -chrome-path /usr/bin/chromium -scan-timeout 500 -screenshot-timeout 300000 -http-timeout 30000 -out "$logdir" -threads 5 -silent 2>>$logerr >/dev/null < "$logdir/${dtreport}mrx.log"
    IFS='|' read app depends cmd <<< ${tools[feroxbuster]}
    (
      while read domain; do
        logfile="$logdir/${dtreport}${domain/:\/\//.}.log"
        result=$(bash -c "$cmd" 2>>$logerr) | progressbar -s slow -m "Feroxbuster $domain"
      done < "$logdir/${dtreport}httpx.log"
    )

    IFS='|' read app depends cmd <<< ${tools[nmap]}
    (
      while read domain; do
        logfile="$logdir/${dtreport}${domain}nmap.log"
        result=$(bash -c "$cmd" 2>>$logerr) | progressbar -s normal -m "NMAP $domain"
      done < "$logdir/${dtreport}mrx.log"
    )
    report

    [[ $anon_mode == 1 ]] && anonsurf stop &> /dev/null
    user_notification
    elapsedtime 'TOTAL Reconaissance'
    return 0
  fi

  clear
}

main() {
  script=$(realpath $BASH_SOURCE)
  dirname=${script%/*}
  readonly basename=${0##*/}
  while [[ $1 ]]; do
    case $1 in
      -h|--help|help) usage; exit 0;;
      -V|--version) echo "$version"; exit 0;;
      -u|--update) update_mode=1; shift;;
      -d|--domain) domain=$2; shift 2;;
      -a|--anon) [[ ${2,,} == @(0|false|off) ]] && anon_mode=0; shift 2;;
      *) shift;;
    esac
  done
  if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    printf '%s: ERROR: Need shell %s %s or greater.\n' "$basename" 'bash' '4.0' 1>&2
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
  workdir=$dirname
  inifile="$workdir/package.ini"

  check_dependencies
  check_inifile
  check_environments

  SECONDS=0
  read_package_ini
  report_tools
  # Ferramentas não selecionáveis
  # nmap sublist3r subfinder assetfinder amass
  mapfile -t dg_options < <(for tool in "${!descriptions[@]}"; do IFS='|' read t d <<< "${descriptions[$tool]}"; printf "%s\n%s\n$dg_checklist_mode\n" "$t" "$d"; done)

  [[ $update_mode == 1 ]] && update_tools
  shopt -s extglob
  init
  run
}

declare -A tools
declare -A descriptions
declare -A pagereports
dg_checklist_mode=${dg_checklist_mode:-OFF}
anon_mode=1
[[ $BASH_SOURCE == $0 ]] && main "$@"
