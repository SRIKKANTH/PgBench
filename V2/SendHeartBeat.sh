#!/bin/bash
########################################################################
#
#Updates the state of client VM and accessiblity status of PG Server
#
# The table on the logs db is as below:
#
#CREATE TABLE ResourceHealth
#(
#    ClientHostname VARCHAR(100) NOT NULL PRIMARY KEY, 
#    PgServerFQDN VARCHAR(100),
#    PgServerEnvironment VARCHAR(25),
#    PgServerRegion VARCHAR(25),
#    ClientLastHeartBeat	DATETIME,
#    ServerLastHeartBeat	DATETIME,
#    IsPgServerAccessible VARCHAR(10),

#    IsPgbenchExecuting VARCHAR(10),
#    CurrentPgbenchActiveConnections int,
#    ClientMemoryUsagePercentage float,
#    ClientCpuUsagePercentage float,
#    ClientRootDiskUsagePercentage float
#)
#
# Author: Srikanth Myakam
#
########################################################################
. $HOME/CommonRoutines.sh

export UnDefinedState='UnDefined'
export UpdateResourceHeathToLogsDBLogFile=$HOME/UpdateResourceHeathToLogsDB.log

function UpdateResourceHeathToLogsDB ()
{
    echo "Pushing stats ($ToLogsDbFileCsv) to LogsDB '$LogsDbServer' into table '$ResourceHealthTableName' ------ " `GetCurrentDateTimeInSQLFormat`

    ClientHostname=`hostname`
    PgServerFQDN=$Server
    PgServerEnvironment=$Environment
    PgServerRegion=$Region
    ClientLastHeartBeat=`GetCurrentDateTimeInSQLFormat`

    # Get PG Server Status
    IsPgServerAccessible='No'
    PGPASSWORD=$PassWord pg_isready -h $Server -U $UserName > /dev/null && IsPgServerAccessible='Yes'

    #Set 'ServerLastHeartBeat' if PgServer is Accessible
    if [ $IsPgServerAccessible == 'Yes' ] 
    then
        ServerLastHeartBeat=`GetCurrentDateTimeInSQLFormat`
    else
        ServerLastHeartBeat=$UnDefinedState
    fi

    # Check if pgbench is executing on client machine
    if [ `ps -ef | grep pgbench| wc -l` -gt 1 ]
    then
        IsPgbenchExecuting="Yes"
    else
        IsPgbenchExecuting="No"
    fi

    CurrentPgbenchActiveConnections=`netstat -napt 2>/dev/null | grep pgbench | wc -l`
    ClientMemoryUsagePercentage=`free | grep Mem | awk '{print $3/$2 * 100.0}'`
    ClientCpuUsagePercentage=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'`
    ClientRootDiskUsagePercentage=`df -h| grep "\/$"| awk '{print $5}'| sed "s/%//"`

    # Check if an entry aleady exists for this client
    RowExists='No'
    sqlcmd -S $LogsDbServer -U $LogsDbServerUsername -P $LogsDbServerPassword -d $LogsDataBase -Q "SELECT * FROM $ResourceHealthTableName where ClientHostname='"$ClientHostname"'" | grep $ClientHostname > /dev/null 
    if [ $? == 0 ]
    then
        RowExists='Yes'
    else
        RowExists='No'
    fi

    if [ $RowExists == 'No' ]
    then
        # Insert a new row if one doesn't exists for this client
        mssql_cmd="INSERT INTO $ResourceHealthTableName (ClientHostname,PgServerFQDN,PgServerEnvironment,PgServerRegion,ClientLastHeartBeat,ServerLastHeartBeat,IsPgServerAccessible,IsPgbenchExecuting,CurrentPgbenchActiveConnections,ClientMemoryUsagePercentage,ClientCpuUsagePercentage,ClientRootDiskUsagePercentage) VALUES ('$ClientHostname','$PgServerFQDN','$PgServerEnvironment','$PgServerRegion','$ClientLastHeartBeat', '$ServerLastHeartBeat','$IsPgServerAccessible','$IsPgbenchExecuting',$CurrentPgbenchActiveConnections,$ClientMemoryUsagePercentage, $ClientCpuUsagePercentage,$ClientRootDiskUsagePercentage);"
    else
        # Update the row if one exists for this client
        mssql_cmd="UPDATE $ResourceHealthTableName set PgServerFQDN='$PgServerFQDN',PgServerEnvironment='$PgServerEnvironment',PgServerRegion='$PgServerRegion',ClientLastHeartBeat='$ClientLastHeartBeat',ServerLastHeartBeat='$ServerLastHeartBeat',IsPgServerAccessible='$IsPgServerAccessible',IsPgbenchExecuting='$IsPgbenchExecuting',CurrentPgbenchActiveConnections=$CurrentPgbenchActiveConnections,ClientMemoryUsagePercentage=$ClientMemoryUsagePercentage,ClientCpuUsagePercentage=$ClientCpuUsagePercentage,ClientRootDiskUsagePercentage=$ClientRootDiskUsagePercentage WHERE ClientHostname='$ClientHostname'"
    fi

    echo "executing sqlcmd : $mssql_cmd"
    sqlcmd -S $LogsDbServer -U $LogsDbServerUsername -P $LogsDbServerPassword -d $LogsDataBase -Q "$mssql_cmd"
}

echo "-------------------------------- `GetCurrentDateTimeInSQLFormat` -------------------------------- " >> $UpdateResourceHeathToLogsDBLogFile
UpdateResourceHeathToLogsDB >> $UpdateResourceHeathToLogsDBLogFile
