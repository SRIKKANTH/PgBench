#!/bin/bash
########################################################################
#
# Updates the state of client VM and accessiblity status of PG Server
#
# The table on the logs db is as below:
#
#
#CREATE TABLE ResourceHealth
#(
#    Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
#    Test_Server_fqdn VARCHAR(100),
#    Test_Server_Environment VARCHAR(25),
#    Test_Server_Region VARCHAR(25),
#    Test_Database_Type  VARCHAR(25),
#    Test_Type VARCHAR(25),
#    Client_Last_HeartBeat timestamp,
#    Server_Last_HeartBeat timestamp,
#    Is_Test_Server_Accessible_From_Client VARCHAR(25),
#    Is_Test_Executing VARCHAR(25),
#    Current_Test_Active_Connections int,
#    Client_Memory_Usage_Percentage float,
#    Client_Cpu_Usage_Percentage float,
#    Client_Root_Disk_Usage_Percentage float,
#    Recent_Test_Logs VARCHAR(300),
#    Client_Last_Reboot VARCHAR(50)
#);
#
#
#CREATE TABLE Client_info
#(
#    Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
#    Client_Last_HeartBeat timestamp,
#    Test_Server_Assigned VARCHAR(100),
#    Client_Region VARCHAR(25),
#    Client_Resource_Group VARCHAR(25),
#    Client_VM_SKU VARCHAR(25),
#    Client_Username VARCHAR(25),
#    Client_Password VARCHAR(25),
#    Client_FQDN VARCHAR(100)
#);
#
#CREATE TABLE Server_Info
#(
#    Test_Server_fqdn VARCHAR(100) NOT NULL PRIMARY KEY, 
#    Server_Last_HeartBeat timestamp,
#    Test_Server_Region VARCHAR(25),
#    Test_Server_Environment VARCHAR(25),
#    Test_Server_Server_Edition VARCHAR(25),
#    Test_Server_CPU_Cores INT,
#    Test_Server_Storage_In_MB INT,
#    Test_Server_Username VARCHAR(25),
#    Test_Server_Password VARCHAR(25),
#    Test_Database_Type  VARCHAR(25),
#    Test_Database_Name VARCHAR(25)
#);
#
#
# Author: Srikanth Myakam
#
########################################################################
. $HOME/CommonRoutines.sh

export UpdateResourceHeathToLogsDBLogFile=$HOME/UpdateResourceHeathToLogsDB.log

function IsTestServerAccessibleFromClient ()
{
    Is_Test_Server_Accessible_From_Client='No'
    if [ 'postgres' == $TestDatabaseType ] 
    then
        # Get PG Server Status
        PGPASSWORD=$PassWord pg_isready -h $Server -U $UserName > /dev/null && Is_Test_Server_Accessible_From_Client='Yes'
    else
        Is_Test_Server_Accessible_From_Client='UnknownDB'
    fi
    echo $Is_Test_Server_Accessible_From_Client
}

function CurrentTestActiveConnections ()
{
    Current_Test_Active_Connections=0
    
    if [ 'pgbench' == $TestType ] 
    then
        Current_Test_Active_Connections=`netstat -napt 2>/dev/null | grep pgbench | wc -l`
    fi
    echo $Current_Test_Active_Connections
}

function IsTestExecuting ()
{
    Is_Test_Executing="No"

    if [ 'pgbench' == $TestType ] 
    then
        # Check if pgbench is executing on client machine
        if [ `ps -ef | grep pgbench| wc -l` -gt 1 ]
        then
            Is_Test_Executing="Yes"
        fi
    else
        Is_Test_Executing="UnknownTest"
    fi
    echo $Is_Test_Executing
}

function UpdateResourceHeathToLogsDB ()
{
    echo "Pushing stats to LogsDB '$LogsDbServer' into table '$ResourceHealthTableName' ------ " `GetCurrentDateTimeInSQLFormat`

    Client_Hostname=`hostname`
    Test_Server_fqdn=$Server
    Test_Server_Environment=$Environment
    Test_Server_Region=$Region
    Test_Database_Type=$TestDatabaseType
    Test_Type=$TestType

    Client_Last_HeartBeat=`GetCurrentDateTimeInSQLFormat`

    Is_Test_Server_Accessible_From_Client=`IsTestServerAccessibleFromClient`

    #Set 'Server_Last_HeartBeat' if Test_Server_fqdn is Accessible
    if [ $Is_Test_Server_Accessible_From_Client == 'Yes' ] 
    then
        Server_Last_HeartBeat=`GetCurrentDateTimeInSQLFormat`
    else
        Server_Last_HeartBeat='1900-01-01 00:00:00'
    fi

    Is_Test_Executing=`IsTestExecuting`

    # Get few latest lines from test log
    Recent_Test_Logs=''
    Recent_Test_Logs=`tail -5 $HOME/Logs/*.log 2>/dev/null | tail -c 300`

    if [ -z "$Recent_Test_Logs" ]
    then
        Recent_Test_Logs=`tail -5 $HOME/runLog.log 2>/dev/null | tail -c 300`
        if [ -z "$Recent_Test_Logs" ]
        then
            Recent_Test_Logs="Sorry no logs available!"
        fi
    fi
    
    # Check many connections are established between client and server
    Current_Test_Active_Connections=`CurrentTestActiveConnections`

    # Now get some Client Linux VM stats
    Client_Memory_Usage_Percentage=`free | grep Mem | awk '{print $3/$2 * 100.0}'`
    Client_Cpu_Usage_Percentage=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'`
    Client_Root_Disk_Usage_Percentage=`df -h| grep "\/$"| awk '{print $5}'| sed "s/%//"`
    Client_Last_Reboot=`uptime -p | sed 's/^up //'`

    # -----------------------------------------------------------------------------------
    # Insert / Update heart beat info  into $ResourceHealthTableName table of the logs DB
    # -----------------------------------------------------------------------------------

    # Check if an entry aleady exists for this client
    RowExists='No'

    PGPASSWORD=$LogsDbServerPassword psql -h $LogsDbServer -U $LogsDbServerUsername -d $LogsDataBase -c "SELECT * FROM $ResourceHealthTableName where Client_Hostname='"$Client_Hostname"'" | grep $Client_Hostname > /dev/null 

    if [ $? == 0 ]
    then
        RowExists='Yes'
        if [ $Is_Test_Server_Accessible_From_Client == 'No' ] 
        then
            echo "Check if Server_Last_HeartBeat from server is older than specific time and diclare server dead and client as free." 
        fi
    else
        RowExists='No'
    fi

    if [ $RowExists == 'No' ]
    then
        # Insert a new row if one doesn't exists for this client
        sql_cmd="INSERT INTO $ResourceHealthTableName ( \
                Client_Hostname, \
                Test_Server_fqdn, \
                Test_Server_Environment, \
                Test_Server_Region, \
                Test_Database_Type, \
                Test_Type, \
                Client_Last_HeartBeat, \
                Server_Last_HeartBeat, \
                Is_Test_Server_Accessible_From_Client, \
                Is_Test_Executing, \
                Current_Test_Active_Connections, \
                Client_Memory_Usage_Percentage, \
                Client_Cpu_Usage_Percentage, \
                Client_Root_Disk_Usage_Percentage, \
                Client_Last_Reboot \
            ) VALUES ( 
                '$Client_Hostname', \
                '$Test_Server_fqdn', \
                '$Test_Server_Environment', \
                '$Test_Server_Region', \
                '$Test_Database_Type', \
                '$Test_Type', \
                '$Client_Last_HeartBeat', \
                '$Server_Last_HeartBeat', \
                '$Is_Test_Server_Accessible_From_Client', \
                '$Is_Test_Executing', \
                $Current_Test_Active_Connections, \
                $Client_Memory_Usage_Percentage, \
                $Client_Cpu_Usage_Percentage, \
                $Client_Root_Disk_Usage_Percentage, \
                '$Client_Last_Reboot' \
        ); "
    else
    # If Test_Server_fqdn is NOT accessible skip 'Server_Last_HeartBeat' value and update all values
        sql_cmd="UPDATE $ResourceHealthTableName  \
        set \
            Test_Server_fqdn='$Test_Server_fqdn', \
            Test_Server_Environment='$Test_Server_Environment', \
            Test_Server_Region='$Test_Server_Region', \
            Test_Database_Type='$Test_Database_Type', \
            Test_Type='$Test_Type', \
            Client_Last_HeartBeat='$Client_Last_HeartBeat', \
            Is_Test_Server_Accessible_From_Client='$Is_Test_Server_Accessible_From_Client', \
            Is_Test_Executing='$Is_Test_Executing', \
            Current_Test_Active_Connections=$Current_Test_Active_Connections, \
            Client_Memory_Usage_Percentage=$Client_Memory_Usage_Percentage, \
            Client_Cpu_Usage_Percentage=$Client_Cpu_Usage_Percentage, \
            Client_Root_Disk_Usage_Percentage=$Client_Root_Disk_Usage_Percentage, \
            Client_Last_Reboot='$Client_Last_Reboot' \
        WHERE Client_Hostname='$Client_Hostname'; "
    fi
    echo "sql_cmd: $sql_cmd"
    ExecuteQueryOnLogsDB "$sql_cmd"

    # Updating Recent_Test_Logs into ResourceHealthTableName
    sql_cmd="UPDATE $ResourceHealthTableName  \
        set \
            Recent_Test_Logs='$Recent_Test_Logs' \
        WHERE Client_Hostname='$Client_Hostname'; "
    
    echo "sql_cmd: $sql_cmd"
    ExecuteQueryOnLogsDB "$sql_cmd"

# Update heart beat info  into $ServerInfoTableName and $ResourceHealthTableName tables if Server is accessible
    if [ $Is_Test_Server_Accessible_From_Client == 'Yes' ] 
    then
        sql_server_cmd="UPDATE $ResourceHealthTableName set \
                Server_Last_HeartBeat='$Server_Last_HeartBeat' \
            WHERE Client_Hostname='$Client_Hostname'; \
            UPDATE $ServerInfoTableName set \
                Server_Last_HeartBeat='$Server_Last_HeartBeat' \
            WHERE Test_Server_fqdn='$Test_Server_fqdn' ; "

        echo "sql_server_cmd: $sql_server_cmd"
        ExecuteQueryOnLogsDB "$sql_server_cmd"
    else
        echo "Skipping to update Server_info table as server is not accessible from server"
    fi

    # Update heart beat info  into $ClientInfoTableName table of the logs DB
    sql_cmd="UPDATE $ClientInfoTableName \
        set \
            Client_Last_HeartBeat='$Client_Last_HeartBeat' \
        WHERE Client_Hostname='$Client_Hostname'; "  
    # 1 Query for all the updates/inserts
    echo "sql_cmd: $sql_cmd"
    ExecuteQueryOnLogsDB "$sql_cmd"
}
#------------------------------

echo "-------------------------------- `GetCurrentDateTimeInSQLFormat` -------------------------------- " >> $UpdateResourceHeathToLogsDBLogFile

UpdateResourceHeathToLogsDB >> $UpdateResourceHeathToLogsDBLogFile 2>&1
