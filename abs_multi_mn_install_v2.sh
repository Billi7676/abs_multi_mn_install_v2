#!/bin/bash

# set script vars
declare RPC_PORT=59001
declare -r ABS_USER="ABS_user"
declare -r ABS_PORT=18888
declare -r ROOT_PATH="$(pwd)"
declare -r ABSCORE_ROOT_PATH="$ROOT_PATH/.absolutecore"
declare -r WALLET_PATH="$ROOT_PATH/Absolute"
declare -r SYSTEMD_UNIT_PATH="/etc/systemd/system"
declare -r ABS_UNIT_FILE="absmn"
declare -a IP_LIST
declare -a IP_LIST_V4
declare -a IP_LIST_V6
declare -a RPC_PORTS
declare -a BLS_PRIVATE_KEYS

# when new wallet release is published the next two lines needs to be updated
WALLET_VER="v0.14.0.1"
WALLET_FILE="absolutecore-0.14.0-x86_64-linux-gnu.tar.gz"

WALLET_URL="https://github.com/absolute-community/absolute/releases/download/$WALLET_VER"

SENTINEL_URL="https://github.com/absolute-community/sentinel.git"

# functions defs
function printError {
	printf "\33[0;31m%s\033[0m\n" "$1"
}

function printSuccess {
	printf "\33[0;32m%s\033[0m\n" "$1"
}

function printWarning {
	printf "\33[0;33m%s\033[0m\n" "$1"
}

function extractDaemon
{
	echo "Extracting..."
	tar -zxvf "$WALLET_FILE" && mv "$WALLET_DIR_NAME/bin" "$WALLET_PATH"
	rm -r "$WALLET_DIR_NAME"
	if [ -f "/usr/local/bin/absolute-cli" ]; then
		rm /usr/local/bin/absolute-cli
	fi
	if [ -f "/usr/local/bin/absoluted" ]; then
		rm /usr/local/bin/absoluted
	fi
	ln -s "$WALLET_PATH"/absolute-cli /usr/local/bin/absolute-cli
	ln -s "$WALLET_PATH"/absoluted /usr/local/bin/absoluted
	rm "$WALLET_FILE"
	printSuccess "...done!"
	echo
}

function setupNode
{
	echo "*** Create directory and conf files for masternode $((count+1)) ***"
	mkdir -p "$ABSCORE_PATH" && touch "$ABS_CONF_FILE"
	{
		printf "\n#--- basic configuration --- \nrpcuser=$ABS_USER\nrpcpassword=$RPC_PASS\nrpcport=$RPC_PORT\nbind=$MN_IP:$ABS_PORT\nrpcbind=127.0.0.1:$RPC_PORT\nexternalip=$MN_IP:$ABS_PORT\ndaemon=1\nlisten=1\nserver=1\nmaxconnections=256\nrpcallowip=127.0.0.1\n"
		printf "\n#--- masternode ---\nmasternode=1\nmasternodeblsprivkey=$BLS_PRIVKEY\n"
		printf "\n#--- new nodes ---\naddnode=118.69.72.95:18888\naddnode=80.211.81.251:18888\naddnode=88.198.119.136:18888\naddnode=46.97.97.38:18888\naddnode=62.121.77.173:18888\n"
		printf "addnode=45.77.138.219:18888\naddnode=95.216.209.25:18888\naddnode=116.203.202.68:18888\naddnode=95.217.232.25:18888\naddnode=116.203.255.12:18888\naddnode=168.119.97.188:18888\n"
	} > "$ABS_CONF_FILE"
	printSuccess "...done!"
	echo
}

function setupSentinel
{
	echo "*** Installing sentinel for masternode $((count+1)) ***"
	cd "$ABSCORE_PATH" || exit 1
	git clone "$SENTINEL_URL" --q
	cd "$SENTINEL_PATH" && virtualenv ./venv && ./venv/bin/pip install -r requirements.txt
	printSuccess "...done!"

	echo
	echo "*** Configuring sentinel ***"
	if grep -q -x "absolute_conf=$ABS_CONF_FILE" "$SENTINEL_CONF_FILE" ; then
		printWarning "absolute.conf path already set in sentinel.conf!"
	else
		printf "absolute_conf=%s\n" "$ABS_CONF_FILE" >> "$SENTINEL_CONF_FILE"
		printSuccess "...done!"
	fi
	echo
}

function setupCrontab
{
	echo "*** Configuring crontab ***"
	echo  "Set sentinel to run at every minute..."
	if crontab -l 2>/dev/null | grep -q -x "\* \* \* \* \* cd $SENTINEL_PATH && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >/dev/null ; then
		printWarning "Sentinel run at every minute already set!"
	else
		(crontab -l 2>/dev/null; echo "* * * * * cd $SENTINEL_PATH && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1") | crontab -
		printSuccess "...done!"
	fi
	echo
}


function setupABSunit
{
	echo "*** Create systemd like start unit ***"
	touch "$ABS_UNIT"
	{
	printf "Description=Start ABS daemon\n\nWants=network.target\nAfter=syslog.target network-online.target\n"
	printf "\n[Service]\nType=forking\nTimeoutSec=15\nExecStart=$WALLET_PATH/absoluted -datadir=$ABSCORE_PATH -daemon\n"
	printf "ExecStop=$WALLET_PATH/absolute-cli -datadir=$ABSCORE_PATH stop\n"
	printf "ExecReload=/bin/kill -SIGHUP \$MAINPID\n"
	printf "Restart=on-failure\nRestartSec=15\nKillMode=process\n"
	printf "\n[Install]\nWantedBy=multi-user.target\n"
	} > "$ABS_UNIT"
	printSuccess "...done!"
	echo
}



# entry point
clear

printf "\n%s\n" "===== ABS multinode vps install ====="
printf "\n%s" "Installed OS: $(cut -d':' -f2 <<< "$(lsb_release -d)")"
printf "\n%s\n" "We are now in $(pwd) directory"
echo

# check ubuntu version - we need ubuntu
if [ -r /etc/os-release ]; then
	. /etc/os-release
	if [ "${ID}" != "ubuntu" ] ; then
		echo "Script needs Ubuntu! Exiting..."
		echo
		exit 0
	fi
else
	echo "Operating system is not Ubuntu! Exiting..."
	echo
	exit 0
fi

sleep 2

echo "*** Updating system ***"
apt-get update -y -qq
apt-get upgrade -y -qq
printSuccess "...done!"

# get the number of ips - we need public ips configured locally
IPS_NO_V4=$(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/' | grep -v '^127\.\|^10\.\|^172\.1[6-9]\.\|^172\.2[0-9]\.\|^172\.3[0-2]\.\|^192\.168\.' -c)
IPS_NO_V6=$(ip -6 addr show | grep 'global' | awk '{print $2}' | cut -f1 -d'/' | grep '' -c)
IPS_NO=$((IPS_NO_V4 + IPS_NO_V6))

if [ 0 -eq "$IPS_NO" ]; then
	printError "We didn't found any public ip addresses!"
	printWarning "ABS nodes require public ip configured locally."
	printWarning "If your vps is behind NAT, use the single node setup script."
	printWarning "Exiting..."
	echo
	exit 0
fi

# check for running daemon and kill it
RUNNING_DAEMONS=$(pgrep absoluted -c)
if [ "$RUNNING_DAEMONS" -gt 0 ]; then
	printWarning "Found ABS daemon running! Kill it, then wait 30s..."
	killall -9 absoluted
	sleep 30
	if [ -n "$(pgrep absoluted)" ]; then
		printWarning "ABS daemon respawn! Script can't run with ABS demon running!"
		printWarning "Check your vps and stop ABS service(s)! Exiting..."
		echo
		exit 0
	fi
	printSuccess "...done!"
	echo
fi

# check for configuration directories and back up them
OLD_CONF_NO=$(ls -a | grep '\.absolutecore' -c)
if [ "$OLD_CONF_NO" -gt 0 ]; then
	printWarning "Old configurations directories found!"
	printWarning "Making backup of these directories!"
	mapfile -t OLD_CONF_LIST < <(ls -a | grep '\.absolutecore')
	BKP_DEST="ABS_BKP_$(date +%F_%T)"
	mkdir "$BKP_DEST"
	for OLD_CONF in "${OLD_CONF_LIST[@]}" ; do
		mv "$OLD_CONF" "$BKP_DEST"
	done
	printSuccess "...done!"
	echo
fi

# get the ip list
echo
echo "*** Get available ips ***"
mapfile -t IP_LIST < <(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/' | grep -v '^127\.\|^10\.\|^172\.1[6-9]\.\|^172\.2[0-9]\.\|^172\.3[0-2]\.\|^192\.168\.')
mapfile -t -O "${#IP_LIST[@]}" IP_LIST < <(ip -6 addr show | grep 'global' | awk '{print $2}' | cut -f1 -d'/' | awk '{print "["$1"]" }')
# IP_LIST=("${IP_LIST_V4[*]} ${IP_LIST_V6[*]}")
echo "${IP_LIST[*]}"
printSuccess "...done!"
echo

echo
echo "*** IPs confirmation ***"
count=0
ip_removed=0
printSuccess "Confirm IPs for wich we will install a node with 1 for yes and 2 for no..."
while [ "$count" -lt "$IPS_NO" ]; do
  PS3="Do you want to setup a node for ip ${IP_LIST[$count]}: "
  select choice  in yes no; do
        case $choice in
          yes)
            ((++count))
            echo
            break
            ;;
          no)
            unset 'IP_LIST[$count]'
            ((++count))
            ((++ip_removed))
            echo
            break
            ;;
        esac
  done
done
IP_LIST=("${IP_LIST[@]}")
IPS_NO=$(("$IPS_NO"-"$ip_removed"))
if (("$IPS_NO" == 0)); then
        printWarning "There are no confirmed IPs to setup masternodes on! Exiting..."
        echo
        exit 1
fi
echo


# find open rpc ports
echo
echo "*** Find necessary open rpc ports ***"
count=0
while [ "$count" -lt "$IPS_NO" ]; do
	if [ 0 -eq "$(netstat -tunlep | grep $RPC_PORT -c)" ]; then
		echo "Found RPC port $RPC_PORT open"
		RPC_PORTS["$count"]="$RPC_PORT"
		((++count))
	fi
	((++RPC_PORT))
done
printSuccess "...done!"
echo

# read privatekeys from console
echo "*** Input private keys for each masternode ***"
echo "Generate bls private key(s) in control wallet > debug console with this command: bls generate"
count=0
while [ "$count" -lt "$IPS_NO" ]; do
	echo
	printSuccess "Masternode $((count+1)) will be configured for ip ${IP_LIST[$count]}."
	read -p 'Enter masternode '$((count+1))' bls private key: ' bls_priv_key
	BLS_PRIVATE_KEYS["$count"]="$bls_priv_key"
	((++count))
	sleep 1
done
printSuccess "...done!"
echo


# let's do this
printSuccess "We will install $IPS_NO masternode(s)!"
echo
sleep 2

echo
echo "*** Install ABS daemon dependencies ***"
apt-get install nano dbus ufw fail2ban git pwgen python virtualenv software-properties-common -y -qq
printSuccess "...done!"

echo
echo "*** Download ABS daemon binaries ***"
if [ ! -f "$WALLET_FILE" ]; then
	echo "Downloading..."
	wget "$WALLET_URL/$WALLET_FILE" -q && printSuccess "...done!"
else
	printWarning "File already downloaded!"
fi
WALLET_DIR_NAME=$(tar -tzf "$WALLET_FILE" | head -1 | cut -f1 -d"/")
if [ -z "$WALLET_DIR_NAME" ]; then
	printError "Failed - downloading ABS daemon binaries."
	exit 1
fi

echo
echo "*** Extract ABS daemon binaries ***"
if [ -d "$WALLET_PATH" ]; then
	printWarning "Remove old daemon directory..."
	rm -r "$WALLET_PATH"
	printSuccess "...done!"
	echo
fi
extractDaemon

#configure folders, conf files, sentinel and crontab
echo "*** Creating masternodes ***"
count=0
for BLS_PRIVKEY in "${BLS_PRIVATE_KEYS[@]}"; do
	RPC_PASS=$(pwgen -1 20 -n)
	RPC_PORT="${RPC_PORTS[$count]}"
	MN_IP="${IP_LIST[$count]}"
	ABSCORE_PATH="$ABSCORE_ROOT_PATH$((count+1))"
	ABS_CONF_FILE="$ABSCORE_PATH/absolute.conf"
	SENTINEL_PATH="$ABSCORE_PATH/sentinel"
	SENTINEL_CONF_FILE="$SENTINEL_PATH/sentinel.conf"
	ABS_UNIT="$SYSTEMD_UNIT_PATH/$ABS_UNIT_FILE$((count+1)).service"
	
	echo
	printSuccess "Configure ABS masternode $((count+1)) in $ABSCORE_PATH with following settings:"
	printSuccess "  - ip: $MN_IP:$ABS_PORT"
	printSuccess "  - bls private key: $BLS_PRIVKEY"
	echo
	setupNode
	setupSentinel
	setupCrontab
	setupABSunit
	systemctl enable "$ABS_UNIT_FILE$((count+1))"
	cd "$ROOT_PATH"
	printSuccess "Masternode $((count+1)) configuration ...done!"
	((++count))
	echo
done

echo "*** Following nodes were set up ***"
count=0
for BLS_PRIVKEY in "${BLS_PRIVATE_KEYS[@]}"; do
	MN_IP="${IP_LIST[$count]}"
	printSuccess "Node $((count+1)) was set up on ip $MN_IP:$ABS_PORT with the following bls private key:"
	printSuccess "   $BLS_PRIVKEY"
	echo ""
	((++count))
done

echo
echo "That's it! Everything is done! You just have to start the masternode(s) with next command(s):"
count=0
while [ "$count" -lt "$IPS_NO" ]; do
	printSuccess "systemctl start $ABS_UNIT_FILE$((count+1))"
	((++count))
done
echo

printWarning "Syncing multiple masternodes at the same time will likely cause one or more ABS daemons to die!"
printWarning "I recommand start a masternode and wait until is synced with the network before starting another!"
