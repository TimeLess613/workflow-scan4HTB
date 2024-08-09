#!/usr/bin/bash
# -*- coding:utf-8 -*-

## Usage: sudo bash workflow-scan4HTB.sh <HTB-MachineName> <HTB_IP>

set -eu

WORK_DIR="/home/kali/HTB/${1}/infoG/initscan"
HTB_IP=${2}

info_YT_BB='\033[33;44m[info]\033[0m'    # yellow text blue background

echo -e "${info_YT_BB} Create and move to WORK_DIR: ${WORK_DIR}"
mkdir -p "$WORK_DIR"
cd $WORK_DIR

echo -e "${info_YT_BB} Starting ports scan..."
nmap -Pn -n -sT --reason -p- --min-rate=5000 ${HTB_IP} -oA "${HTB_IP}_ports_all"
nmap -Pn -n -sT --reason -p- --min-rate=5000 ${HTB_IP} -oA "${HTB_IP}_ports_all2"    ## Just in case

file1="${HTB_IP}_ports_all.nmap"
file2="${HTB_IP}_ports_all2.nmap"

set +e
diff <(fgrep open $file1 | cut -d ' ' -f1) <(fgrep open $file2 | cut -d ' ' -f1)
diff_status=$?
set -e

if [ ${diff_status} -eq 0 ]; then
  selected_file="$file1"
  echo -e "${info_YT_BB} Same result about open ports, use $selected_file to do next step..."
else
  echo "Select a results file to do next step:"
  echo "1) $file1"
  echo "2) $file2"
  echo "0) Exit this script."
  
  while true; do
    read -p "Enter your choice with number: " choice
    case $choice in
      0)
        echo "Exit this script."
        exit 0
        ;;
      1)
        selected_file="$file1"
        break
        ;;
      2)
        selected_file="$file2"
        break
        ;;
      *)
        echo "Invalid choice. Choice 0,1,2."
        ;;
    esac
  done
fi

echo -e "${info_YT_BB} Starting base scan using ${selected_file}..."
ports=$(grep 'open' "${selected_file}" | cut -d '/' -f1 | paste -sd ',')
nmap -v -Pn -n -sT -sV -O -p ${ports} ${HTB_IP} -oA "${HTB_IP}_baseScan"
echo -e "${info_YT_BB} Base scan is Done."

echo -e "${info_YT_BB} Starting sC & vuln scan for ports < 5000 on background..."
ports_lt5000=$(grep 'open' "${selected_file}" | cut -d '/' -f1 | awk '$1 < 5000' | paste -sd ',')
nmap -v -Pn -n -p ${ports_lt5000} -sC ${HTB_IP} -oA "${HTB_IP}_NSE-sC" > /dev/null 2>&1 &
nmap -v -Pn -n -p ${ports_lt5000} --script=vuln ${HTB_IP} -oA "${HTB_IP}_NSE-vuln" > /dev/null 2>&1 &

echo -e "${info_YT_BB} ==============================================="
echo -e "${info_YT_BB} Checking if there is domain for add to hosts..."
HEADER_Location=$(curl -s -m 3 -I ${HTB_IP} | grep "Location:" || true)

if [[ ${HEADER_Location} != '' ]];then
  HTB_DOMAIN=$(echo ${HEADER_Location} | cut -d '/' -f 3 | tr -d '\r')
  echo -e "${info_YT_BB} HTB_DOMAIN: ${HTB_DOMAIN}"

  if [[ ${HTB_DOMAIN} != '' ]];then
    # shows for backup
    echo -e "${info_YT_BB} -------- Back up hosts --------"
    cat -e /etc/hosts
    echo -e "${info_YT_BB} -------- Back-ed up hosts --------"

    echo -e "${info_YT_BB} ... Adding HTB_DOMAIN( ${HTB_DOMAIN} ) to hosts..."
    echo "${HTB_IP}    ${HTB_DOMAIN}" >> /etc/hosts
    echo -e "${info_YT_BB} -------- Show now hosts --------"
    cat -e /etc/hosts | tail -n 5

    echo -e "${info_YT_BB} Scanning subdomain..."
    gobuster vhost -u ${HTB_DOMAIN} -w /usr/share/wordlists/amass/subdomains.lst -t 10 --append-domain -o "subdomains_${HTB_DOMAIN}.txt"
    echo -e "${info_YT_BB} Subdomain scan is Done."
  fi
fi

echo -e "${info_YT_BB} Running whatweb..."
whatweb ${HTB_DOMAIN:-$HTB_IP} | tee whatweb_${HTB_DOMAIN:-$HTB_IP}.txt

echo -e "${info_YT_BB} Maybe next step for dir-enum with feroxbuster/gobuster/fuff: feroxbuster -u http://${HTB_DOMAIN:-$HTB_IP}/ -t 32 -w /usr/share/wordlists/dirb/big.txt -o dirEnum_${HTB_DOMAIN:-$HTB_IP}.txt -x php,txt"

echo -e "${info_YT_BB} ==============================================="
ps -ef | grep 'nmap -v -Pn -n'
echo -e "${info_YT_BB} The NSE scan maybe still running on background. Waiting..."
wait

mkdir nmap_other_format
mv *.gnmap nmap_other_format
mv *.xml nmap_other_format
