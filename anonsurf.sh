#!/bin/bash

#
# Author: Christian Benitez
# License: MIT
#

VERSION=1.0.0

# Colors
greenColor="\033[0;32m\033[1m"
redColor="\033[0;31m\033[1m"
blueColor="\033[0;34m\033[1m"
yellowColor="\033[0;33m\033[1m"
purpleColor="\033[0;35m\033[1m"
turquoiseColor="\033[0;36m\033[1m"
grayColor="\033[0;37m\033[1m"
endColor="\033[0m\033[0m"

# Main function 
main() {
  # clean console
  clear
  
  ARG=$1
  if [ -z "$ARG" ]; then 
    usage
    exit 1
  fi

  # Options
  while getopts "hsvx" opt; do
    case ${opt} in
      h )
        usage
        exit 0
        ;;
      s )
        startAnonSurf
        ;;
      v )
        header
        echo -e "\n${blueColor}[*] Version: ${VERSION}${endColor}"
        ;;
      x )
        stopAnonSurf
        ;;
    esac
  done
  shift $((OPTIND -1))
}


# Help and how to use
usage(){
  header
  echo -e "${blueColor}Version: ${VERSION}${endColor}\n"
  echo -e "${yellowColor}usage: anonsurf <args>\n"
  echo "   Available args:"
  echo "       Available args are:"
  echo "         help       -h    Shows help."
	echo "         start      -s    Start the service and the necessary settings to browse anonymously."
	echo "         stop       -x    Stop running services and restore default settings."
	echo "         version    -v    Show version."
  echo -e "${endColor}"
}

# Logo header, info, author
header(){
echo 
echo -e "${purpleColor}
                              _____             __ 
     /\                      / ____|           / _|
    /  \   _ __   ___  _ __ | (___  _   _ _ __| |_ 
   / /\ \ | '_ \ / _ \| '_ \ \___ \| | | | '__|  _|
  / ____ \| | | | (_) | | | |____) | |_| | |  | |  
 /_/    \_\_| |_|\___/|_| |_|_____/ \__,_|_|  |_|  
                                                   
                                                   
  Author: Christian Benitez${endColor}"
echo 
}

# Start the service and the necessary settings to browse anonymously.
startAnonSurf(){
  header

  echo -e "${yellowColor}[*]${endColor} Disabling network service"
  echo -e "   ${blueColor}...Network Manager stopping...${endColor}"
  if command -v network-manager > /dev/null 2>&1; then
    sudo service network-manager stop
  else
    echo -e "   ${redColor}[X]${endColor} Network Manager is not installed"
  fi
  echo 

  echo -e "${yellowColor}[*]${endColor} Configuring the network interface to use Tor"
  echo -e "   ${blueColor}[-]${endColor} eth0: ${greenColor}10.0.2.15${endColor}"
  echo -e "   ${blueColor}[-]${endColor} netmask: ${greenColor}255.255.255.0${endColor}"
  sudo ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
  echo 

  echo -e "${yellowColor}[*]${endColor} Configuring network routes to redirect all traffic through Tor"
  echo -e "   ${blueColor}[-]${endColor} gw: ${greenColor}10.0.2.2${endColor}"
  sudo route add default gw 10.0.2.2 2>/dev/null
  echo 

  echo -e "${yellowColor}[*]${endColor} Verifying the Tor service"
  if command -v tor > /dev/null 2>&1; then
    echo -e "   ${blueColor}[!]${endColor} Tor is installed"
  else
    echo -e "   ${redColor}[X]${endColor} Tor is not installed, please install it to continue"
    exit 1
  fi
  TOR_STATUS=$(sudo service tor status | grep Active | awk -F' ' '{print($2)}')
  echo -e "   ${blueColor}[-]${endColor} Tor: ${greenColor}${TOR_STATUS}${endColor}"
  if [ "inactive" == "${TOR_STATUS}" ]; then
    sudo service tor start
    TOR_STATUS=$(sudo service tor status | grep Active | awk -F' ' '{print($2)}')
    echo -e "   ${blueColor}[-]${endColor} Tor: ${greenColor}${TOR_STATUS}${endColor}"
  else
    echo -e "   ${blueColor}[-]${endColor} Tor: ${grayColor}restarting${endColor}"
    sudo service tor restart
  fi
  echo 

  echo -e "${yellowColor}[*]${endColor} Configuring iptables"
  sudo iptables -F
  sudo iptables -t nat -F
  sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 9050
  sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 9050
  TITLE=$(sudo iptables -L -n -t nat | grep -m 1 target)
  RESULT=$(sudo iptables -L -n -t nat | grep REDIRECT)
  echo -e "${blueColor}${TITLE}${endColor}"
  echo -e "${grayColor}${RESULT}${endColor}"
  echo 
  echo -e "${greenColor}[:)] Configuration completed${endColor}"
  echo 

  PRIV="$(ip address | grep -v '127.0.0.1' | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}' | grep -v '172.17.0.1')"
  if [ -n "$PRIV" ]; then
    echo -e "${blueColor}[-]${endColor} Priv IP: ${greenColor}${PRIV}${endColor}"
  else
    echo -e "${blueColor}[-]${endColor} Priv IP: ${greenColor}Unknown${endColor}"
  fi

  NEWIP="$(GET http://www.vermiip.es/ | grep "Tu IP p&uacute;blica es" | perl -pe 's/(.*:)|(<\/h2>)|(%\s+)//g;')"
  if [ -n "$NEWIP" ]; then
    echo -e "${blueColor}[-]${endColor} Pub IP: ${greenColor}${NEWIP}${endColor}"
  else
    echo -e "${blueColor}[-]${endColor} Pub IP: ${greenColor}Unknown${endColor}"
  fi
}

# Stop running services and restore default settings.
stopAnonSurf(){
  header
  echo -e "${yellowColor}[!!] Stopping services and restoring configuration${endColor}"
  sudo ifconfig eth0 down
  sudo dhclient eth0
  sudo service tor stop
  sudo iptables -F
  sudo iptables -t nat -F
  sleep 1
  echo -e "${greenColor}[:)] Configuration completed${endColor}"

}

# Init main func 
main "$@"
