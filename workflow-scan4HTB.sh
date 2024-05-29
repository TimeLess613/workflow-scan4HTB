#!/usr/bin/bash
# -*- coding:utf-8 -*-

## Usage: sudo bash workflow-scan4HTB.sh <HTB_IP>

set -eu

HTB_IP=${1}
info_YT_BB='\033[33;44m[info]\033[0m'    # yellow text blue background


echo -e "${info_YT_BB} Starting ports scan..."
nmap -Pn -n -sT --reason -p- --min-rate=5000 ${HTB_IP} | tee "${HTB_IP}_ports_all.nmap"
nmap -Pn -n -sT --reason -p- --min-rate=5000 ${HTB_IP} | tee "${HTB_IP}_ports_all2.nmap"    ## Just in case

if [[ $(diff "${HTB_IP}_ports_all.nmap" "${HTB_IP}_ports_all2.nmap") ]]; then
  exit 1
else
  echo -e "${info_YT_BB} Starting base scan..."
  ports=$(grep 'open' "${HTB_IP}_ports_all.nmap" | cut -d '/' -f1 | paste -sd ',')
  nmap -v -Pn -n -sT -sV -O -p ${ports} ${HTB_IP} | tee "${HTB_IP}_baseScan.nmap"
  echo -e "${info_YT_BB} Base scan is Done."
  
  echo -e "${info_YT_BB} Starting sC & vuln scan for ports < 5000..."
  ports_lt5000=$(grep 'open' "${HTB_IP}_ports_all.nmap" | cut -d '/' -f1 | awk '$1 < 5000' | paste -sd ',')
  nohup nmap -v -Pn -n -p ${ports_lt5000} -sC ${HTB_IP} > "${HTB_IP}_NSE-sC.nmap" 2>&1 &
  nohup nmap -v -Pn -n -p ${ports_lt5000} --script=vuln ${HTB_IP} > "${HTB_IP}_NSE-vuln.nmap" 2>&1 &
  echo -e "${info_YT_BB} Running NSE vuln scan background..."
  
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
  
      echo -e "${info_YT_BB} -------- Add HTB_DOMAIN( ${HTB_DOMAIN} ) to hosts --------"
      echo "${HTB_IP}    ${HTB_DOMAIN}" >> /etc/hosts
      echo -e "${info_YT_BB} -------- Show now hosts --------"
      cat -e /etc/hosts | tail -n 5
  
      echo -e "${info_YT_BB} Scanning subdomain..."
      gobuster vhost -u ${HTB_DOMAIN} -w /usr/share/wordlists/amass/subdomains.lst -t 10 --append-domain -o "subdomains_${HTB_DOMAIN}.txt"
      echo -e "${info_YT_BB} Subdomain scan is Done."
    fi
  fi
  
  echo -e "${info_YT_BB} ==============================================="
  echo -e "${info_YT_BB} The NSE scan maybe still running..."
  echo -e "${info_YT_BB} Show ps..."
  ps -ef | grep 'nmap -v '
  echo -e "${info_YT_BB} ==============================================="
  echo -e "${info_YT_BB} If it's still running, please check status with command: ps -ef | grep 'nmap -v -Pn -n'"
  ps -ef | grep 'nmap -v -Pn -n'
  echo -e "${info_YT_BB} Maybe next step for dir-enum with feroxbuster/gobuster/fuff: feroxbuster -u http://${HTB_IP}/ -w /usr/share/wordlists/dirb/big.txt -x php,txt"
fi
