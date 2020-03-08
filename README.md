# Absolute coin (ABS) one vps / multinode install script v2

This script is used to install multiple masternode of Absolute coin (ABS) on a single vps with multiple ip addresses.


## What you need

To install the node you need the following:
- a control wallet on your PC, MAC or Linux computer
- 2500 ABS coins for each node that will be used as collateral
- a vps server running Ubuntu Linux with multiple ip addresses (allocate 384-512MB of RAM per node or setup a swap file 2x amount of RAM - check the end of this guide for how to setup swap)


## How to do it


**1. On your local computer**

Download the last version of ABS wallet from the github repository found here:

https://github.com/absolute-community/absolute/releases

Then you need to generate a new ABS address in your control wallet. Open Debug Console from Tools menu of your control wallet and paste the next command:

	getaccountaddress MN1

MN1 is just an alias associated with the generated address (MN2... MN3... etc for each node you want to setup).

Send the collateral - 2500 ABS - to the address generated above. Make sure that you send exactly 2500 ABS to that address. Make sure that the \<Substract fee from amount\> option is not checked.

You need to wait for 15 confirmations before you can obtain transaction id and index with the next command run in debug console:

	masternode outputs

To connect your vps with the cold wallet you need a masternode private key which is obtained with this command run in debug console:

	masternode genkey

This private key is needed later when you run install script. Generate as many private keys you need, one for every node you want to setup.

Now open the masternode configuration file from the control wallet (Tools > Open masternode configuration file) and configure the masternode using the example present in the file.
You need the following information to create the masternode line, separated by one space:
- masternode alias
- vps ip and port
- masternode private key
- transaction id
- output index

Example line:

	MN1 207.246.76.60:18888 93HaYBVUCYjEMeeH1Y4sBGLALQZE1Yc1K64xiqgX37tGBDQL8Xg 2bcd3c84c84f87eaa86e4e56834c92927a07f9e18718810b92e0d0324456a67c 0

You need to have one line for each ip your vps has. To be sure which private key is associated with each ip, check the script output and make sure you have associated them right.

Save this file and enable masternode tab in your ABS control wallet (Setting > Options > Wallet > Show mastenodes tab)

Restart your Absolute wallet.


**2. On your vps server**

Use Putty to connect to your vps via ssh. Make sure you have Ubuntu Linux v16.04 installed.

You need to be root, so, if you use a different user to login to your vps then switch the current user to root and navigate to /root folder with this shell command:

	cd /root

Download the install script with this command:

	wget https://bit.ly/abs_multi_mn_install_v2 -O abs_multi_mn_install.sh && chmod +x abs_multi_mn_install.sh

Start the install script with the next command.

	./abs_multi_mn_install.sh

Make sure that the script run without errors! At some point it will ask for private keys you generated earlier. Paste one at a time and press Enter.

Some warnings may occure, for example if you run the script twice for some reason. At the end, the script will provide you with a few commands that you can use to start the nodes or just reboot the vps, the script auto start the daemon on system reboot.

After you start the nodes, the daemon will download the ABS blockchain for each node and sync with the network. This process takes about 15-20 minutes, depending on your vps internet connection.

To check if the vps is synced with the network use this command:

	absolute-cli -datadir=/root/.absolutecore1 getinfo

Always use -datadir=path_to_abscore option in a multi node vps.

Check that the last block is the one as on ABS explorer found here:

	http://explorer.absolutecoin.net

Also note that the script will display at the end which ip is associated with which private key. You will need this info to set up masternode.conf file corectly.

After your node is synced with the network, switch to your control wallet and start your masternodes. Open masternode tab, select each alias you just created from the masternode list and click the Start alias button. You should get a "Successfuly started MNx" prompt.

Now you need to wait another 20 minutes and the status of your masternodes should be Enabled.

To check if a masternode was started succesfully type next command on your vps:

	absolute-cli -datadir=/root/.absolutecore1 masternode status
	
In a multi node environment you always need to use -datadir=path_to_abscore option in your commands. This way you select a specified node that you want to send cmds to.


## Create 2GB swap space

For better stability during initial phase when all nodes need to sync with the network is recommended to create a swap file. This is possible on the KWM type vps. On OpenVZ vps, in most cases this is already done by the vps provider and can't be modified.

To create a 2GB swap file run the next commands, one at a time:

	dd if=/dev/zero of=/mnt/swap bs=1M count=2000
	mkswap /mnt/swap
	chmod 0600 /mnt/swap
	swapon /mnt/swap
	echo '/mnt/swap swap swap defaults 0 0' | sudo tee -a /etc/fstab
	sudo sysctl vm.swappiness=10
	echo "vm.swappiness = 10" >> /etc/sysctl.conf


Congratulations, your multi node vps is running! 


*If you run into problems ask for help in ABS discord support channel.*

