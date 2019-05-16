#!/bin/bash
#
# This common routines for DB benchmark automation.
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
# Author: Srikanth Myakam
#
########################################################################

function GetCurrentDateTimeInSQLFormat()
{
    date "+%Y-%m-%d %H:%M:%S"
}

function SendMail()
{
    Attachment=$1
    Subject_tag=$2
    MailBody=$3
    echo $MailBody
    ReportEmail=`grep "ReportEmail" $TestDataFile`
    echo "Sending Email Report to $ReportEmail with $Attachment attached and body: "`head $MailBody`

    Subject="*`hostname`* - "$Subject_tag 
    mail -a "From:Alfred" -a 'MIME-Version: 1.0' -a 'Content-Type: text/html; charset=iso-8859-1' -a 'X-AUTOR: Ing. Gareca' -s "$Subject" $ReportEmail -A $Attachment < $MailBody
}

function get_MinMax()
{
    inputArray=("$@")
    count=${#inputArray[@]}
    lastIndex=$((count-1))

    IFS=$'\n' sorted=($(sort -n <<<"${inputArray[*]}"))
    unset IFS
    min=`printf "%.f\n" ${sorted[0]}`
    max=`printf "%.f\n" ${sorted[$lastIndex]}`
    echo "$min,$max"
}

function get_Avg()
{
    inputArray=("$@")
    count=${#inputArray[@]}
    sum=$( IFS="+"; bc <<< "${inputArray[*]}" )
    unset IFS
    average=`echo $sum/$count|bc -l`
    printf "%.1f\n" $average
}

function get_Column_Avg()
{
    local filename=$1
    local results
    columns=`tail -1 $filename |wc -w`
    i=0
    for j in $(seq 1 $columns)
    do
        results[$i]=`get_Avg $(cat $filename | awk -vcol=$j '{print $col}')`
        ((i++))
    done
    echo ${results[*]}| sed 's/ /,/g'
}

function get_Sum()
{
    inputArray=("$@")
    sum=$( IFS="+"; bc <<< "${inputArray[*]}" )
    unset IFS
    echo $sum
}

function CheckDependencies()
{
    if [ ! -f ConnectionProperties.csv ]; then
        echo "ERROR: ConnectionProperties.csv: File not found!"
        exit 1
    fi

    if [[ `which sar` == "" ]]; then
        echo "INFO: sysstat: not installed!"
        echo "INFO: sysstat: Trying to install!"
        sudo apt install sysstat -y
    fi

    if [[ `which bc` == "" ]]; then
        echo "INFO: bc: not installed!"
        echo "INFO: bc: Trying to install!"
        sudo apt install bc -y
    fi

    if [[ `which pgbench` == "" ]]; then
        echo "INFO: pgbench: not installed!"
        echo "INFO: pgbench: Trying to install!"
        sudo apt install postgresql-contrib -y
    fi
}

function LowerCase()
{
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

function exit_script()
{
    echo $1
    SendMail $LogFile "$1" $2
    exit 
}

function ExecuteQueryOnLogsDB()
{
    # Warning: Don't keep any echo statments in this routie as the output of this function used as it is.
    sql_cmd="$@"
    PGPASSWORD=$LogsDbServerPassword psql -h $LogsDbServer -U $LogsDbServerUsername -d $LogsDataBase -c "$sql_cmd" 
}

#-------------------------------------------------------------------
#   Execution starts from here
#-------------------------------------------------------------------

# Read config from config file
export TestDataFile='ConnectionProperties.csv'
export TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))

# Logs DB SQL server details
export LogsDbServer=`grep "LogsDbServer\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsDbServerUsername=`grep "LogsDbServerUsername\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsDbServerPassword=`grep "LogsDbServerPassword\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsDataBase=`grep "LogsDataBase" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsTableName=`grep "LogsTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export ResourceHealthTableName=`grep "ResourceHealthTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export ServerInfoTableName=`grep "ServerInfoTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export ClientInfoTableName=`grep "ClientInfoTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export ScheduledTestsTable=`grep "ScheduledTestsTable" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

export Client_Hostname=`hostname`
export Duration=""
export ConnectionsList=()
export ScaleFactor=""


# Get test config assigned for this server from logs db server
rm -rf $HOME/test_config.sh > /dev/null 2>&1 
# Get test_parameters_script column from $ScheduledTestsTable for this client $Client_Hostname
ExecuteQueryOnLogsDB "select test_parameters_script from $ScheduledTestsTable WHERE Client_Hostname='$Client_Hostname';" | sed 's/+//'| sed 's/^ //'| grep -v "^[-(]"| sed s/test_parameters_script// > $HOME/test_config.sh

if [ `wc $HOME/test_config.sh | awk '{print $2}'` == 0 ]
then
    echo "I couldn't find any test configuration assigned for me ($Client_Hostname) on log server"
else
    . $HOME/test_config.sh
    # Get Test Server assigned for this client from '$ClientInfoTableName' table
    Client_Info=($(ExecuteQueryOnLogsDB "select * from $ClientInfoTableName  where client_hostname='$Client_Hostname'" | grep $Client_Hostname|sed 's/ //g'|sed 's/|/,/g'|sed 's/,/ /g'))

    if [ -z "$Client_Info" ] 
    then
        echo "FATAL: Cannot find my details ('$Client_Hostname') in ClientInfoTableName:$ClientInfoTableName"
        echo "FATAL: Cannot run any tests"
    else
        export Client_VM_SKU=${Client_Info[5]}
        
        Scheduled_Test_Info=($(ExecuteQueryOnLogsDB "select * from $ScheduledTestsTable  where client_hostname='$Client_Hostname'" | grep $Client_Hostname|sed 's/ //g'|sed 's/|/,/g'|sed 's/,/ /g'))

        if [ -z "$Scheduled_Test_Info" ]
        then
            echo "INFO: Cannot find any scheduled tests for me ('$Client_Hostname') deatils in Scheduled_Test_Info:$Scheduled_Test_Info"
            echo "INFO: No test will be executed"
        else
            export Server=${Scheduled_Test_Info[1]}
            export TestType=${Scheduled_Test_Info[2]}
            if [ -z "$Server" ]
            then
                echo "INFO: No server assigned for me ('$Client_Hostname') in ScheduledTestsTable:$ScheduledTestsTable"
                echo "INFO: No test will be executed"
            else
                echo "INFO: Server assigned for me ('$Client_Hostname') is: $Server"
                
                # Update $ClientInfoTableName table with this server
                sql_cmd="UPDATE $ClientInfoTableName  \
                        set \
                            Test_Server_Assigned='$Server' \
                        WHERE Client_Hostname='$Client_Hostname'; "

                ExecuteQueryOnLogsDB "$sql_cmd"

                # Now get Test Server details from $ServerInfoTableName table
                Server_Info=($(ExecuteQueryOnLogsDB "select * from $ServerInfoTableName  where Test_Server_fqdn='$Server'" | grep $Server|sed 's/ //g'|sed 's/|/,/g'|sed 's/,/ /g'))

                if [ -z "$Server_Info" ] 
                then
                    echo "FATAL: Cannot find Server ('$Server') deatils in ServerInfoTableName:$ServerInfoTableName"
                    echo "FATAL: No test will be executed"
                else
                    export Region=${Server_Info[2]}
                    export Environment=${Server_Info[3]}
                    export Test_Server_Edition=${Server_Info[4]}
                    export Test_Server_CPU_Cores=${Server_Info[5]}
                    export Test_Server_Storage_In_MB=${Server_Info[6]}
                    export UserName=${Server_Info[7]}
                    export PassWord=${Server_Info[8]}
                    export TestDatabaseType=${Server_Info[9]}
                    export TestDatabase=${Server_Info[10]}
                    export TestDatabaseTopology=${Server_Info[11]}

                    #Get test and DB under test type from test config
                    #TestType=`grep "TestType\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
                    #TestDatabaseType=`grep "TestDatabaseType\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

                    export TestType=`LowerCase $TestType`
                    export TestDatabaseType=`LowerCase $TestDatabaseType`

                    printf "Client_Hostname=$Client_Hostname\nServer=$Server\nRegion=${Server_Info[2]}\nEnvironment=${Server_Info[3]}\nTest_Server_Edition=${Server_Info[4]}\nTest_Server_CPU_Cores=${Server_Info[5]}\nTest_Server_Storage_In_MB=${Server_Info[6]}\nUserName=${Server_Info[7]}\nPassWord=${Server_Info[8]}\nTestDatabaseType=${Server_Info[9]}\nTestDatabase=${Server_Info[10]}\nClient_VM_SKU=${Client_Info[5]}\nTestType=$TestType\nTestDatabaseType=$TestDatabaseType\n"
                    printf "Test Configuration: \n Duration:$Duration\n ScaleFactor:$ScaleFactor\n"
                    echo "ConnectionsList:${ConnectionsList[@]}"
                fi
            fi
        fi
    fi
fi
