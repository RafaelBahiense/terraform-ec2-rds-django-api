#!/bin/bash -vx
set -e

# Define the log file
LOG_FILE="/home/ubuntu/user_data.log"

# Function to log the error
log_error() {
	# shellcheck disable=2317
	echo "Error occurred in script at line: $1" >>"$LOG_FILE"
}

# Trap any error and call the log_error function
trap 'log_error $LINENO' ERR

export SSH_USER="ubuntu"
export DEBIAN_FRONTEND=noninteractive
/usr/bin/apt-get update
/usr/bin/apt-get -yq install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" wget awscli jq libssl-dev atool net-tools git python3 python3.10-venv python3-pip

/bin/cat <<"__UPG__" >/etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
__UPG__

# clone repo
/usr/bin/git clone https://github.com/cirossmonteiro/duopen-challenge.git ${application_root}/duopen-challenge
/usr/bin/python3 -m venv ${application_root}/duopen-challenge/backend/venv
source ${application_root}/duopen-challenge/backend/venv/bin/activate
/usr/bin/pip install --prefix ${application_root}/duopen-challenge/backend -r ${application_root}/duopen-challenge/backend/requirements.txt
 
# Init script for starting, stopping
cat <<INIT >/etc/init.d/my_application
#!/bin/bash
### BEGIN INIT INFO
# Provides:          my_application
# Required-Start:    $local_fs $network
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/stop my_application
### END INIT INFO

start() {
  echo "Starting my_application server from /home/foundry..."
  source ${application_root}/duopen-challenge/backend/venv/bin/activate
  start-stop-daemon --start --quiet  --pidfile ${application_root}/duopen-challenge/backend/application.pid -m -b -c $SSH_USER -d ${application_root}/duopen-challenge/backend --exec /usr/bin/python3 -- manage.py runserver 
}

stop() {
  echo "Stopping my_application server..."
  start-stop-daemon --stop --pidfile ${application_root}/duopen-challenge/backend/application.pid
}

case \$1 in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    sleep 5
    start
    ;;
esac
exit 0
INIT

# Start up on reboot
/bin/chmod +x /etc/init.d/my_application
/usr/sbin/update-rc.d my_application defaults

# Dirty fix
/bin/touch ${application_root}/duopen-challenge/backend/application.pid
/bin/chown $SSH_USER ${application_root}/duopen-challenge/backend/application.pid
/bin/chmod 664 ${application_root}/duopen-challenge/backend/application.pid
/bin/chgrp $SSH_USER ${application_root}/duopen-challenge/backend/application.pid

# Not root
/bin/chown -R $SSH_USER ${application_root}

# Start the application
/etc/init.d/my_application start

exit 0
