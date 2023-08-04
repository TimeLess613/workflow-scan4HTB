#!/usr/bin/bash
# -*- coding:utf-8 -*-

## Usage: sudo bash ~/workflow-scan4HTB/workflow-scan4HTB.sh <HTB_IP>

set -eu

HTB_IP=${1}
YT_BB='\033[33;44m'    # yellow text blue background
RS='\033[0m'           # reset style


echo -e "${YT_BB}[info]${RS} Starting ports scan..."
nmap -Pn -n -sT -p- --min-rate=10000 ${HTB_IP} | tee "${HTB_IP}_ports_all.nmap"

echo -e "${YT_BB}[info]${RS} Starting base scan..."
ports=$(grep 'open' "${HTB_IP}_ports_all.nmap" | cut -d '/' -f1 | paste -sd ',')
nmap -v -Pn -n -sT --reason -sV -O -p ${ports} ${HTB_IP} | tee "${HTB_IP}_baseScan.nmap"
echo -e "${YT_BB}[info]${RS} Base scan is Done."

echo -e "${YT_BB}[info]${RS} Starting sC & vuln scan for ports < 5000..."
ports_lt5000=$(grep 'open' "${HTB_IP}_ports_all.nmap" | cut -d '/' -f1 | awk '$1 < 5000' | paste -sd ',')
nohup nmap -v -Pn -n -p ${ports_lt5000} --script=vuln ${HTB_IP} > "${HTB_IP}_NSE-vuln.nmap" 2>&1 &
echo -e "${YT_BB}[info]${RS} Running NSE vuln scan background..."

echo -e "${YT_BB}[info]${RS} ==============================================="

echo -e "${YT_BB}[info]${RS} Checking if there is domain for add to hosts..."
HEADER_Location=$(curl -m 3 -I ${HTB_IP} | grep "Location:" || true)

if [[ ${HEADER_Location} != '' ]];then
  HTB_DOMAIN=$(echo ${HEADER_Location} | cut -d '/' -f 3)
  echo -e "${YT_BB}[info]${RS} HTB_DOMAIN: ${HTB_DOMAIN}"

  if [[ ${HTB_DOMAIN} != '' ]];then
    # shows for backup
    echo -e "${YT_BB}[info]${RS} -------- Back up hosts --------"
    cat -e /etc/hosts
    echo -e "${YT_BB}[info]${RS} -------- Backed up hosts --------"

    echo -e "${YT_BB}[info]${RS} -------- Add HTB_DOMAIN(${HTB_DOMAIN}) to hosts --------"
    echo "${HTB_IP}    ${HTB_DOMAIN}" >> /etc/hosts
    echo -e "${YT_BB}[info]${RS} -------- Modified hosts --------"

    echo -e "${YT_BB}[info]${RS} -------- Show now hosts --------"
    cat -e /etc/hosts

#     echo -e "${YT_BB}[info]${RS} Scanning subdomain..."
#     gobuster vhost -u ${HTB_DOMAIN} -w /usr/share/wordlists/amass/bitquark_subdomains_top100K.txt -t 100 --append-domain -o "subdomains_${HTB_DOMAIN}.txt"
#     echo -e "${YT_BB}[info]${RS} Subdomain scan is Done."
  fi
fi

echo -e "${YT_BB}[info]${RS} ==============================================="
echo -e "${YT_BB}[info]${RS} The NSE-vuln scan maybe still running..."
echo -e "${YT_BB}[info]${RS} Show ps..."
ps -ef | grep 'nmap -v '
echo -e "${YT_BB}[info]${RS} ==============================================="
echo -e "${YT_BB}[info]${RS} If it's still running, please check status with command: ps -ef | grep 'nmap -v -Pn -n'"
