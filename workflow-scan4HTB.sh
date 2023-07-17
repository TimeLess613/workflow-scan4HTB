#!/usr/bin/bash
# -*- coding:utf-8 -*-

## Usage: sudo bash ~/workflow-scan4HTB/workflow-scan4HTB.sh <HTB_IP>

set -eu

HTB_IP=${1}

echo "[info] Starting ports scan..."
nmap -Pn -n -sT --reason -p- --min-rate=10000 ${HTB_IP} | tee "${HTB_IP}_ports_all.nmap"

echo "[info] Starting base scan..."
ports=$(grep 'open' "${HTB_IP}_ports_all.nmap" | cut -d '/' -f1 | paste -sd ',')
nmap -v -Pn -n -sT -sV -O -p ${ports} ${HTB_IP} | tee "${HTB_IP}_baseScan.nmap"
echo "[info] Base scan is Done."

echo "[info] Starting NSE vuln scan for ports < 5000..."
ports_lt5000=$(grep 'open' "${HTB_IP}_ports_all.nmap" | cut -d '/' -f1 | awk '$1 < 5000' | paste -sd ',')
nohup nmap -v -Pn -n -p ${ports} --script=vuln ${HTB_IP} > "${HTB_IP}_NSE-vuln.nmap" 2>&1 &
echo "[info] Running NSE vuln scan background..."

echo "[info] ==============================================="

echo "[info] Checking if there is domain for add to hosts..."
HEADER_Location=$(curl -m 3 -I ${HTB_IP} | grep -q "Location:" || true)

if [[ ${HEADER_Location} != '' ]];then
  HTB_DOMAIN=$(echo ${HEADER_Location} | grep -oP '(?<=Location: http://).*' | tr -d '/\r')
  echo "[info] HTB_DOMAIN: ${HTB_DOMAIN}"

  if [[ ${HTB_DOMAIN} != '' ]];then
    # shows for backup
    echo "[info] -------- Back up hosts --------"
    cat -e /etc/hosts
    echo "[info] -------- Backed up hosts --------"

    echo "[info] -------- Add HTB_DOMAIN(${HTB_DOMAIN}) to hosts --------"
    echo "${HTB_IP}    ${HTB_DOMAIN}" >> /etc/hosts
    echo "[info] -------- Modified hosts --------"

    echo "[info] -------- Show now hosts --------"
    cat -e /etc/hosts

#     echo "[info] Scanning subdomain..."
#     gobuster vhost -u ${HTB_DOMAIN} -w /usr/share/wordlists/amass/bitquark_subdomains_top100K.txt -t 100 --append-domain -o "subdomains_${HTB_DOMAIN}.txt"
#     echo "[info] Subdomain scan is Done."
  fi
fi

echo "[info] ==============================================="
echo "[info] The NSE-vuln scan maybe still running..."
echo "[info] Show ps..."
ps -ef | grep 'nmap -v '
echo "[info] ==============================================="
echo "[info] If it's still running, please check status with command: ps -ef | grep 'nmap -v -Pn -n'"
