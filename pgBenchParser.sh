#!/bin/bash
#
# This script converts pgbench IO output file into csv format.
# Author: Srikanth Myakam
# Email	: 
####

export PATH="$PATH:/opt/mssql-tools/bin"

export DEBUG=0

TestDataFile=ConnectionProperties.csv

PerformanceTestMode="Performance"
LongHaulTestMode="LongHaul"
export COLLECT_SERVER_STATS=1
MatchingPattern="$PerformanceTestMode\|$LongHaulTestMode"

function DebugLog ()
{
    if [ $DEBUG -ge 1 ]
    then
        >&2 echo $1
    fi
}

function FixOutput ()
{
    [ -z "$1" ] && echo 0 || echo $1
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

function get_Sum()
{
    inputArray=("$@")
    sum=$( IFS="+"; bc <<< "${inputArray[*]}" )
    unset IFS
    echo $sum
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

function get_Percentage ()
{
    printf "%.1f\n" `echo 100*$1/$2 |bc -l`
}

function HowGoodIsIt()
{
    CurrentValue=$1
    ReferenceValue=$2
    
    Difference=`echo $CurrentValue-$ReferenceValue |bc -l`
    Difference=`get_Percentage $Difference $ReferenceValue`

    if [ `echo "$CurrentValue == 0" | bc -l` != 0 ]
    then 
        echo "Aborted ($Difference%)"
    elif [ `echo "$Difference >= 0" | bc -l` != 0 ]
    then
        Difference="+$Difference"
        echo "Good ($Difference%)"
    elif [ `echo "$Difference >= -10" | bc -l` != 0 ]
    then
        echo "Normal ($Difference%)"
    elif [ `echo "$Difference >= -20" | bc -l` != 0 ]
    then
        echo "Bad ($Difference%)"
    elif [ `echo "$Difference < -20" | bc -l` != 0 ]
    then
        echo "Worst ($Difference%)"

    fi
}

function Parse
{
    log_file_name=$1

    if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <pgbench-output.log>" >&2
    exit 1
    fi

    if [ ! -f $log_file_name ]; then
        echo "$1: File not found!"
        exit 1
    fi

    csv_file=`echo $log_file_name | sed "s/\.log/\.csv/"`

    res_Iteration=(`grep "Starting the test iteration"  $log_file_name | awk '{print $6}'`)
    res_TransactionType=(`grep "transaction type:"  $log_file_name| sed "s/transaction type://"|sed "s/ //"|sed "s/ /_/g"`)
    res_ScalingFactor=(`grep  ScaleFactor: $log_file_name | awk '{print $2}'`)
    res_QueryMode=(`grep "query mode:"  $log_file_name | awk '{print $3}'`)
    res_Clients=(`grep  Clients: $log_file_name | awk '{print $2}'`)
    res_Threads=(`grep  Threads: $log_file_name | awk '{print $2}'`)
    res_Duration=(`grep "duration:"  $log_file_name| sed "s/duration: //"|sed "s/ //g"`)
    res_TotalTransaction=(`grep "number of transactions actually processed: "  $log_file_name | awk '{print $6}'`)
    res_AvgLatency=(`grep "latency average: "  $log_file_name | sed "s/latency average: //"|sed "s/ //g"`)
    if [ ${#res_AvgLatency[@]} == 0 ]
    then
        res_AvgLatency=(`grep "latency average ="  $log_file_name | sed "s/latency average =//"|sed "s/ //g"`)
    fi
    res_StdDevLatency=(`grep "latency stddev: "  $log_file_name | sed "s/latency stddev: //"|sed "s/ //g"`)
    if [ ${#res_StdDevLatency[@]} == 0 ]
    then
        res_StdDevLatency=(`grep "latency stddev ="  $log_file_name | sed "s/latency stddev =//"|sed "s/ //g"`)
    fi
    res_TPSIncConnEstablishing=(`grep "tps.*including connections establishing"  $log_file_name | awk '{print $3}'`)
    res_TPSExcludingConnEstablishing=(`grep "tps.*excluding connections establishing"  $log_file_name | awk '{print $3}'`)
    res_PgServer=(`grep  Server: $log_file_name | awk '{print $2}'`)
    res_Duration=(`grep duration $log_file_name| awk '{print $2}'`)
    
    VmVcores=`grep "VMcores" $log_file_name| awk '{print $2}'`

    res_OsMemoryStats=(`grep "^Memory stats OS" $log_file_name | sed "s/^.*:  //"`)
    res_OsCpuUsage=(`grep "^CPU usage (OS)" $log_file_name | sed "s/^.*:  //"`)
    res_PgBenchClientConnections=(`grep "^Connections" $log_file_name | sed "s/^.*:  //"`)
    res_PgBenchCpuMemUtilization=(`grep "^CPU,MEM usage (pgbench)" $log_file_name | sed "s/^.*:  //"`)


    if [ $COLLECT_SERVER_STATS == 1 ]
    then
        res_Network_rx_Server=(`grep "ServerNetwork rx" $log_file_name | awk '{print $4$2}'| sed "s/rx/-/" `)
        res_Network_tx_Server=(`grep "ServerNetwork tx" $log_file_name | awk '{print $4$2}'| sed "s/tx/-/" `)
        res_PgConnections_Server=(`grep "ServerConnections" $log_file_name | sed "s/^.*:  //"`)
        res_OsCpuUsage_Server=(`grep "ServerCPU usage (OS)" $log_file_name | sed "s/^.*:  //"`)
        res_OsMemoryStats_Server=(`grep "ServerMemory stats OS" $log_file_name | sed "s/^.*:  //"`)
        
        #/dev/sdc datadrive
        res_ServerDiskAverage_sdc_Server=(`grep "ServerDisk sde" $log_file_name  |awk '{print $4}'`)
        res_ServerDiskMinMaxIOPS_sdc_Server=(`grep "ServerDiskIOPSMinMax sde" $log_file_name  |awk '{print $4}'`)
        res_ServerDiskMinMaxReadMBps_sdc_Server=(`grep "ServerDiskReadMBpsMinMax sde" $log_file_name  |awk '{print $4}'`)
        res_ServerDiskMinMaxWriteMBps_sdc_Server=(`grep "ServerDiskWriteMBpsMinMax sde" $log_file_name  |awk '{print $4}'`)

        #/dev/sdd logdrive
        res_ServerDiskAverage_sdd_Server=(`grep "ServerDisk sdf" $log_file_name  |awk '{print $4}'`)
        res_ServerDiskMinMaxIOPS_sdd_Server=(`grep "ServerDiskIOPSMinMax sdf" $log_file_name  |awk '{print $4}'`)
        res_ServerDiskMinMaxReadMBps_sdd_Server=(`grep "ServerDiskReadMBpsMinMax sdf" $log_file_name  |awk '{print $4}'`)
        res_ServerDiskMinMaxWriteMBps_sdd_Server=(`grep "ServerDiskWriteMBpsMinMax sdf" $log_file_name  |awk '{print $4}'`)

        echo "Iteration,ScalingFactor,Clients,Threads,TotalTransaction,AvgLatency,StdDevLatency,TPSIncConnEstablishing,TPSExcludingConnEstablishing,TransactionType,QueryMode,Duration,ClientOsMemoryStats-Total,ClientOsMemoryStats-Used,ClientOsMemoryStats-Free,ClientOsCpuUsage,PgBenchClientConnections,PgBenchCpuUsage,PgBenchMemUsage,PgServer,Network_rx_ServerAvg,Network_tx_ServerAvg,PgConnections_ServerAvg,OsCpuUsage_Server,OsMemoryStats_Server-Total,Used,Free,sdcIOPSAvg,sdcMbpsReadAvg,sdcMbpsWriteAvg,sdcIOPSMin,sdcIOPSMax,sdcReadMBpsMin,sdcReadMBpsMax,sdcWriteMBpsMin,sdcWriteMBpsMax,sddIOPSAvg,sddMbpsReadAvg,sddMbpsWriteAvg,sddIOPSMin,sddIOPSMax,sddReadMBpsMin,sddReadMBpsMax,sddWriteMBpsMin,sddWriteMBpsMax"  > $csv_file
    else
        echo "Iteration,ScalingFactor,Clients,Threads,TotalTransaction,AvgLatency,StdDevLatency,TPSIncConnEstablishing,TPSExcludingConnEstablishing,TransactionType,QueryMode,Duration,ClientOsMemoryStats-Total,ClientOsMemoryStats-Used,ClientOsMemoryStats-Free,ClientOsCpuUsage,PgBenchClientConnections,PgBenchCpuUsage,PgBenchMemUsage,PgServer,"  > $csv_file
    fi

    count=0
    while [ "x${res_Iteration[$count]}" != "x" ]
    do
        if [ $COLLECT_SERVER_STATS == 1 ]
        then
            echo "${res_Iteration[$count]},${res_ScalingFactor[count]},${res_Clients[count]},${res_Threads[count]},${res_TotalTransaction[$count]},${res_AvgLatency[$count]},${res_StdDevLatency[$count]},${res_TPSIncConnEstablishing[$count]},${res_TPSExcludingConnEstablishing[$count]},${res_TransactionType[$count]},${res_QueryMode[$count]},${res_Duration[$count]},${res_OsMemoryStats[$count]},${res_OsCpuUsage[$count]},${res_PgBenchClientConnections[$count]},${res_PgBenchCpuMemUtilization[$count]},${res_PgServer[$count]},${res_Network_rx_Server[$count]},${res_Network_tx_Server[$count]},${res_PgConnections_Server[$count]},${res_OsCpuUsage_Server[$count]},${res_OsMemoryStats_Server[$count]},${res_ServerDiskAverage_sdc_Server[$count]},${res_ServerDiskMinMaxIOPS_sdc_Server[$count]},${res_ServerDiskMinMaxReadMBps_sdc_Server[$count]},${res_ServerDiskMinMaxWriteMBps_sdc_Server[$count]},${res_ServerDiskAverage_sdd_Server[$count]},${res_ServerDiskMinMaxIOPS_sdd_Server[$count]},${res_ServerDiskMinMaxReadMBps_sdd_Server[$count]},${res_ServerDiskMinMaxWriteMBps_sdd_Server[$count]},"  >> $csv_file
        else
            echo "${res_Iteration[$count]},${res_ScalingFactor[count]},${res_Clients[count]},${res_Threads[count]},${res_TotalTransaction[$count]},${res_AvgLatency[$count]},${res_StdDevLatency[$count]},${res_TPSIncConnEstablishing[$count]},${res_TPSExcludingConnEstablishing[$count]},${res_TransactionType[$count]},${res_QueryMode[$count]},${res_Duration[$count]},${res_OsMemoryStats[$count]},${res_OsCpuUsage[$count]},${res_PgBenchClientConnections[$count]},${res_PgBenchCpuMemUtilization[$count]},${res_PgServer[$count]}"  >> $csv_file
        fi
        ((count++))
    done
##################################################

    return 
##################################################
    total=$count

    avg_TPSIncConnEstablishing=`get_Avg "${res_TPSIncConnEstablishing[@]}" | sed 's/\\.[0-9]*//'`
    avg_TPSExcludingConnEstablishing=`get_Avg "${res_TPSExcludingConnEstablishing[@]}" | sed 's/\\.[0-9]*//'`

    minMax_TPSIncConnEstablishing=`get_MinMax "${res_TPSIncConnEstablishing[@]}"`
    minMax_TPSExcludingConnEstablishing=`get_MinMax "${res_TPSExcludingConnEstablishing[@]}"`

    TotalExecutionDuration=`get_Sum "${res_Duration[@]}"`
    DbInitializationDuration=`grep "Initializing .*Done" $log_file_name | awk '{print $6}'`

    count=0
    while [ "x${res_AvgLatency[$count]}" != "x" ]
    do
        res_AvgLatency[$count]=`echo ${res_AvgLatency[$count]}| sed 's/\\..*//g'`
        res_StdDevLatency[$count]=`echo ${res_StdDevLatency[$count]}| sed 's/\\..*//g'`
        ((count++))
    done

    AvgLatency=`get_Avg "${res_AvgLatency[@]}" | sed 's/\\.[0-9]*//'`
    StdDevLatency=`get_Avg "${res_StdDevLatency[@]}" | sed 's/\\.[0-9]*//'`

    # Parsing Client stats
    grep "^Memory stats OS" $log_file_name | sed "s/^.*:  //"| sed 's/,/ /g' > /tmp/ClientStats.tmp
    avg_OsMemoryStats=`get_Column_Avg /tmp/ClientStats.tmp`
    
    tmp_array=(`echo $avg_OsMemoryStats| sed 's/,/ /g'`)
    VmTotalMem=${tmp_array[0]}
    OsMemoryUsage=`get_Percentage ${tmp_array[1]} ${tmp_array[0]}`

    grep "^CPU usage (OS)" $log_file_name | sed "s/^.*:  //"| sed 's/,/ /g' > /tmp/ClientStats.tmp
    avg_OsCpuUsage=`get_Column_Avg /tmp/ClientStats.tmp`
    grep "^Connections" $log_file_name | sed "s/^.*:  //"| sed 's/,/ /g' > /tmp/ClientStats.tmp
    avg_PgBenchClientConnections=`get_Column_Avg /tmp/ClientStats.tmp`
    grep "^CPU,MEM usage (pgbench)" $log_file_name | sed "s/^.*:  //"| sed 's/,/ /g' > /tmp/ClientStats.tmp
    avg_PgBenchCpuMemUtilization=(`get_Column_Avg /tmp/ClientStats.tmp| sed 's/,/ /g'`)
    
    echo "" > $csv_file-tmp
    echo ",ServerConfiguration" >> $csv_file-tmp
    ServerVcores=`grep ${res_PgServer[0]} $TestDataFile | sed "s/,/ /g"| awk '{print $6}'`
    SpaceQuotaInMb=`grep ${res_PgServer[0]} $TestDataFile | sed "s/,/ /g"| awk '{print $7}'`
    ServerName=`echo ${res_PgServer[0]} | sed "s/-pip.*//"`
    echo ",ServerVcores,$ServerVcores" >> $csv_file-tmp
    echo ",SpaceQuotaInMb,$SpaceQuotaInMb" >> $csv_file-tmp
    echo ",ServerName,$ServerName" >> $csv_file-tmp
    echo "" >> $csv_file-tmp
    echo ",ServerStats" >> $csv_file-tmp
    echo ",,Average TPS,Min TPS,Max TPS" >> $csv_file-tmp
    echo ",TPSIncConnEstablishing,$avg_TPSIncConnEstablishing,$minMax_TPSIncConnEstablishing" >> $csv_file-tmp
    echo ",TPSExcludingConnEstablishing,$minMax_TPSExcludingConnEstablishing,$avg_TPSExcludingConnEstablishing" >> $csv_file-tmp
    echo "" >> $csv_file-tmp
    echo ",TotalExecutionDuration,$TotalExecutionDuration" >> $csv_file-tmp
    echo ",DbInitializationDuration,$DbInitializationDuration" >> $csv_file-tmp
    echo "" >> $csv_file-tmp
    echo ",AvgLatency,$AvgLatency" >> $csv_file-tmp
    echo ",StdDevLatency,$StdDevLatency" >> $csv_file-tmp
    echo "" >> $csv_file-tmp
    echo ",ClientConfiguration" >> $csv_file-tmp
    echo ",VmTotalMemory,$VmTotalMem" >> $csv_file-tmp
    echo ",VmVcores,$VmVcores" >> $csv_file-tmp
    echo "" >> $csv_file-tmp
    echo ",ClientStats" >> $csv_file-tmp
    echo ",ClientOsCpuUtilization,$avg_OsCpuUsage" >> $csv_file-tmp
    echo ",ClientOsMemoryUtilization,$OsMemoryUsage" >> $csv_file-tmp
    echo ",PgBenchClientConnections,$avg_PgBenchClientConnections" >> $csv_file-tmp
    echo ",PgBenchCpuUtilization,${avg_PgBenchCpuMemUtilization[0]}" >> $csv_file-tmp
    echo ",PgBenchMemUtilization,${avg_PgBenchCpuMemUtilization[1]}" >> $csv_file-tmp
    echo ",,Total,Used,Free" >> $csv_file-tmp
    echo ",OsMemoryUtilization,$avg_OsMemoryStats" >> $csv_file-tmp
    echo "" >> $csv_file-tmp
    echo ",TestParameters" >> $csv_file-tmp
    echo ",ScaleFactor,${res_ScalingFactor[0]}" >> $csv_file-tmp
    echo ",Clients,${res_Clients[0]}" >> $csv_file-tmp
    echo ",Threads,${res_Threads[0]}" >> $csv_file-tmp
    echo "" >> $csv_file-tmp

    cat $csv_file >> $csv_file-tmp
    mv $csv_file-tmp $csv_file

    echo $csv_file
}

function CSV2Html()
{
    CsvFileName=$1
    HtmlFileName=`echo $CsvFileName | sed "s/\.csv/\.html/"`
    cat $CsvFileName |sed "s/^,//g" |sed "s/ //g"  |awk -F"," 'BEGIN{    print "<table border="1">"}{
        print "<tr>";
        count=0
        for(i=1;i<=NF;i++){
            if($i == ""){
                count++
            }
            else{
                count++
                if(tolower($i) ~ /good/){
                    print "<td align=center colspan="count" bgcolor=#52D300><font color=black ><b>"$i"</b></font></td>";
                }else
                if(tolower($i) ~ /bad/){
                    print "<td align=center colspan="count" bgcolor=#FF7D7D><font color=black ><b>"$i"</b></font></td>";
                }else
                if(tolower($i) ~ /worst/){
                    print "<td align=center colspan="count" bgcolor=red><font color=white ><b>"$i"</b></font></td>";
                }else
                if(tolower($i) ~ /aborted/){
                    print "<td align=center colspan="count" bgcolor=Black><font color=white ><b>"$i"</b></font></td>";
                }else
                if(tolower($i) ~ /normal/){
                    print "<td align=center colspan="count" bgcolor=white><font color=Black ><b>"$i"</b></font></td>";
                }else{ 
                    print "<td align=center colspan="count">" $i"</td>";
                }
                count=0
            }       
        }
        print "</tr>"
    }END{print "</table>"}'  > $HtmlFileName
    echo $HtmlFileName
}

function GetReferenceTpsAvg ()
{
    local TestType=$1
    local Environment=$2
    local ServerType=$3
    local ServerVcores=$4
    local ScalingFactor=$5
    local Clients=$6
    local Threads=$7

    local LogsDbServer=`grep "LogsDbServer\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsDbServerUsername=`grep "LogsDbServerUsername\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsDbServerPassword=`grep "LogsDbServerPassword\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsDataBase=`grep "LogsDataBase" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsTableName=`grep "LogsTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

    local ReferenceValue=`sqlcmd -S $LogsDbServer -U $LogsDbServerUsername -P $LogsDbServerPassword  -d $LogsDataBase  -I -Q "SELECT  Avg(AverageTPS)  FROM $LogsTableName WHERE TestType = '$TestType' and ServerType='$ServerType' and Environment = '$Environment' and ServerVcores = $ServerVcores and AverageTPS != 0  and ScalingFactor = '$ScalingFactor' and Clients = '$Clients' and Threads = '$Threads'"`

    echo $ReferenceValue | awk '{print $2}'  | sed 's/\..*//' 2>&1
}

function SendMail ()
{
    MailBodyFile=$1
    Attachment=$2
    ReportEmail=$3

    echo "Sending Email Report to $ReportEmail with $Attachment"

    Subject='PG synthetic workload report: '`date +%F`
    mail  -a "From:Alfred" -a 'MIME-Version: 1.0' -a 'Content-Type: text/html; charset=iso-8859-1' -a 'X-AUTOR: Ing. Gareca' -s "$Subject" $ReportEmail -A $Attachment  < $MailBodyFile
}

function UploadStatsToLogsDB ()
{
    local ToLogsDbFileCsv=$1

    LogsDbServer=`grep "LogsDbServer\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    LogsDbServerUsername=`grep "LogsDbServerUsername\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    LogsDbServerPassword=`grep "LogsDbServerPassword\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    LogsDataBase=`grep "LogsDataBase" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    LogsTableName=`grep "LogsTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    
    echo "Pushing stats ($ToLogsDbFileCsv) to LogsDB '$LogsDbServer' into table '$LogsTableName'"

    bcp $LogsTableName in $ToLogsDbFileCsv -S $LogsDbServer -U $LogsDbServerUsername -P $LogsDbServerPassword -d $LogsDataBase -c  -t ',' 2>&1
}

function CopyToAzureStorageBlob ()
{
    FileToBeUploaded=$1
    StorageAccountUrl=$2
    DestinationKey=$3
    
    echo "FileToBeUploaded $FileToBeUploaded to $StorageAccountUrl$FileToBeUploaded with $DestinationKey"

    yes|azcopy --source $FileToBeUploaded --destination $StorageAccountUrl$FileToBeUploaded --dest-key $DestinationKey
}

function ParseAll()
{
    SummaryCsv="$log_folder/Summary.csv"
    ToLogsDbFileCsv="$log_folder/ToLogsDbFileCsv.csv"

    list=(`ls $log_folder/*.log | grep -v dmesg`)

    echo "" > $ToLogsDbFileCsv
    echo ",,,,,,ServerDetails,TestResult,ReferenceTpsAvg,,,TPS Including Connection Establishment,,Latencies,,,,,Client Stats,,,Test Parameters,,Execution Durations" > $SummaryCsv
    echo ",TestType,ServerType,ServerName,Environment,Vcores,SpaceQuotaInMb,---,---,Average TPS,Min TPS,Max TPS,AvgLatency(ms),StdDevLatency(ms),OsCpuUtilization%,OsMemoryUtilization%,PgBenchActiveConnections,PgBenchCpuUtilization%,PgBenchMemoryUtilization%,ScalingFactor,Clients,Threads,TotalExecution,DbInitialization" >> $SummaryCsv

    count=0
    while [ "x${list[$count]}" != "x" ]
    do
        echo "Parsing ${list[$count]}.."
        CsvFile=`Parse ${list[$count]}`
        ServerVcores=$(FixOutput `grep ServerVcores $CsvFile | sed "s/,/ /g"| awk '{print $2}'` 0 )
        SpaceQuotaInMb=$(FixOutput `grep SpaceQuotaInMb $CsvFile | sed "s/,/ /g"| awk '{print $2}'` 0 )
        ServerName=$(FixOutput `grep ServerName $CsvFile | sed "s/,/ /g"| awk '{print $2}'` NA )
        TPSIncConnEstablishing=$(FixOutput `grep TPSIncConnEstablishing $CsvFile | head -1 | sed "s/,TPSIncConnEstablishing,//g"` 0,0,0 )
        TPSExcludingConnEstablishing=$(FixOutput `grep TPSExcludingConnEstablishing $CsvFile  | head -1 | sed "s/,TPSExcludingConnEstablishing,//g"` 0.0,0.0,0.0 )
        TotalExecutionDuration=$(FixOutput `grep TotalExecutionDuration $CsvFile| awk -F"," '{print $3}'` 0 )
        DbInitializationDuration=$(FixOutput `grep DbInitializationDuration $CsvFile| awk -F"," '{print $3}'` 0 )
        OsMemoryUtilization=$(FixOutput `grep ClientOsMemoryUtilization $CsvFile| awk -F"," '{print $3}'` 0.0 )
        
        AvgLatency=$(FixOutput `grep AvgLatency $CsvFile| awk -F"," '{print $3}'` 0 )
        StdDevLatency=$(FixOutput `grep StdDevLatency $CsvFile| awk -F"," '{print $3}'` 0 )
        
        OsMemoryUtilization=$(FixOutput `grep ClientOsMemoryUtilization $CsvFile| awk -F"," '{print $3}'` 0.0 )
        OsCpuUtilization=$(FixOutput `grep ClientOsCpuUtilization $CsvFile| awk -F"," '{print $3}'` 0.0 )
        PgBenchCpuUtilization=$(FixOutput `grep PgBenchCpuUtilization $CsvFile| awk -F"," '{print $3}'` 0.0 )
        PgBenchMemoryUtilization=$(FixOutput `grep PgBenchMemUtilization $CsvFile| awk -F"," '{print $3}'` 0.0 )
        PgBenchActiveConnections=$(FixOutput `grep PgBenchClientConnections $CsvFile | head -1| awk -F"," '{print $3}'| sed "s/\..*//"` 0 )
        TestType=$(FixOutput `grep $ServerName  $TestDataFile | awk -F"," '{print $9}'` NA )
        ServerType=$(FixOutput `grep $ServerName  $TestDataFile | awk -F"," '{print $10}'` NA )
        Environment=$(FixOutput `grep $ServerName  $TestDataFile | awk -F"," '{print $11}'` NA )
        
        ScalingFactor=$(FixOutput `grep ScaleFactor $CsvFile | sed "s/,/ /g"| awk '{print $2}'` 0 )
        Clients=$(FixOutput `grep Clients $CsvFile | sed "s/,/ /g"| awk '{print $2}'` 0 )
        Threads=$(FixOutput `grep Threads $CsvFile | sed "s/,/ /g"| awk '{print $2}'` 0 )
        ExecutedOn=`date "+%Y-%m-%d %H:%M:%S"`

        local ReferenceTpsAvg=`GetReferenceTpsAvg $TestType $Environment $ServerType $ServerVcores $ScalingFactor $Clients $Threads`

        local CurrentTpsAvg=`echo $TPSIncConnEstablishing|awk -F"," '{print $1}'`

        local TestResult='NoReferenceData'
        
        DebugLog "CurrentTpsAvg=$CurrentTpsAvg, ReferenceTpsAvg=$ReferenceTpsAvg"

        re='^[0-9]+$'
        if [[ $ReferenceTpsAvg =~ $re ]] ; then
            TestResult=`HowGoodIsIt $CurrentTpsAvg $ReferenceTpsAvg` 
        else
            ReferenceTpsAvg='NoReferenceData'
        fi

        echo ",$TestType,$ServerType,$ServerName,$Environment,$ServerVcores,$SpaceQuotaInMb,$TestResult,$ReferenceTpsAvg,$TPSIncConnEstablishing,$AvgLatency,$StdDevLatency,$OsCpuUtilization,$OsMemoryUtilization,$PgBenchActiveConnections,$PgBenchCpuUtilization,$PgBenchMemoryUtilization,$ScalingFactor,$Clients,$Threads,$TotalExecutionDuration,$DbInitializationDuration" >> $SummaryCsv

        echo ",$TestType,$ServerName,$ServerType,$ServerVcores,$SpaceQuotaInMb,$TPSIncConnEstablishing,$ServerOsCpuUtilization,$ServerOsMemoryUtilization,$OsCpuUtilization,$OsMemoryUtilization,$PgBenchActiveConnections,$PgBenchCpuUtilization,$PgBenchMemoryUtilization,$ScalingFactor,$Clients,$Threads,$TotalExecutionDuration,$DbInitializationDuration,$ExecutedOn,$Environment,$StdDevLatency,$AvgLatency" >> $ToLogsDbFileCsv

        fileName=`basename $CsvFile`
        fileName=`echo $CsvFile |sed "s/$fileName/$ServerName\.csv/"`
        mv -fu $CsvFile $fileName 2>/dev/null 
        
        fileName=`basename ${list[$count]}`
        fileName=`echo ${list[$count]} |sed "s/$fileName/$ServerName\.log/"`
        mv -fu ${list[$count]} $fileName 2>/dev/null 

        ((count++))
    done
    
    if [ $DEBUG == 0 ]
    then
        UploadStatsToLogsDB $ToLogsDbFileCsv
    fi
    htmlFile=`CSV2Html $SummaryCsv`
    
    mkdir -p $log_folder/CSVs
    mv -f $log_folder/*.csv $log_folder/CSVs/
    reportZipFile=`date|sed "s/ /_/g"| sed "s/:/_/g"`.zip
    zip -r $reportZipFile $log_folder/*
   
    StorageAccountUrl=`grep "StorageAccountUrl" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    DestinationKey=`grep "DestinationKey" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    ReportEmail=`grep "ReportEmail" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

    SendMail $htmlFile $reportZipFile $ReportEmail

    if [ $DEBUG == 0 ]
    then
        CopyToAzureStorageBlob $reportZipFile $StorageAccountUrl $DestinationKey
    fi
    mv -f $reportZipFile OldLogs/
    echo "Parsing done!"
}

function CheckDependencies()
{
    if [ ! -f ConnectionProperties.csv ]; then
        echo "ERROR: ConnectionProperties.csv: File not found!"
        exit 1
    fi

    if [ ! -d $log_folder ]; then
        echo "ERROR: $log_folder: log_folder not found!"
        exit 1
    fi

    if [[ `which bc` == "" ]]; then
        echo "INFO: bc: not installed!"
        echo "INFO: bc: Trying to install!"
        sudo apt install bc -y
    fi
    
    if [[ `dpkg -l | grep mailutils| wc -l` == "0" ]]; then
        echo "INFO: mailutils: not installed!"
        echo "INFO: mailutils: Trying to install!"
        sudo apt-get install mailutils
    fi
}

function SetUpClients()
{
    TestDataFile='ConnectionProperties.csv'

    PerformanceTestMode="Performance"
    LongHaulTestMode="LongHaul"

    MatchingPattern="$PerformanceTestMode\|$LongHaulTestMode"

    ClientVMs=""

    ClientVMs=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))
    
    count=0
    while [ "x${ClientVMs[$count]}" != "x" ]
    do
        echo -e "ClientVM:\t"`ssh ${ClientVMs[$count]} hostname`
        VMUser=`echo ${ClientVMs[$count]} | sed 's/@.*//'`
            
        ssh-copy-id -i ~/.ssh/id_rsa.pub ${ClientVMs[$count]} 2>/dev/null
        ssh ${ClientVMs[$count]} "[ -d /home/$VMUser/W/Logs/ ] || mkdir -p /home/$VMUser/W/Logs/"

        FileList=( pbenchTest.sh RunTest.sh $TestDataFile)

        for FileToBeUploaded in "${FileList[@]}"
        do
            scp $FileToBeUploaded ${ClientVMs[$count]}:/home/$VMUser/W    
        done

        ssh ${ClientVMs[$count]} "chmod +x /home/$VMUser/W/*.sh"

        echo "--------------------------------------------------------"
        ((count++))
    done
}

function TestAllServers()
{
    TestDataFile='ConnectionProperties.csv'

    PerformanceTestMode="Performance"
    LongHaulTestMode="LongHaul"

    MatchingPattern="$PerformanceTestMode\|$LongHaulTestMode"

    UserName=$(grep -i "DbUserName," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
    PassWord=$(grep -i "DbPassWord," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

    Server=""
    ScaleFactor=""
    Connections=""
    Threads=""

    Server=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $2}'))
    ScaleFactor=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $3}'))
    Connections=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $4}'))
    Threads=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $5}'))
    ClientVMs=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))

    count=0
    while [ "x${Server[$count]}" != "x" ]
    do
        echo -e "ClientVM:\t"`ssh ${ClientVMs[$count]} hostname`
        echo -e "Server:\t${Server[$count]}"
        echo -e "ScaleFactor:\t${ScaleFactor[$count]}"
        echo -e "Connections:\t${Connections[$count]}"
        echo -e "Threads:\t${Threads[$count]}"
        pg_isready -U $UserName  -h ${Server[$count]} -p 5432 -d postgres
        echo "--------------------------------------------------------"
    ((count++))
    done
}

###############################################################
##
##              Script Execution Starts from here
###############################################################
CheckDependencies

[ ! -d OldLogs  ] && mkdir OldLogs

if [ "$#" -eq 1 ]; then
    DEBUG=1
    log_folder=$1
    ParseAll
    exit
fi

if [ $DEBUG != 0 ]
then
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 <path to pgbench logs>" >&2
        exit 1
    fi
    log_folder=$1
    ParseAll
    exit 1
fi

log_folder=`date|sed "s/ /_/g"| sed "s/:/_/g"`
mkdir -p $log_folder
echo "Getting logs from clients.."
TestDataFile='ConnectionProperties.csv'

res_ClientDetails=($(grep -i "$MatchingPattern" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))

count=1
while [ "x${res_ClientDetails[$count]}" != "x" ]
do
    VMUser=`ssh ${res_ClientDetails[$count]} 'echo $USER'`
    echo -e `ssh ${res_ClientDetails[$count]} 'hostname'`"\t:---"
    scp ${res_ClientDetails[$count]}:/home/$VMUser/W/Logs/* $log_folder/ 
    ssh ${res_ClientDetails[$count]} "bash /home/$VMUser/W/RunTest.sh"
    ((count++))
done
echo "Getting logs from clients.. done!"    

ParseAll

if [ ! -d OldLogs ]; then
    mkdir -p OldLogs
fi

mv -f $log_folder OldLogs/$log_folder
