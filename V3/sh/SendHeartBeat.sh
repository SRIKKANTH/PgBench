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
#   Test_Server VARCHAR(100),
#   Test_Server_Environment VARCHAR(25),
#   Test_Server_Region VARCHAR(25),
#   Database_Type  VARCHAR(25),
#   Test_Type VARCHAR(25),
#   Client_Last_HeartBeat timestamp,
#   Server_Last_HeartBeat timestamp,
#   Is_Test_Server_Accessible_From_Client VARCHAR(25),
#   Is_Test_Executing VARCHAR(25),
#   Current_Test_Active_Connections int,
#   Client_Memory_Usage_Percentage float,
#   Client_Cpu_Usage_Percentage float,
#   Client_Root_Disk_Usage_Percentage float,
#   Recent_Test_Logs VARCHAR(300)
# )
#
# Author: Srikanth Myakam
#
########################################################################
. $HOME/CommonRoutines.sh

export UpdateResourceHeathToLogsDBLogFile=$HOME/UpdateResourceHeathToLogsDB.log

function IsTestServerAccessibleFromClient ()
{
    Is_Test_Server_Accessible_From_Client='No'
    if [ 'postgres' == $DatabaseType ] 
    then
        # Get PG Server Status
        PGPASSWORD=$PassWord pg_isready -h $Server -U $UserName > /dev/null && Is_Test_Server_Accessible_From_Client='Yes'
    else
        Is_Test_Server_Accessible_From_Client='UnknownDB'
    fi
    echo $Is_Test_Server_Accessible_From_Client
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
    echo "Pushing stats ($ToLogsDbFileCsv) to LogsDB '$LogsDbServer' into table '$ResourceHealthTableName' ------ " `GetCurrentDateTimeInSQLFormat`

    Client_Hostname=`hostname`
    Test_Server=$Server
    Test_Server_Environment=$Environment
    Test_Server_Region=$Region
    Database_Type=$DatabaseType
    Test_Type=$TestType

    Client_Last_HeartBeat=`GetCurrentDateTimeInSQLFormat`

    Is_Test_Server_Accessible_From_Client=`IsTestServerAccessibleFromClient`

    #Set 'Server_Last_HeartBeat' if Test_Server is Accessible
    if [ $Is_Test_Server_Accessible_From_Client == 'Yes' ] 
    then
        Server_Last_HeartBeat=`GetCurrentDateTimeInSQLFormat`
    else
        Server_Last_HeartBeat='1900-01-01 00:00:00'
    fi

    Is_Test_Executing=`IsTestExecuting`

    Recent_Test_Logs=`tail -5 Logs/*.log| tail -c 300`

    Current_Test_Active_Connections=`netstat -napt 2>/dev/null | grep pgbench | wc -l`
    Client_Memory_Usage_Percentage=`free | grep Mem | awk '{print $3/$2 * 100.0}'`
    Client_Cpu_Usage_Percentage=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'`
    Client_Root_Disk_Usage_Percentage=`df -h| grep "\/$"| awk '{print $5}'| sed "s/%//"`

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
                    Test_Server, \
                    Test_Server_Environment, \
                    Test_Server_Region, \
                    Database_Type, \
                    Test_Type, \
                    Client_Last_HeartBeat, \
                    Server_Last_HeartBeat, \
                    Is_Test_Server_Accessible_From_Client, \
                    Is_Test_Executing, \
                    Current_Test_Active_Connections, \
                    Client_Memory_Usage_Percentage, \
                    Client_Cpu_Usage_Percentage, \
                    Client_Root_Disk_Usage_Percentage, \
                    Recent_Test_Logs \
                ) VALUES ( 
                    '$Client_Hostname', \
                    '$Test_Server', \
                    '$Test_Server_Environment', \
                    '$Test_Server_Region', \
                    '$Database_Type', \
                    '$Test_Type', \
                    '$Client_Last_HeartBeat', \
                    '$Server_Last_HeartBeat', \
                    '$Is_Test_Server_Accessible_From_Client', \
                    '$Is_Test_Executing', \
                    $Current_Test_Active_Connections, \
                    $Client_Memory_Usage_Percentage, \
                    $Client_Cpu_Usage_Percentage, \
                    $Client_Root_Disk_Usage_Percentage, \
                    '$Recent_Test_Logs' \
            );"
    else
        # Update the row if one exists for this client
        if [ $Is_Test_Server_Accessible_From_Client == 'Yes' ] 
        then
        # If Test_Server is accessible update all values
            sql_cmd="UPDATE $ResourceHealthTableName  \
            set \
                Test_Server='$Test_Server', \
                Test_Server_Environment='$Test_Server_Environment', \
                Test_Server_Region='$Test_Server_Region', \
                Database_Type='$Database_Type', \
                Test_Type='$Test_Type', \
                Client_Last_HeartBeat='$Client_Last_HeartBeat', \
                Server_Last_HeartBeat='$Server_Last_HeartBeat', \
                Is_Test_Server_Accessible_From_Client='$Is_Test_Server_Accessible_From_Client', \
                Is_Test_Executing='$Is_Test_Executing', \
                Current_Test_Active_Connections=$Current_Test_Active_Connections, \
                Client_Memory_Usage_Percentage=$Client_Memory_Usage_Percentage, \
                Client_Cpu_Usage_Percentage=$Client_Cpu_Usage_Percentage, \
                Client_Root_Disk_Usage_Percentage=$Client_Root_Disk_Usage_Percentage, \
                Recent_Test_Logs='$Recent_Test_Logs' \
            WHERE Client_Hostname='$Client_Hostname'"
        else
        # If Test_Server is NOT accessible skip 'Server_Last_HeartBeat' value and update all values
            sql_cmd="UPDATE $ResourceHealthTableName  \
            set \
                Test_Server='$Test_Server', \
                Test_Server_Environment='$Test_Server_Environment', \
                Test_Server_Region='$Test_Server_Region', \
                Database_Type='$Database_Type', \
                Test_Type='$Test_Type', \
                Client_Last_HeartBeat='$Client_Last_HeartBeat', \
                Is_Test_Server_Accessible_From_Client='$Is_Test_Server_Accessible_From_Client', \
                Is_Test_Executing='$Is_Test_Executing', \
                Current_Test_Active_Connections=$Current_Test_Active_Connections, \
                Client_Memory_Usage_Percentage=$Client_Memory_Usage_Percentage, \
                Client_Cpu_Usage_Percentage=$Client_Cpu_Usage_Percentage, \
                Client_Root_Disk_Usage_Percentage=$Client_Root_Disk_Usage_Percentage, \
                Recent_Test_Logs='$Recent_Test_Logs' \
            WHERE Client_Hostname='$Client_Hostname'"
        fi
    fi

    echo "executing sqlcmd : $sql_cmd"
    PGPASSWORD=$LogsDbServerPassword psql -h $LogsDbServer -U $LogsDbServerUsername -d $LogsDataBase -c "$sql_cmd" 
}

echo "-------------------------------- `GetCurrentDateTimeInSQLFormat` -------------------------------- " >> $UpdateResourceHeathToLogsDBLogFile
UpdateResourceHeathToLogsDB >> $UpdateResourceHeathToLogsDBLogFile 2>&1
