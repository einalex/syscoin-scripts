#!/bin/bash

# Only run as a root user
if [ "$(sudo id -u)" != "0" ]; then
    echo "This script may only be run as root or with user with sudo privileges."
    exit 1
fi

HBAR="---------------------------------------------------------------------------------------"

# import messages
source <(curl -sL https://raw.githubusercontent.com/einalex/syscoin-scripts/master/messages.sh)

pause(){
  echo ""
  read -n1 -rsp $'Press any key to continue or Ctrl+C to exit...\n'
}

do_exit(){
  echo ""
  echo "Install script (and donations welcomed) by:"
  echo ""
  echo "  demesm @ address SkSsc5DDejrXq2HfRf9B9QDqHrNiuUvA9Y"
  echo "  doublesharp @ alias doublesharp / address SjaXL2hXfpiuoPZrRFEPawUSHVjwkdu5az"
  echo "  einalex @ address SPdXXwaMg4cSXfPq6Zn1PZrjz66qsTF4bo"
  echo ""
  echo "Goodbye!"
  echo ""
  exit 0
}

update_system(){
  echo "$MESSAGE_UPDATE"
  # update package and upgrade Ubuntu
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
  sudo apt-get install git -y
  clear
}

update_sentinel(){
  echo "$MESSAGE_SENTINEL"
  #update sentinel
  cd /home/syscoin/sentinel
  sudo su -c "git checkout master" syscoin
  sudo su -c "git pull" syscoin
  clear
}

maybe_prompt_for_swap_file(){
  # Create swapfile if less than 4GB memory
  MEMORY_RAM=$(free -m | awk '/^Mem:/{print $2}')
  MEMORY_SWAP=$(free -m | awk '/^Swap:/{print $2}')
  MEMORY_TOTAL=$(($MEMORY_RAM + $MEMORY_SWAP))
  if [ $MEMORY_TOTAL -lt 3500 ]; then
    echo ""
    echo "Server memory is less than 4GB... you will be able to compile Syscoin Core faster by creating a swap file."
    echo ""
    if ! grep -q '/swapfile' /etc/fstab ; then
      read -e -p "Do you want to create a swap file? [Y/n]: " CREATE_SWAP
      if [ "$CREATE_SWAP" = "" ] || [ "$CREATE_SWAP" = "y" ] || [ "$CREATE_SWAP" = "Y" ]; then
        IS_CREATE_SWAP="Y";
      fi
    fi
  fi
}

maybe_create_swap_file(){
  if [ "$IS_CREATE_SWAP" = "Y" ]; then
    echo "Creating a 4GB swapfile..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee --append /etc/fstab > /dev/null
    sudo mount -a
    echo "Swapfile created."
  fi
}

install_dependencies(){
  echo "$MESSAGE_DEPENDENCIES"
  # git
  sudo apt-get install -y git
  # build tools
  sudo apt-get install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils software-properties-common
  # boost
  sudo apt-get install -y libboost-all-dev
  # bdb 4.8
  sudo add-apt-repository -y ppa:bitcoin/bitcoin
  sudo apt-get update -y
  sudo apt-get install -y libdb4.8-dev libdb4.8++-dev
  # zmq
  sudo apt-get install -y libzmq3-dev
  clear
}

git_clone_repository(){
  echo "$MESSAGE_CLONING"
  cd
  if [ ! -d ~/syscoin ]; then
    git clone https://github.com/syscoin/syscoin.git
  fi
}

syscoin_branch(){
  read -e -p "Syscoin Core Github Branch [master]: " SYSCOIN_BRANCH
  if [ "$SYSCOIN_BRANCH" = "" ]; then
    SYSCOIN_BRANCH="master"
  fi
}

git_checkout_branch(){
  cd ~/syscoin
  git fetch
  git checkout $SYSCOIN_BRANCH --quiet
  if [ ! $? = 0 ]; then
    echo "$MESSAGE_ERROR"
    echo "Unable to checkout https://www.github.com/syscoin/syscoin/tree/${SYSCOIN_BRANCH}, please make sure it exists."
    echo ""
    exit 1
  fi
  git pull
}

autogen(){
  echo "$MESSAGE_AUTOGEN"
  cd ~/syscoin
  ./autogen.sh
  clear
}

configure(){
  echo "$MESSAGE_MAKE_CONFIGURE"
  cd ~/syscoin
  ./configure --disable-tests --disable-gui-tests --disable-bench
  clear
}

compile(){
  echo "$MESSAGE_MAKE"
  echo "Running compile with $(nproc) core(s)..."
  # compile using all available cores
  cd ~/syscoin
  make -j$(nproc) -pipe
  clear
}

make_install() {
  echo "$MESSAGE_MAKE_INSTALL"
  # install the binaries to /usr/local/bin
  cd ~/syscoin
  sudo make install
  clear

}

start_syscoind(){
  echo "$MESSAGE_SYSCOIND"
  sudo service syscoind start     # start the service
  sudo systemctl enable syscoind  # enable at boot
  clear
}

stop_syscoind(){
  echo "$MESSAGE_STOPPING"
  sudo service syscoind stop
  clear
}

clear
echo "$MESSAGE_WELCOME"
pause
clear

echo "$MESSAGE_PLAYER_ONE"
sleep 1
clear

rebuild_syscoind() {
  syscoin_branch      # ask which branch to use
  clear
  stop_syscoind       # stop syscoind if it is running
  update_system       # update all the system libraries
  git_checkout_branch # check out our branch
  clear
  autogen             # run ./autogen.sh
  configure           # run ./configure
  compile             # make and make install
  make_install        # install the binaries
  start_syscoind      # start syscoind back up

  echo "$MESSAGE_COMPLETE"
  echo "Syscoin Core update complete using https://www.github.com/syscoin/syscoin/tree/${SYSCOIN_BRANCH}!"
}

# errors are shown if LC_ALL is blank when you run locale
if [ "$LC_ALL" = "" ]; then export LC_ALL="$LANG"; fi

# check to see if there is already a syscoin user on the system
if grep -q '^syscoin:' /etc/passwd; then
  clear
  echo "$MESSAGE_UPGRADE"
  echo ""
  echo "  Choose [Y]es (default) to upgrade Syscoin Core on a working masternode."
  echo "  Choose [N]o to re-run the configuration process for your masternode."
  echo ""
  echo "$HBAR"
  echo ""
  read -e -p "Upgrade/recompile Sycoin Core only? [Y/n]: " IS_UPGRADE
  if [ "$IS_UPGRADE" = "" ] || [ "$IS_UPGRADE" = "y" ] || [ "$IS_UPGRADE" = "Y" ]; then
    rebuild_syscoind
    update_sentinel
    do_exit             # exit the script
  fi
fi
clear

RESOLVED_ADDRESS=$(curl -s ipinfo.io/ip)

echo "$MESSAGE_CONFIGURE"
echo ""
echo "This script has been tested on Ubuntu 16.04 LTS x64."
echo ""
echo "Before starting script ensure you have: "
echo ""
echo "  - Sent 100,000SYS to your masternode address"
echo "  - Run 'masternode genkey' and 'masternode outputs' and recorded the outputs"
echo "  - Added masternode config file ('Tools>Open Masternode Config' in Syscoin-Qt) "
echo "    - addressAlias vpsIp:8369 masternodePrivateKey transactionId outputIndex"
echo "    - EXAMPLE: mn1 ${RESOLVED_ADDRESS}:8369 ctk9ekf0m3049fm930jf034jgwjfk zkjfklgjlkj3rigj3io4jgklsjgklsjgklsdj 0"
echo "  - Restarted Syscoin-Qt"
echo ""
echo "Default values are in brackets [default] or capitalized [Y/n] - pressing enter will use this value."
echo ""
echo "$HBAR"
echo ""

SYSCOIN_BRANCH="master"
DEFAULT_PORT=8369

# syscoin.conf value defaults
rpcuser="sycoinrpc"
rpcpassword="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
masternodeprivkey=""
externalip="$RESOLVED_ADDRESS"
port="$DEFAULT_PORT"

# try to read them in from an existing install
if sudo test -f /home/syscoin/.syscoincore/syscoin.conf; then
  sudo cp /home/syscoin/.syscoincore/syscoin.conf ~/syscoin.conf
  sudo chown $(whoami).$(id -g -n $(whoami)) ~/syscoin.conf
  source ~/syscoin.conf
  rm -f ~/syscoin.conf
fi

RPC_USER="$rpcuser"
RPC_PASSWORD="$rpcpassword"
MASTERNODE_PORT="$port"

# ask which branch to use
syscoin_branch

masternode_private_key(){
  read -e -p "Masternode Private Key [$masternodeprivkey]: " MASTERNODE_PRIVATE_KEY
  if [ "$MASTERNODE_PRIVATE_KEY" = "" ]; then
    if [ "$masternodeprivkey" != "" ]; then
      MASTERNODE_PRIVATE_KEY="$masternodeprivkey"
    else
      echo "You must enter a masternode private key!";
      masternode_private_key
    fi
  fi
}
masternode_private_key

if [ "$externalip" != "$RESOLVED_ADDRESS" ]; then
  echo ""
  echo "WARNING: The syscoin.conf value for externalip=${externalip} does not match your detected external ip of ${RESOLVED_ADDRESS}."
  echo ""
fi
read -e -p "External IP Address [$externalip]: " EXTERNAL_ADDRESS
if [ "$EXTERNAL_ADDRESS" = "" ]; then
  EXTERNAL_ADDRESS="$externalip"
fi
if [ "$port" != "" ] && [ "$port" != "$DEFAULT_PORT" ]; then
  echo ""
  echo "WARNING: The syscoin.conf value for port=${port} does not match the default of ${DEFAULT_PORT}."
  echo ""
fi
read -e -p "Masternode Port [$port]: " MASTERNODE_PORT
if [ "$MASTERNODE_PORT" = "" ]; then
  MASTERNODE_PORT="$port"
fi

# read -e -p "Configure for mainnet? [Y/n]: " IS_MAINNET

maybe_prompt_for_swap_file

#Generating Random Passwords
RPC_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

pause
clear

# syscoin conf file
SYSCOIN_CONF=$(cat <<EOF
# rpc config
rpcuser=user
rpcpassword=$RPC_PASSWORD
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
# syscoind config
listen=1
server=1
daemon=1
maxconnections=24
addressindex=1
debug=0
# masternode config
masternode=1
masternodeprivkey=$MASTERNODE_PRIVATE_KEY
externalip=$EXTERNAL_ADDRESS
port=$MASTERNODE_PORT
EOF
)

# testnet config
SYSCOIN_TESTNET_CONF=$(cat <<EOF
# testnet config
testnet=1
addnode=40.121.201.195
addnode=40.71.212.2
addnode=40.76.48.206
EOF
)

# syscoind.service config
SYSCOIND_SERVICE=$(cat <<EOF
[Unit]
Description=Syscoin Core Service
After=network.target iptables.service firewalld.service

[Service]
Type=forking
User=syscoin
ExecStart=/usr/local/bin/syscoind
ExecStop=/usr/local/bin/syscoin-cli stop && sleep 20 && /usr/bin/killall syscoind
ExecReload=/usr/local/bin/syscoin-cli stop && sleep 20 && /usr/local/bin/syscoind

[Install]
WantedBy=multi-user.target
EOF
)

# syscoind.service config
SENTINEL_CONF=$(cat <<EOF
# syscoin conf location
syscoin_conf=/home/syscoin/.syscoincore/syscoin.conf

# db connection details
db_name=/home/syscoin/sentinel/database/sentinel.db
db_driver=sqlite

# network
EOF
)

# syscoind.service config
SENTINEL_PING=$(cat <<EOF
#!/bin/bash

~/sentinel/venv/bin/python ~/sentinel/bin/sentinel.py 2>&1 >> ~/sentinel/sentinel-cron.log
EOF
)

# functions to install a masternode from scratch
create_and_configure_syscoin_user(){
  echo "$MESSAGE_CREATE_USER"

  # create a syscoin user if it doesn't exist
  grep -q '^syscoin:' /etc/passwd || sudo adduser --disabled-password --gecos "" syscoin

  # add alias to .bashrc to run syscoin-cli as sycoin user
  grep -q "syscli\(\)" ~/.bashrc || echo "syscli() { sudo su -c \"syscoin-cli \$*\" syscoin; }" >> ~/.bashrc
  grep -q "alias syscoin-cli" ~/.bashrc || echo "alias syscoin-cli='syscli'" >> ~/.bashrc
  grep -q "sysd\(\)" ~/.bashrc || echo "sysd() { sudo su -c \"syscoind \$*\" syscoin; }" >> ~/.bashrc
  grep -q "alias syscoind" ~/.bashrc || echo "alias syscoind='sysd'" >> ~/.bashrc
  grep -q "sysmasternode\(\)" ~/.bashrc || echo "sysmasternode() { bash <(curl -sL https://raw.githubusercontent.com/einalex/syscoin-scripts/master/masternode.sh); }" >> ~/.bashrc

  echo "$SYSCOIN_CONF" > ~/syscoin.conf
  if [ ! "$IS_MAINNET" = "" ] && [ ! "$IS_MAINNET" = "y" ] && [ ! "$IS_MAINNET" = "Y" ]; then
    echo "$SYSCOIN_TESTNET_CONF" >> ~/syscoin.conf
  fi

  # in case it's already running because this is a re-install
  sudo service syscoind stop

  # create conf directory
  sudo mkdir -p /home/syscoin/.syscoincore
  sudo rm -rf /home/syscoin/.syscoincore/debug.log
  sudo mv -f ~/syscoin.conf /home/syscoin/.syscoincore/syscoin.conf
  sudo chown -R syscoin.syscoin /home/syscoin/.syscoincore
  sudo chmod 600 /home/syscoin/.syscoincore/syscoin.conf
  clear
}

create_systemd_syscoind_service(){
  echo "$MESSAGE_SYSTEMD"
  # create systemd service
  echo "$SYSCOIND_SERVICE" > ~/syscoind.service
  # install the service
  sudo mkdir -p /usr/lib/systemd/system/
  sudo mv -f ~/syscoind.service /usr/lib/systemd/system/syscoind.service
  # reload systemd daemon
  sudo systemctl daemon-reload
  clear
}

install_fail2ban(){
  echo "$MESSAGE_FAIL2BAN"
  sudo apt-get install fail2ban -y
  sudo service fail2ban restart
  sudo systemctl fail2ban enable
  clear
}

install_ufw(){
  echo "$MESSAGE_UFW"
  sudo apt-get install ufw -y
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow 8369/tcp
  yes | sudo ufw enable
  clear
}

install_sentinel(){
  echo "$MESSAGE_SENTINEL"
  # go home
  cd
  if [ ! -d ~/sentinel ]; then
    git clone https://github.com/syscoin/sentinel.git
  else
    cd sentinel
    git fetch
    git checkout master --quiet
    git pull
  fi
  clear
}

install_virtualenv(){
  echo "$MESSAGE_VIRTUALENV"
  cd ~/sentinel
  # install virtualenv
  sudo apt-get install -y python-virtualenv virtualenv
  # setup virtualenv
  virtualenv venv
  venv/bin/pip install -r requirements.txt
  clear
}

configure_sentinel(){
  echo "$MESSAGE_CRONTAB"
  # create systemd service
  echo "$SENTINEL_CONF" > ~/sentinel/sentinel.conf
  if [ "$IS_MAINNET" = "" ] || [ "$IS_MAINNET" = "y" ] || [ "$IS_MAINNET" = "Y" ]; then
    echo "network=mainnet" >> ~/sentinel/sentinel.conf
  else
    echo "network=testnet" >> ~/sentinel/sentinel.conf
  fi

  cd
  sudo mv -f ~/sentinel /home/syscoin
  sudo chown -R syscoin.syscoin /home/syscoin/sentinel

  # create sentinel-ping
  echo "$SENTINEL_PING" > ~/sentinel-ping

  # install sentinel-ping script
  sudo mv -f ~/sentinel-ping /usr/local/bin
  sudo chmod +x /usr/local/bin/sentinel-ping

  # setup cron for syscoin user
  sudo crontab -r -u syscoin
  sudo crontab -l -u syscoin | grep sentinel-ping || echo "* * * * * /usr/local/bin/sentinel-ping" | sudo crontab -u syscoin -
  clear
}

get_masternode_status(){
  echo ""
  sudo su -c "syscoin-cli mnsync status" syscoin && \
  sudo su -c "syscoin-cli masternode status" syscoin
  echo ""
  read -e -p "Check again? [Y/n]: " CHECK_AGAIN
  if [ "$CHECK_AGAIN" = "" ] || [ "$CHECK_AGAIN" = "y" ] || [ "$CHECK_AGAIN" = "Y" ]; then
    get_masternode_status
  fi
}

# if there is <4gb and the user said yes to a swapfile...
maybe_create_swap_file

# prepare to build
update_system
install_dependencies
git_clone_repository
git_checkout_branch
clear

# run the build steps
autogen
configure
compile
make_install
clear

create_and_configure_syscoin_user
create_systemd_syscoind_service
start_syscoind
install_sentinel
install_virtualenv
configure_sentinel
install_fail2ban
install_ufw
clear

echo "$MESSAGE_COMPLETE"
echo ""
echo "Your masternode configuration should now be completed and running as the syscoin user."
echo "If you see MASTERNODE_SYNC_FINISHED return to Syscoin-Qt and start your node, otherwise check again."

get_masternode_status

# ping sentinel
sudo su -c "sentinel-ping" syscoin

echo ""
echo "Masternode setup complete!"
echo ""
echo "Please run the following command to access syscoin-cli from this session or re-login."
echo ""
echo "  source ~/.bashrc"
echo ""
echo "You can run syscoin-cli commands as the syscoin user: "
echo ""
echo "  syscoin-cli getinfo"
echo "  syscoin-cli masternode status"
echo ""
echo "To update this masternode just type:"
echo ""
echo "  sysmasternode"
echo ""
echo "ATTENTION: Pressing the start button in Qt will reset your qualification time, which will exempt you from getting rewards for |masternodes| * 2.6 / 60 hours. Once you initially started the node this way, ONLY do so again in case the node has been offline for > 4hrs."
echo ""

do_exit
