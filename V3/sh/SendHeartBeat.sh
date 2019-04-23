#!/bin/bash
########################################################################
#
#Updates the state of client VM and accessiblity status of PG Server
#
# The table on the logs db is as below:
#
# CREATE TABLE ResourceHealth
# (
#   Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
#   Pg_Server VARCHAR(100),
#   Pg_Server_Environment VARCHAR(25),
#   Pg_Server_Region VARCHAR(25), 
#   Client_Last_HeartBeat timestamp,
#   Server_Last_HeartBeat timestamp,
#   Is_Pg_Server_Accessible_From_Client VARCHAR(10),
#   Is_Pgbench_Executing VARCHAR(10),
#   Current_Pgbench_Active_Connections int,
#   Client_Memory_Usage_Percentage float,
#   Client_Cpu_Usage_Percentage float,
#   Client_Root_Disk_Usage_Percentage float
# )
#
# Author: Srikanth Myakam
#
########################################################################
. $HOME/CommonRoutines.sh

export UpdateResourceHeathToLogsDBLogFile=$HOME/UpdateResourceHeathToLogsDB.log

function UpdateResourceHeathToLogsDB ()
{
    echo "Pushing stats ($ToLogsDbFileCsv) to LogsDB '$LogsDbServer' into table '$ResourceHealthTableName' ------ " `GetCurrentDateTimeInSQLFormat`

    ClientHostname=`hostname`
    PgServer=$Server
    PgServerEnvironment=$Environment
    PgServerRegion=$Region
    ClientLastHeartBeat=`GetCurrentDateTimeInSQLFormat`

    # Get PG Server Status
    IsPgServerAccessibleFromClient='No'
    PGPASSWORD=$PassWord pg_isready -h $Server -U $UserName > /dev/null && IsPgServerAccessibleFromClient='Yes'

    #Set 'ServerLastHeartBeat' if PgServer is Accessible
    if [ $IsPgServerAccessibleFromClient == 'Yes' ] 
    then
        ServerLastHeartBeat=`GetCurrentDateTimeInSQLFormat`
    else
        ServerLastHeartBeat='1900-01-01 00:00:00'
    fi

    # Check if pgbench is executing on client machine
    if [ `ps -ef | grep pgbench| wc -l` -gt 1 ]
    then
        IsPgbenchExecuting="Yes"
    else
        IsPgbenchExecuting="No"
    fi
string=`tail -5 Logs/*.log| tail -c 280`
    CurrentPgbenchActiveConnections=`netstat -napt 2>/dev/null | grep pgbench | wc -l`
    ClientMemoryUsagePercentage=`free | grep Mem | awk '{print $3/$2 * 100.0}'`
    ClientCpuUsagePercentage=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'`
    ClientRootDiskUsagePercentage=`df -h| grep "\/$"| awk '{print $5}'| sed "s/%//"`

    # Check if an entry aleady exists for this client
    RowExists='No'

    PGPASSWORD=$LogsDbServerPassword psql -h $LogsDbServer -U $LogsDbServerUsername -d $LogsDataBase -c "SELECT * FROM $ResourceHealthTableName where Client_Hostname='"$ClientHostname"'" | grep $ClientHostname > /dev/null 

    if [ $? == 0 ]
    then
        RowExists='Yes'
    else
        RowExists='No'
    fi

    if [ $RowExists == 'No' ]
    then
        # Insert a new row if one doesn't exists for this client
            sql_cmd="INSERT INTO $ResourceHealthTableName ( \
                Client_Hostname, \
                Pg_Server, \
                Pg_Server_Environment, \
                Pg_Server_Region, \
                Client_Last_HeartBeat, \
                Server_Last_HeartBeat, \
                Is_Pg_Server_Accessible_From_Client, \
                Is_Pgbench_Executing, \
                Current_Pgbench_Active_Connections, \
                Client_Memory_Usage_Percentage, \
                Client_Cpu_Usage_Percentage, \
                Client_Root_Disk_Usage_Percentage ) VALUES ( \
                '$ClientHostname', \
                '$PgServer', \
                '$PgServerEnvironment', \
                '$PgServerRegion', \
                '$ClientLastHeartBeat', \
                '$ServerLastHeartBeat', \
                '$IsPgServerAccessibleFromClient', \
                '$IsPgbenchExecuting', \
                $CurrentPgbenchActiveConnections, \
                $ClientMemoryUsagePercentage, \
                $ClientCpuUsagePercentage, \
                $ClientRootDiskUsagePercentage \
            );"
    else
        # Update the row if one exists for this client
        if [ $IsPgServerAccessibleFromClient == 'Yes' ] 
        then
        # If pgServer is accessible update all values
            sql_cmd="UPDATE $ResourceHealthTableName  \
            set \
            Pg_Server='$PgServer', \
            Pg_Server_Environment='$PgServerEnvironment', \
            Pg_Server_Region='$PgServerRegion', \
            Client_Last_HeartBeat='$ClientLastHeartBeat', \
            Server_Last_HeartBeat='$ServerLastHeartBeat', \
            Is_Pg_Server_Accessible_From_Client='$IsPgServerAccessibleFromClient', \
            Is_Pgbench_Executing='$IsPgbenchExecuting', \
            Current_Pgbench_Active_Connections=$CurrentPgbenchActiveConnections, \
            Client_Memory_Usage_Percentage=$ClientMemoryUsagePercentage, \
            Client_Cpu_Usage_Percentage=$ClientCpuUsagePercentage, \
            Client_Root_Disk_Usage_Percentage=$ClientRootDiskUsagePercentage \
            WHERE Client_Hostname='$ClientHostname'"
        else
        # If pgServer is NOT accessible skip 'Server_Last_HeartBeat' value and update all values
            sql_cmd="UPDATE $ResourceHealthTableName  \
            set \
            Pg_Server='$PgServer', \
            Pg_Server_Environment='$PgServerEnvironment', \
            Pg_Server_Region='$PgServerRegion', \
            Client_Last_HeartBeat='$ClientLastHeartBeat', \
            Is_Pg_Server_Accessible_From_Client='$IsPgServerAccessibleFromClient', \
            Is_Pgbench_Executing='$IsPgbenchExecuting', \
            Current_Pgbench_Active_Connections=$CurrentPgbenchActiveConnections, \
            Client_Memory_Usage_Percentage=$ClientMemoryUsagePercentage, \
            Client_Cpu_Usage_Percentage=$ClientCpuUsagePercentage, \
            Client_Root_Disk_Usage_Percentage=$ClientRootDiskUsagePercentage \
            WHERE Client_Hostname='$ClientHostname'"
        fi
    fi

    echo "executing sqlcmd : $sql_cmd"
    PGPASSWORD=$LogsDbServerPassword psql -h $LogsDbServer -U $LogsDbServerUsername -d $LogsDataBase -c "$sql_cmd" 
}

echo "-------------------------------- `GetCurrentDateTimeInSQLFormat` -------------------------------- " >> $UpdateResourceHeathToLogsDBLogFile
UpdateResourceHeathToLogsDB >> $UpdateResourceHeathToLogsDBLogFile 2>&1
