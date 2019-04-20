#!/bin/bash
#
# This script converts pgbench output file into csv format.
#
# Author: Srikanth Myakam 
#
########################################################################

export PATH="$PATH:/opt/mssql-tools/bin"

export DEBUG=0

TestDataFile=ConnectionProperties.csv

PerformanceTestMode="Performance"
LongHaulTestMode="LongHaul"
export COLLECT_SERVER_STATS=0
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

get_raw_logs_report ()
{
    log_file_name=$1
    
    raw_csv_file=`echo $log_file_name | sed "s/\.log/-raw\.csv/"`
    
    Time=(`grep progress $log_file_name  | awk '{print $2}' | sed 's/\..*//'`)
    Tps=(`grep progress $log_file_name  | awk '{print $4}'`)
    Latency=(`grep progress $log_file_name  | awk '{print $7}'`)
    StdLatency=(`grep progress $log_file_name  | awk '{print $10}'`)
    res_ScalingFactor=(`grep  ScaleFactor: $log_file_name | awk '{print $2}'`)
    res_Clients=(`grep  Clients: $log_file_name | awk '{print $2}'`)
    res_Threads=(`grep  Threads: $log_file_name | awk '{print $2}'`)
    Server=`grep  Server: $log_file_name | awk '{print $2}' | head -1`
    TotalLength=$(( ${#Time[@]} + 6 ))
    echo "Average,Median,Stdev,3%,97%,Average %,> Average %,< Average %"> $raw_csv_file
    echo "=Average(E16:E$TotalLength),=Median(E16:E$TotalLength),=Stdev(E16:E$TotalLength),=PERCENTILE(E16:E$TotalLength,0.03),=PERCENTILE(E16:E$TotalLength,0.97),=AVERAGE(D2:E2),=AVERAGEIF(E16:E$TotalLength,\">\"&F2),=AVERAGEIF(E16:E$TotalLength,\"<\"&F2)" >> $raw_csv_file

    echo "">> $raw_csv_file
    echo $trackOptions >> $raw_csv_file
    echo "">> $raw_csv_file
    #echo "ScalingFactor,Clients,Threads,Time,Tps,Latency,StdLatency"  >> $raw_csv_file
    echo "ScalingFactor,Clients,Threads,Test Time,Tps,Latency,stddev" >> $raw_csv_file

    trackOptions=`grep "track_" $log_file_name| sed "s/| Collects.*//"| sed "s/|/-/"| sed "s/ //g"| sed ':a;N;$!ba;s/\n/,/g'| sed 's/-/,/g'`
    i=0
    count=0
    while [ "x${Time[$count]}" != "x" ]
    do
        if  (( ${Time[$count]} % 10 == 0 ))
        then
            echo "${res_ScalingFactor[$i]},${res_Clients[$i]},${res_Threads[$i]},${Time[$count]},${Tps[$count]},${Latency[$count]},${StdLatency[$count]}"  >> $raw_csv_file
        fi
        
        if [ ${Time[$count+1]} -lt ${Time[$count]} ]
        then
             echo "increasing i: "${Time[$count]}
            ((i++))
        fi
        ((count++))
    done
    #cat $raw_csv_file
    echo "Raw logs FileName: $raw_csv_file"
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
    Environment=`grep "Environment" $log_file_name| awk '{print $2}'`
    Region=`grep "Region" $log_file_name| awk '{print $2}'`

    res_OsMemoryStats=(`grep "^Memory stats OS" $log_file_name | sed "s/^.*:  //"`)
    res_OsCpuUsage=(`grep "^CPU usage (OS)" $log_file_name | sed "s/^.*:  //"`)
    res_PgBenchClientConnections=(`grep "^Connections" $log_file_name | sed "s/^.*:  //"`)
    res_PgBenchCpuMemUtilization=(`grep "^CPU,MEM usage (pgbench)" $log_file_name | sed "s/^.*:  //"`)

    res_PgBenchTestStartTime=(`grep "Starting the test iteration" $log_file_name | sed "s/^.*- //"`)
    res_PgBenchTestEndTime=(`grep "End of the test iteration" $log_file_name | sed "s/^.*- //"`)

    PgBenchTestStartTime=`grep "Test Started at:" $log_file_name | awk '{print $5,$6}'`
    PgBenchTestEndTime=`grep "Test Finished at:" $log_file_name | awk '{print $5,$6}'`

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

        echo "Iteration,TestStartTime,TestEndTime,PgServer,Client,Environment,Region,ScalingFactor,Clients,Threads,TotalTransaction,AvgLatency,StdDevLatency,TPSIncConnEstablishing,TPSExcludingConnEstablishing,TransactionType,QueryMode,Duration,ClientOsMemoryStatsTotal,ClientOsMemoryStatsUsed,ClientOsMemoryStatsFree,ClientOsCpuUsage,PgBenchClientConnections,PgBenchCpuUsage,PgBenchMemUsage,PgServer,Network_rx_ServerAvg,Network_tx_ServerAvg,PgConnections_ServerAvg,OsCpuUsage_Server,OsMemoryStats_Server-Total,Used,Free,sdcIOPSAvg,sdcMbpsReadAvg,sdcMbpsWriteAvg,sdcIOPSMin,sdcIOPSMax,sdcReadMBpsMin,sdcReadMBpsMax,sdcWriteMBpsMin,sdcWriteMBpsMax,sddIOPSAvg,sddMbpsReadAvg,sddMbpsWriteAvg,sddIOPSMin,sddIOPSMax,sddReadMBpsMin,sddReadMBpsMax,sddWriteMBpsMin,sddWriteMBpsMax"  > $csv_file
    else
        echo "Iteration,TestStartTime,TestEndTime,PgServer,Client,Environment,Region,ScalingFactor,Clients,Threads,TotalTransaction,AvgLatency,StdDevLatency,TPSIncConnEstablishing,TPSExcludingConnEstablishing,TransactionType,QueryMode,Duration,ClientOsMemoryStatsTotal,ClientOsMemoryStatsUsed,ClientOsMemoryStatsFree,ClientOsCpuUsage,PgBenchClientConnections,PgBenchCpuUsage,PgBenchMemUsage,"  > $csv_file
    fi
    trackOptions=`grep "track_" $log_file_name| sed "s/| Collects.*//"| sed "s/|/-/"| sed "s/ //g"| sed ':a;N;$!ba;s/\n/,/g'| sed 's/-/,/g'`
    Client=`hostname`
    count=0
    while [ "x${res_Iteration[$count]}" != "x" ]
    do
        if [ $COLLECT_SERVER_STATS == 1 ]
        then
            echo "${res_Iteration[$count]},${PgBenchTestStartTime},${PgBenchTestEndTime},${Environment},${Region},${res_PgServer[$count]},${Client},${res_ScalingFactor[count]},${res_Clients[count]},${res_Threads[count]},${res_TotalTransaction[$count]},${res_AvgLatency[$count]},${res_StdDevLatency[$count]},${res_TPSIncConnEstablishing[$count]},${res_TPSExcludingConnEstablishing[$count]},${res_TransactionType[$count]},${res_QueryMode[$count]},${res_Duration[$count]},${res_OsMemoryStats[$count]},${res_OsCpuUsage[$count]},${res_PgBenchClientConnections[$count]},${res_PgBenchCpuMemUtilization[$count]},${res_Network_rx_Server[$count]},${res_Network_tx_Server[$count]},${res_PgConnections_Server[$count]},${res_OsCpuUsage_Server[$count]},${res_OsMemoryStats_Server[$count]},${res_ServerDiskAverage_sdc_Server[$count]},${res_ServerDiskMinMaxIOPS_sdc_Server[$count]},${res_ServerDiskMinMaxReadMBps_sdc_Server[$count]},${res_ServerDiskMinMaxWriteMBps_sdc_Server[$count]},${res_ServerDiskAverage_sdd_Server[$count]},${res_ServerDiskMinMaxIOPS_sdd_Server[$count]},${res_ServerDiskMinMaxReadMBps_sdd_Server[$count]},${res_ServerDiskMinMaxWriteMBps_sdd_Server[$count]},$trackOptions"  >> $csv_file
        else
            echo "${res_Iteration[$count]},${PgBenchTestStartTime},${PgBenchTestEndTime},${Environment},${Region},${res_PgServer[$count]},${Client},${res_ScalingFactor[count]},${res_Clients[count]},${res_Threads[count]},${res_TotalTransaction[$count]},${res_AvgLatency[$count]},${res_StdDevLatency[$count]},${res_TPSIncConnEstablishing[$count]},${res_TPSExcludingConnEstablishing[$count]},${res_TransactionType[$count]},${res_QueryMode[$count]},${res_Duration[$count]},${res_OsMemoryStats[$count]},${res_OsCpuUsage[$count]},${res_PgBenchClientConnections[$count]},${res_PgBenchCpuMemUtilization[$count]}"  >> $csv_file

            echo "${res_Iteration[$count]},${PgBenchTestStartTime},${PgBenchTestEndTime},${Environment},${Region},${res_PgServer[$count]},${Client},${res_ScalingFactor[count]},${res_Clients[count]},${res_Threads[count]},${res_TotalTransaction[$count]},${res_AvgLatency[$count]},${res_StdDevLatency[$count]},${res_TPSIncConnEstablishing[$count]},${res_TPSExcludingConnEstablishing[$count]},${res_TransactionType[$count]},${res_QueryMode[$count]},${res_Duration[$count]},${res_OsMemoryStats[$count]},${res_OsCpuUsage[$count]},${res_PgBenchClientConnections[$count]},${res_PgBenchCpuMemUtilization[$count]},${res_PgServer[$count]},$trackOptions"  >> Tracking.csv
        fi
        ((count++))
    done
    get_raw_logs_report $log_file_name
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
###############################################################################


if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path to pgbench logs>" >&2
    exit 1
fi

log_folder=$1
list=(`ls $log_folder/LogFile*.log | grep -v dmesg`)
count=0
while [ "x${list[$count]}" != "x" ]
do
    echo "Parsing ${list[$count]}.."
    CsvFile=`Parse ${list[$count]}`
    ((count++))
done

[ ! -d $log_folder/CSVs  ] && mkdir -p $log_folder/CSVs
[ ! -d $log_folder/raw-CSVs  ] && mkdir -p $log_folder/raw-CSVs

mv $log_folder/*-raw.csv $log_folder/raw-CSVs
mv $log_folder/*.csv $log_folder/CSVs
