#!/bin/bash

# Check if necessary envs are set:
if [ "$GSLTS" == "" ]; then
    echo "AUTHKEY needs to be set! You can find the key here: https://steamcommunity.com/dev/apikey"
    exit 1
fi

if [ "$AUTHKEY" == "" ]; then
    echo "GSLTS needs to be set! You can create Tokens here: https://steamcommunity.com/dev/managegameservers"
    exit 1
fi

# Start installation of steamCMD + installation of CS:GO Dedicated Server
sudo mkdir -p "${HOME}/SteamCMD"
cd "${HOME}/SteamCMD"

echo "Downloading and unpacking SteamCMD"
sudo curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | sudo tar zxvf - &> /dev/null
echo "Finished downloading and unpacking."
echo "Installing/Updating SteamCMD and CSGO if necessary..."
sudo chmod +x ./steamcmd.sh
sudo bash "./steamcmd.sh" \
    +login anonymous \
    +force_install_dir ${HOME}/csgo-base \
    +app_update 740 \
    +quit &> /dev/null
sudo mkdir -p /home/admin/.steam
sudo ln -sf /home/admin/SteamCMD/linux32 /home/admin/.steam/sdk32
cd "${HOME}/csgo-base/csgo"

# MetaMod installation
echo "Installing MetaMod in Base"
MM_MAINVER=`curl -s 'http://metamodsource.net/mmsdrop/' | grep -oP '[0-9].[0-9][0-9]\/</a>' | sed 's/.\{5\}$//' | sort -t. -rn -k1,1 -k2,2 -k3,3 | head -2 | tail -1`
MM_CURRENT=`curl -s http://metamodsource.net/mmsdrop/$MM_MAINVER/mmsource-latest-linux`
sudo curl -sqL "http://metamodsource.net/mmsdrop/$MM_MAINVER/$MM_CURRENT" | sudo tar -xzf - &> /dev/null
echo "MetaMod package: $MM_CURRENT successfully installed."

# SourceMod installation
echo "Installing SourceMod in Base"
SM_MAINVER=`curl -s 'http://www.sourcemod.net/smdrop/' | grep -oP '[0-9].[0-9][0-9]\/</a>' | sed 's/.\{5\}$//' | sort -t. -rn -k1,1 -k2,2 -k3,3 | head -2 | tail -1`
SM_CURRENT=`curl -s http://www.sourcemod.net/smdrop/$SM_MAINVER/sourcemod-latest-linux`
sudo curl -sqL "http://www.sourcemod.net/smdrop/$SM_MAINVER/$SM_CURRENT" | sudo tar -zxf - &> /dev/null
echo "SourceMod package: $SM_CURRENT successfully installed."

# Set folder privileges
# Copy plugin, compile and move it into the plugins folder 
sudo chown -R ${USER}: ${HOME}
sudo chmod 777 -R ${HOME}/csgo-base/csgo/addons
cd ${HOME}/csgo-base/csgo/addons/sourcemod/scripting/
cp ${APPDIR}/plugin/checker.sp checker.sp && sudo chmod +x spcomp && ./spcomp checker.sp &> /dev/null && mv checker.smx ../plugins/checker.smx

# Append database settings
# and delete before doing that the last line '}'
cd ${HOME}/csgo-base/csgo/addons/sourcemod/configs/
sed -i '$ d' databases.cfg
echo '
    "stats" 
    {
        "driver"  "mysql"
        "host"   "'${db_Host}'"
        "database"  "'${db_Name}'"
        "user"   "'${db_User}'"
        "pass"   "'${db_Password}'"
        "port"   "'${db_Port}'"
    }
}' >> databases.cfg

# Create .env file
echo 'GSLTS="'${GSLTS}'"
AUTHKEY="'${AUTHKEY}'"
WS_COLLECTION="'${WS_COLLECTION}'"
' > ${APPDIR}/.env

# Move server.cfg
cd ${HOME}/csgo-base/csgo/cfg
mv -f ${APPDIR}/plugin/server.cfg server.cfg

# Starting API
echo "Finished, starting Webserver..."
cd ${APPDIR}
go build -o api && chmod +x ./api
sudo -u ${USER} -H sh -c "./api"