# download and run below script on Linux host to onboard internet facing on-prem hosts to EDR
 
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh
bash ~/install_linux_azcmagent.sh
azcmagent connect --service-principal-id <service-principal-id> --service-principal-secret <service

#To offboard a Linux host from EDR we run below commands
 
sudo azcmagent disconnect --force-local-only
sudo apt-get -y purge mdatp
if test -d /var/lib/waagent
then
    sudo systemctl stop walinuxagent
    sudo waagent -deprovision -force
    sudo rm -rf /var/lib/waagent /var/log/waagent.log
fi
 