#!/bin/bash
#
# Install dependencies and schedule cron jobs for pgbench testing.
#
# Author: Srikanth Myakam
#
########################################################################

export PATH="$PATH:/opt/mssql-tools/bin"
export InstallationFailed='No'

function InstallDependencies()
{ 
    sudo DEBIAN_FRONTEND=noninteractive apt --assume-yes --fix-broken -y install
    sudo apt-get update
    # Install ms-sql tools to communicate with LogsDB
    if [[ `which bcp` == "" ]]; then
        echo "INFO: mssql-tools: not installed!"
        echo "INFO: mssql-tools: Trying to install!"
        
        curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
        curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt --assume-yes --fix-broken -y install
        sudo DEBIAN_FRONTEND=noninteractive apt-get  --assume-yes  install -y mssql-tools unixodbc-dev

        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
        .  ~/.bash_profile
        # Check if bcp installed or not
        if [[ `which bcp` == "" ]]; then
            echo "FATAL: Failted to install 'mssql-tools'!"
            InstallationFailed='Yes'
        fi
    else
        echo "Skipping 'mssql-tools' installation as already installed"
    fi

    # pgbench is the PG bench marking tool.
    if [[ `which pgbench` == "" ]]; then
        echo "INFO: pgbench: not installed!"
        echo "INFO: pgbench: Trying to install!"
        sudo DEBIAN_FRONTEND=noninteractive apt --assume-yes --fix-broken -y install
        sudo DEBIAN_FRONTEND=noninteractive apt --assume-yes install -y postgresql-contrib
        
        # Check if pgbench installed or not
        if [[ `which pgbench` == "" ]]; then
            echo "FATAL: Failted to install 'pgbench'!"
            InstallationFailed='Yes'
        fi
    else
        echo "Skipping 'pgbench' installation as already installed"
    fi
    
    # 'sysstat' is needed for collecting client VM stats
    if [[ `which sar` == "" ]]; then
        echo "INFO: sysstat: not installed!"
        echo "INFO: sysstat: Trying to install!"
        sudo DEBIAN_FRONTEND=noninteractive apt --assume-yes --fix-broken -y install
        sudo DEBIAN_FRONTEND=noninteractive  apt-get --assume-yes install -y sysstat

        # Check if sysstat installed or not
        if [[ `which sysstat` == "" ]]; then
            echo "FATAL: Failted to install 'sysstat'!"
            InstallationFailed='Yes'
        fi
    else
        echo "Skipping 'sysstat' installation as already installed"
    fi
    
    # 'mailutils' is needed for sending report mails during & after test 
    if [[ `which mail` == "" ]]; then
        echo "INFO: mailutils: not installed!"
        echo "INFO: mailutils: Trying to install!"
        sudo DEBIAN_FRONTEND=noninteractive apt --assume-yes --fix-broken -y install
        sudo DEBIAN_FRONTEND=noninteractive apt-get --assume-yes install -y mailutils

        # Check if sysstat installed or not
        if [[ `which mail` == "" ]]; then
            echo "FATAL: Failted to install 'mailutils'!"
            InstallationFailed='Yes'
        fi
    else
        echo "Skipping 'mailutils' installation as already installed"
    fi
}

InstallDependencies

if [ $InstallationFailed == 'no' ]
then
    #
    CodePath=$HOME

    #Remove all cron jobs for current user
    echo "Flushing existing cron jobs for current user '$USER'"
    crontab -r

    #Add cron job for HearBeat Monitor to run at every 10 minutes
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CodePath/SendHeartBeat.sh -with args") | crontab -

    #Add cron job for pgbench perf test run at 12:10 am everyday
    (crontab -l 2>/dev/null; echo "01 0 * * * $CodePath/RunTest.sh -with args") | crontab -

    #List all cron jobs for current user and check if above jobs added or not
    echo "Cron jobs scheduled for current user '$USER':"
    crontab -l
else
    echo "FATAL: Failed to install one or more packages"
fi
