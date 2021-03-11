#!/bin/bash

# https://docs.microsoft.com/en-us/dotnet/core/install/linux-ubuntu#2004-
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y apt-transport-https
sudo apt-get update
sudo apt-get install -y dotnet-sdk-3.1

# https://github.com/cobbr/Covenant/wiki/Installation-And-Startup
sudo git clone --recurse-submodules https://github.com/cobbr/Covenant /opt/Covenant
sudo dotnet build /opt/Covenant/Covenant
screen -S Covenant -dm sudo dotnet run --project /opt/Covenant/Covenant/Covenant.csproj
sleep 5

sudo cat << 'EOF' >> /tmp/start-covenant.sh
#!/bin/bash

covenant_status=$(pgrep -fa Covenant)

if [ -z "$covenant_status" ]
then
	echo '[+] starting Covenant'
	screen -S Covenant -dm sudo dotnet run --project /opt/Covenant/Covenant/Covenant.csproj
	pgrep -fa Covenant
else
	echo "[!] Covenant appears running"; pgrep -fa Covenant
fi
EOF
sudo cp /tmp/start-covenant.sh /usr/bin/start-covenant.sh
sudo chmod 755 /usr/bin/start-covenant.sh
