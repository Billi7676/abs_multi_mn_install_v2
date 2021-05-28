# Absolute coin (ABS) one vps / multinode install script v2

This script is used to install multiple masternode of Absolute coin (ABS) on a single vps with multiple ip addresses.


## What you need

To install the node you need the following:
- a control wallet on your PC, MAC or Linux computer
- 2500 ABS coins for each node that will be used as collateral
- a vps server running Ubuntu Linux 18.04 or 20.04 with multiple ip addresses (allocate 512MB of RAM per node or setup a swap file 2x amount of RAM - check the end of this guide for how to setup swap)


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

This key is needed for a while until the network is upgraded. In the future there will be another mechanism (bls private and public keys pair) to link masternode vps with the control wallet.

To get the bls private key pair run this command in debug console:

	bls generate

Again, generate as many bls pairs as you need later with the script.

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

Restart your Absolute wallet, the look for masternode alias just created above in masternode tab, select it from the list and click Start Alias button (before starting your node you should check that vps cold node is synced too).

<br />

<strong>Following section is needed after block 970000</strong>

We will need two new addresses - owner address (must be new and unused) and voting address - run these 2 cmds in debug console:

	getaccountaddress MN1-OWN
	getaccountaddress MN1-VOT

<strong><small>NOTE: Voting rights can be transferred to another address or owner... in this case last command will not be necessary instead use that address as a voting address.</small></strong>

Optional, to keep track of your masternode payments you can generate another new address like this:

	getaccountaddress MN1-PAYMENTS

If this is not a priority you can use your main wallet address. Note that you need to have some ABS here to cover few transactions fees (1 ABS will do - must be confirmed - atleast 6 blocsk old).

Optional, another address can be generated and used to cover fees for your masternodes transactions. You need to fund this address and use it on your protx command.

	getaccountaddress MN-FEES


I won't use it with this script, fees will be covered from the main wallet address.

<br />

<br />



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

	http://explorer.absify.me

Also note that the script will display at the end which ip is associated with which private key. You will need this info to set up masternode.conf file corectly.

After your node is synced with the network, switch to your control wallet and start your masternodes. Open masternode tab, select each alias you just created from the masternode list and click the Start alias button. You should get a "Successfuly started MNx" prompt.

Now you need to wait another 20 minutes and the status of your masternodes should be Enabled.

To check if a masternode was started succesfully type next command on your vps:

	absolute-cli -datadir=/root/.absolutecore1 masternode status
	
In a multi node environment you always need to use <small>-datadir=path_to_abscore</small> option in your commands. This way you select a specified node that you want to send cmds to.

<strong><small>Note: you need to have vps cold node synced before you continue with the part 3!</small></strong>


<br />

<br />

**3. On your control wallet**

<strong><small>Note: This part is only needed after block 970000!</small></strong>

<br />

On your control wallet you need to run few commands to prepare, sign and sumbit a special ProRegTx transaction that will activate your masternode.

<strong><small>Note: Make sure your wallet is unlocked!</small></strong>

<br />

<strong>Step 1. Prepare a unsigned special transaction.</strong>

Synthax:

	protx register_prepare collateralTx collateralTxIndex ip:port ownerAddr operatorBlsPubKey votingAddr operatorReward payoutAddr (feeSourceAddr)

You can use a text editor to prepare this command. Replace each command argument as follows:

	- collateralTx: transaction id of the 2500ABS collateral
	- collateralTxIndex: transaction index of the 2500ABS collateral
	- ip:port: masternode ip and port
	- ownerAddr: new ABS address generated above
	- operatorBlsPubKey: BLS public key generated above
	- votingAddr: new ABS address generated above or the address used to delegate proposal voting
	- operatorReward: percentage of the block reward allocated to the operator as payment (use 0 here)
	- payoutAddr: new or main wallet address to receive rewards
	- feeSourceAddr: (optional) an address used to fund ProTx fee, if missing, payoutAddr will be used


<strong><small>Note: if you use a non-zero operatorReward, you need to use a separate update_service transaction to specify the reward address (not covered by this how-to).</small></strong>


Example command:

	protx register_prepare 
	75babcc7660dbce0d8f8c6ac541eabc0e7844e74e03b4ec4f85df902a1264099 
	0 
	65.21.144.60:17777 
	yjSSuGj2Num4cJmswrEyks1yUqSZ6PT9T2 
	15d473ecc5b48f0f19c18a5bc78ae19dc722ccf22570f98ffc5945cdf4eda9539c421418e2cfb5e41fe0b6cb4d73d1f1 
	ye2ZCAVkUEfvVyTLYDqmMG7aEZKtDeeEpn 
	0 
	yhWybg5sRZHopwwDHU7CRPkYiXUk9TgTV1


Result:

	{
  	"tx": "030001000180b191aa19030230c250064c9217f327fafd70b222fa7d6a3a50e8e774fc1a300000000000feffffff0121dff505000000001976a914e888e2ac0f029208e2ac59572740dcc66b3c4c4888ac00000000d1010000000000994026a102f95df8c44e3be0744e84e7c0ab1e54acc6f8d8e0bc0d66c7bcba750000000000000000000000000000ffff4115903c4571fd9dd95354f9c9e0c2ff15c503f2fb4c2effb4fe15d473ecc5b48f0f19c18a5bc78ae19dc722ccf22570f98ffc5945cdf4eda9539c421418e2cfb5e41fe0b6cb4d73d1f1c2407d14cacc4c275e35918102216c973ad1561b00001976a914e888e2ac0f029208e2ac59572740dcc66b3c4c4888ac216cf434d24a2547c9f0763a16a9bf2a695cac3d2c54dd9208bd631446f433d900",
  	"collateralAddress": "yXUmTnwkZrmXeSy1FwUr9pBcZPPtWjcT6M",
  	"signMessage": "yhWybg5sRZHopwwDHU7CRPkYiXUk9TgTV1|0|yjSSuGj2Num4cJmswrEyks1yUqSZ6PT9T2|ye2ZCAVkUEfvVyTLYDqmMG7aEZKtDeeEpn|5ccbe02fb852dcb5b11358de2d5cc9bd17db70d0b271ceb381328404830f34d2"
	}

<strong><small>Note: protx command should be one line with only one space between arguments.</small></strong>

<strong>Step 2. Sign the message from previous command with the collateral address resulted above.</strong>

Example command:

	signmessage yXUmTnwkZrmXeSy1FwUr9pBcZPPtWjcT6M yhWybg5sRZHopwwDHU7CRPkYiXUk9TgTV1|0|yjSSuGj2Num4cJmswrEyks1yUqSZ6PT9T2|ye2ZCAVkUEfvVyTLYDqmMG7aEZKtDeeEpn|5ccbe02fb852dcb5b11358de2d5cc9bd17db70d0b271ceb381328404830f34d2


Result:

	H2rV31nqSkcWNqBhCYhCYYmKVTlQkzVjfzCvuqIjocknTPtzC3BgRgJR/uoPbNH8YHpETTYuhp+6Ms22gzeHsqg=


<strong>Step 3. Submit transaction and signature resulted above.</strong>

Example command:

	protx register_submit 030001000180b191aa19030230c250064c9217f327fafd70b222fa7d6a3a50e8e774fc1a300000000000feffffff0121dff505000000001976a914e888e2ac0f029208e2ac59572740dcc66b3c4c4888ac00000000d1010000000000994026a102f95df8c44e3be0744e84e7c0ab1e54acc6f8d8e0bc0d66c7bcba750000000000000000000000000000ffff4115903c4571fd9dd95354f9c9e0c2ff15c503f2fb4c2effb4fe15d473ecc5b48f0f19c18a5bc78ae19dc722ccf22570f98ffc5945cdf4eda9539c421418e2cfb5e41fe0b6cb4d73d1f1c2407d14cacc4c275e35918102216c973ad1561b00001976a914e888e2ac0f029208e2ac59572740dcc66b3c4c4888ac216cf434d24a2547c9f0763a16a9bf2a695cac3d2c54dd9208bd631446f433d900 H2rV31nqSkcWNqBhCYhCYYmKVTlQkzVjfzCvuqIjocknTPtzC3BgRgJR/uoPbNH8YHpETTYuhp+6Ms22gzeHsqg=

Result:

	a12cbb3e286b53822e3c150ff1c8de2b6712e9dcbc29e9f54457440c245b7df5


Now you should have your node up and running...



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

