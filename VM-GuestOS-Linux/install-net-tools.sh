# This script has been tested on Ubuntu
# Update repository
sudo apt update -y && sudo apt upgrade -y 
#Traceroute
sudo apt-get install traceroute -y
# TCP traceroute
sudo apt-get install tcptraceroute -y
# Nmap
sudo apt-get install nmap -y
# Hping3
sudo sudo apt-get install hping3 -y
# iPerf
sudo apt-get install iperf3 -y
# Nginx and adds machine name on main page
sudo apt-get install nginx -y && hostname > /var/www/html/index.html
# Speedtest
sudo apt-get install speedtest-cli -y