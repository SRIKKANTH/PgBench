#!/bin/bash
#
# This commont routines for pgbench automation.
#
# Author: Srikanth Myakam (v-srm@microsoft.com)
#
########################################################################


function GetCurrentDateTimeInSQLFormat ()
{
    date "+%Y-%m-%d %H:%M:%S"
}

function SendMail ()
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

CheckDependencies()
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

    if [[ `which pgbench` == "" ]]; then
        echo "INFO: pgbench: not installed!"
        echo "INFO: pgbench: Trying to install!"
        sudo apt install postgresql-contrib -y
    fi
}

export PATH="$PATH:/opt/mssql-tools/bin"

export TestDataFile='ConnectionProperties.csv'
export TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))
# Test Server Details
export Server=${TestData[1]}
export UserName=${TestData[4]}
export PassWord=${TestData[5]}
export Environment=${TestData[6]}
export Region=${TestData[7]}

# Logs DB SQL server details
export LogsDbServer=`grep "LogsDbServer\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsDbServerUsername=`grep "LogsDbServerUsername\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsDbServerPassword=`grep "LogsDbServerPassword\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsDataBase=`grep "LogsDataBase" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export LogsTableName=`grep "LogsTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
export ResourceHealthTableName=`grep "ResourceHealthTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

#export UserName=postgres@$(echo $Server | sed s/\\..*//)

