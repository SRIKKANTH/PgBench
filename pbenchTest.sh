#!/bin/bash
set +H
# Settings file in csv file.
export TestDataFile='ConnectionProperties.csv'

# If you dont know how to configure above file set below creds with your server details.
export TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))
export Server=${TestData[1]}
export UserName=$(grep -i "DbUserName," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
export PassWord=$(grep -i "DbPassWord," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
export UserName=postgres@$(echo $Server | sed s/\\..*//)

# How many iterations do you want to run?
export Test_Iterations=1

#These conections are tested against given Server. This list is repeated $Test_Iterations times.
export ConnectionsList="
    1
    2
    4
    8
    16
    32
    64
    100
    200
    "
# How long do you want to run each of above conections? (in seconds)
export Duration=7200

# Set DropDBonEachRun=1 if you want to drop and create test db on each iteration.
export DropDBonEachRun=0

# Which db to be used for testing? Note: If DropDBonEachRun=1 then it will be dropped and re-created on each iteration
export pgbenchTestDatabase="postgres"

# How often do you want pgbench to print progress (in seconds) 
export pgbench_progress_interval=10

#############################################
# Advanced settings:
#####################
# Settings COLLECT_SERVER_STATS=1 will collect server VM stats if its a Linux VM installed with PG 
export COLLECT_SERVER_STATS=0

# CollectViews=1 will collect views on db check get_views routine for details
export CollectViews=0
# How often do you want to collect views? (in seconds)
export views_capture_duration=0
# COLLECT_query_store_stats=1 will collect PG query store stats if available 
export COLLECT_query_store_stats=0

###


##################################################################################

capture_duration=$((Duration -30))

capture_cpu_SystemFile=/tmp/capture_cpu_System_Top.log
capture_cpu_PgBenchFile=/tmp/capture_cpu_PgBench_Top.log
capture_connectionsFile=/tmp/capture_connections.log
capture_memory_usageFile=/tmp/capture_memory_usage.log
capture_netusageFile=/tmp/capture_netusage_sar.log

capture_server_connectionsFile=/tmp/capture_server_connections.log
capture_server_netusageFile=/tmp/capture_server_netusage_sar.log
capture_server_diskusageFile=/tmp/capture_server_diskusage.log
capture_server_cpu_SystemFile=/tmp/capture_server_cpu_System_Top.log
capture_server_memory_usageFile=/tmp/capture_server_memory_usage.log

##############
capture_cpu(){
    sleep 10
    for i in $(seq 1 $capture_duration)
    do
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' >> $capture_cpu_SystemFile
        top -bn1 | grep pgbench | awk '{print $9,$10}' >> $capture_cpu_PgBenchFile
        sleep 1
    done
}

capture_connections(){
    sleep 10
	for i in $(seq 1 $capture_duration)
	do
		#netstat -natp | grep pgbench | grep ESTA | wc -l >> $filetag-connections_$Iteration.csv
		netstat -taepn 2>/dev/null | grep pgbench | grep ESTA | wc -l >> $capture_connectionsFile
		sleep 1
	done
}

capture_memory_usage(){
    sleep 10
    #$ free -m
    #              total        used        free      shared  buff/cache   available
    #Mem:          28136        1191       25672          68        1272       26332
    #Swap:             0           0           0
	for i in $(seq 1 $capture_duration)
	do
        free -m| grep Mem |awk '{print $2, $3, $4}' >> $capture_memory_usageFile
		sleep 1
	done
    #vmstat 1 $capture_duration >> $filetag-vmstat_$Iteration.csv
}

capture_netusage(){
    sleep 10
    sar -n DEV 1 $capture_duration 2>&1 >> $capture_netusageFile
}

get_captured_server_usages(){
    echo "Server VM stats (Average) during test :-------------------------"
    if [ -f $capture_server_netusageFile ]
    then
        echo "ServerNetwork "`cat $capture_server_netusageFile| grep Average| head -1|awk '{print $5}'` ":" `cat $capture_server_netusageFile| grep Average|grep eth0| awk '{print $5}'`
        echo "ServerNetwork "`cat $capture_server_netusageFile| grep Average| head -1|awk '{print $6}'` ":" `cat $capture_server_netusageFile| grep Average|grep eth0| awk '{print $6}'`
    fi
    echo "ServerConnections : " `get_Column_Avg $capture_server_connectionsFile`
    echo "ServerCPU usage (OS): " `get_Column_Avg $capture_server_cpu_SystemFile`
    echo "ServerMemory stats OS (total,used,free): " `get_Column_Avg $capture_server_memory_usageFile`

    echo "ServerDiskUsage: IOPS,MbpsRead,MbpsWrite :-----" 
    disk_list=(`cat $capture_server_diskusageFile | grep ^sd| awk '{print $1}' |sort |uniq`)

    count=0
    while [ "x${disk_list[$count]}" != "x" ]
    do
        disk=${disk_list[$count]}
        
        cat $capture_server_diskusageFile | grep ^$disk| awk '{print $2"\t"$3"\t"$4}' > $capture_server_diskusageFile.tmp
        echo "ServerDisk "$disk ": "`get_Column_Avg $capture_server_diskusageFile.tmp`
        ((count++))
    done   

    echo "ServerDiskUsageIOPS: Min,Max :-----" 

    count=0
    while [ "x${disk_list[$count]}" != "x" ]
    do
        disk=${disk_list[$count]}
        
        IOPS_Array=(`cat $capture_server_diskusageFile | grep ^$disk| awk '{print $2}'`)
        echo "ServerDiskIOPSMinMax "$disk ": "`get_MinMax ${IOPS_Array[@]}`
        ((count++))
    done   

    echo "ServerDiskUsage Read MBps: Min,Max :-----" 

    count=0
    while [ "x${disk_list[$count]}" != "x" ]
    do
        disk=${disk_list[$count]}
        
        IOPS_Array=(`cat $capture_server_diskusageFile | grep ^$disk| awk '{print $3}'`)
        echo "ServerDiskReadMBpsMinMax "$disk ": "`get_MinMax ${IOPS_Array[@]}`
        ((count++))
    done   

    echo "ServerDiskUsage Write MBps: Min,Max :-----" 

    count=0
    while [ "x${disk_list[$count]}" != "x" ]
    do
        disk=${disk_list[$count]}
        
        IOPS_Array=(`cat $capture_server_diskusageFile | grep ^$disk| awk '{print $4}'`)
        echo "ServerDiskWriteMBpsMinMax "$disk ": "`get_MinMax ${IOPS_Array[@]}`
        ((count++))
    done   
}

get_MinMax()
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

get_Avg()
{
    inputArray=("$@")
    count=${#inputArray[@]}
    sum=$( IFS="+"; bc <<< "${inputArray[*]}" )
    unset IFS
    average=`echo $sum/$count|bc -l`
    printf "%.3f\n" $average
}

get_Column_Avg()
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

get_views()
{
    view_list_1=( 'pg_stat_activity' 
    'pg_stat_wal_receiver1'
    'pg_stat_replication'
    'pg_stat_wal_receiver'
    'pg_stat_ssl'
    'pg_stat_progress_vacuum'
    'pg_stat_archiver'
    'pg_stat_bgwriter'
    'pg_stat_database'
    'pg_stat_database_conflicts'
    'pg_stat_all_tables'
    'pg_stat_sys_tables'
    'pg_stat_user_tables'
    'pg_stat_xact_all_tables'
    'pg_stat_xact_sys_tables'
    'pg_stat_xact_user_tables'
    'pg_stat_all_indexes'
    'pg_stat_sys_indexes'
    'pg_stat_user_indexes'
    'pg_statio_all_tables'
    'pg_statio_sys_tables'
    'pg_statio_user_tables'
    'pg_statio_all_indexes'
    'pg_statio_sys_indexes'
    'pg_statio_user_indexes'
    'pg_statio_all_sequences'
    'pg_statio_sys_sequences'
    'pg_statio_user_sequences'
    'pg_stat_user_functions'
    'pg_stat_xact_user_functions' )

    view_list_2=( 
    'pg_stat_database'
    'pg_stat_activity'
    'pg_stat_user_tables'
    'pg_statio_user_tables'
    'pg_stat_user_indexes'
    'pg_statio_user_tables' )

    view_list=( 
    'pg_stat_activity'
    'pg_stat_wal_receiver'
    'pg_stat_ssl'
    'pg_stat_progress_vacuum'
    'pg_stat_archiver'
    'pg_stat_bgwriter'
    'pg_stat_database'
    'pg_stat_database_conflicts'
    'pg_stat_all_tables'
    'pg_stat_xact_all_tables'
    'pg_stat_all_indexes'
    'pg_statio_all_tables'
    'pg_statio_all_indexes'
    'pg_statio_all_sequences'
    'pg_stat_user_functions'
    'pg_stat_xact_user_functions')

    LogFolder="Logs/ViewCSVs/"
    TCS_RunLog=TCS_RunLog.log
    echo "" > $TCS_RunLog

    [ ! -d $LogFolder  ] && mkdir -p $LogFolder

    local i=0
    for view in ${view_list[*]}
    do
        local cmd="get_viewstats $view $Server $PassWord $UserName"
        echo "Executing $cmd"  >> $TCS_RunLog
        $cmd &
        pids[${i}]=$!
        ((i++))
    done
    echo "Waiting for $capture_duration seconds to all procs to exit"  >> $TCS_RunLog

    sleep $capture_duration

    for pid in ${pids[*]}
    do
        kill -9 $pid 2>/dev/null 
    done
    echo "End of get_views"  >> $TCS_RunLog
}

get_viewstats()
{

    viewN
    ame=$1# 
    PassWord=$1 will PG collect query stats if available store  Server=$2
    PassWord=$3
    UserName=$4

    local LogFolder="Logs/ViewCSVs/"
    #sleep 10
    LogFile=$LogFolder/$viewName.log

    echo "" > $LogFile

    for i in $(seq 1 $capture_duration)
    do
        echo  "["`date`"] $viewName Iteration: $i" >> $TCS_RunLog
        PGPASSWORD=$PassWord psql -h $Server -U $UserName -d postgres -c "select CURRENT_TIMESTAMP, *  $viewName" >> $LogFile
        sleep $views_capture_duration
    done
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

exit_script()
{
    echo $1
    SendMail $LogFile "$1" $2
    exit 
}

run_cmd()
{
    local cmd=$@
    local output_file=/tmp/cmd_output_`cat /proc/sys/kernel/random/uuid`.log
    echo "Executing: $cmd"
    #$cmd > $output_file 2>&1
    $cmd  | tee $output_file 2>&1
    if [ $? != 0 ]
    then
        exit_script "Failed to execute '$cmd'" $output_file
    fi
    rm -rf $output_file
}

run_psql_cmd()
{
    local sql_cmd=$@
    local sql_output_file=/tmp/cmd_output_`cat /proc/sys/kernel/random/uuid`.log
    
    echo "Executing: psql command: $sql_cmd"
    
    PGPASSWORD=$PassWord psql -h $Server -U $UserName -d postgres -c "$sql_cmd" > $sql_output_file 2>&1
    if [ $? != 0 ]
    then
        exit_script "Failed to execute '$sql_cmd'" $sql_output_file
    fi
    cat $sql_output_file
    rm -rf $sql_output_file
}

pgBenchTest ()
{
    TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))

    PerformanceTestMode="Performance"
    LongHaulTestMode="LongHaul"
    
    TestMode=$PerformanceTestMode
    
    [[ $(grep `hostname` $TestDataFile) =~ $LongHaulTestMode ]] && TestMode=$LongHaulTestMode
    [[ $(grep `hostname` $TestDataFile) =~ $PerformanceTestMode ]] && TestMode=$PerformanceTestMode

    TestMode=$PerformanceTestMode
    echo "Executing test in $TestMode mode"

    ScaleFactor=${TestData[2]}
    Connections=${TestData[3]}
    Threads=${TestData[4]}
    
    if [ "x$Server" == "x"  ]
    then
        echo "Exiting the test as no config found for this server!"
        exit 1
    else
        echo "TestMode: $TestMode"
    fi

    run_psql_cmd "select 1;"
    
    Iteration=1

    echo "-------- Client Machine Details -------- `date`"
    echo "VMcores: "`nproc`
    echo "TotalMemory: "`free -h|grep Mem|awk '{print $2}'`
    echo "KernelVersion: "`uname -r`
    echo "OSVersion: "`lsb_release -a 2>/dev/null |grep Description| sed 's/Description://'|sed 's/\s//'|sed 's/\s/_/g'`
    echo "HostVersion: "`dmesg | grep "Host Build" | sed "s/.*Host Build://"| awk '{print  $1}'| sed "s/;//"`
    echo ""
    echo "ServerConfigTrackingParameters:"

    run_psql_cmd "SHOW ALL;" | grep "pg_qs.query_capture_mode\|track_activities\|track_counts\|track_functions\|track_io_timing"
    echo ""

    if [ DropDBonEachRun == 1 ]
    then
        echo "-------- Dropping test db ... -------- `date`"
        #run_psql_cmd "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = $pgbenchTestDatabase AND pid <> pg_backend_pid();"
        run_psql_cmd "DROP DATABASE IF EXISTS $pgbenchTestDatabase;"
        echo ""
        echo "-------- Creating test db ... -------- `date`"
        run_psql_cmd "CREATE DATABASE $pgbenchTestDatabase;"
    fi

    echo ""
    echo "-------- Initializing db... -------- `date`"
    echo "-------- Test parameters -------- `date`"
    echo "Server: "$Server
    echo "ScaleFactor: "$ScaleFactor
    echo "Clients: "$Connections
    echo "Threads: "$Threads
    
    echo "PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/$pgbenchTestDatabase"
    startTime=`date +%s`
    PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/$pgbenchTestDatabase 2>&1
    endTime=`date +%s`

    echo ""
    echo "-------- Initializing db... Done in $((endTime-startTime)) seconds -------- "

    for Connections in $ConnectionsList
    do
        Threads=$Connections
        if [ $Threads -gt `nproc` ]
        then
            Threads=`nproc`
        fi

        echo "Starting the test.."
        while sleep  1
        do
            echo "-------- Starting the test iteration: $Iteration -------- `date`"
            echo "-------- Test parameters -------- `date`"
            echo "Server: "$Server
            echo "ScaleFactor: "$ScaleFactor
            echo "Clients: "$Connections
            echo "Threads: "$Threads

            echo "Sleeping for 15 secs.."
            sleep 15
            echo "Sleeping for 15 secs..Done!"

            echo > $capture_cpu_SystemFile
            echo > $capture_cpu_PgBenchFile
            echo > $capture_connectionsFile
            echo > $capture_memory_usageFile
            echo > $capture_netusageFile

            procs=( "capture_netusage" "capture_memory_usage" "capture_cpu" "capture_connections" )

            if [ $CollectViews == 1 ]
            then
                procs+=( "get_views" )
            fi
            # Start processes and store pids in array
            i=0
            for cmd in ${procs[*]}
            do
                echo "Executing $cmd"
                $cmd &
                pids[${i}]=$!
                ((i++))
            done
            
            if [ $COLLECT_SERVER_STATS == 1 ]
            then
                echo "Starting stat collection on server"
                ssh $Server "bash ~/W/RunCollectServerStats.sh"
            fi

            if [ $COLLECT_query_store_stats == 1 ]
            then
                echo "'query_store' before test:---------------------------"
                PGPASSWORD=$PassWord psql -h $Server -U $UserName -d azure_sys -c  "select * from query_store.qs_view where query_sql_text like '%pgbench%' order by  query_sql_text asc, start_time asc"
                echo "-----------------------------------------------------"
            fi
             
            echo "Executing: PGPASSWORD=$PassWord pgbench -S -P $pgbench_progress_interval -c $Connections -j $Threads -T $Duration -U $UserName postgres://$Server:5432/$pgbenchTestDatabase"
            
            PGPASSWORD=$PassWord pgbench $extra_options -P $pgbench_progress_interval -c $Connections -j $Threads -T $Duration -U $UserName postgres://$Server:5432/$pgbenchTestDatabase 2>&1
            
            echo "Waiting for all procs to exit"
            for pid in ${pids[*]}
            do
                kill -9 $pid 2>/dev/null 
            done

            mkdir -p Logs/$Connections/$Iteration 

            if [ $COLLECT_SERVER_STATS == 1 ]
            then
                scp $Server:/tmp/capture_server* /tmp/
                scp $Server:/tmp/capture_server* Logs/$Connections/$Iteration/
            fi

            echo "Client VM stats (Average) during test:--------------------"
            echo "Network "`cat $capture_netusageFile| grep Average| head -1|awk '{print $5}'` ":" `cat $capture_netusageFile| grep Average|grep eth0| awk '{print $5}'`
            echo "Network "`cat $capture_netusageFile| grep Average| head -1|awk '{print $6}'` ":" `cat $capture_netusageFile| grep Average|grep eth0| awk '{print $6}'`
            echo "Memory stats OS (total,used,free): " `get_Column_Avg $capture_memory_usageFile`
            echo "Connections : " `get_Column_Avg $capture_connectionsFile`
            echo "CPU usage (OS): " `get_Column_Avg $capture_cpu_SystemFile`
            echo "CPU,MEM usage (pgbench): " `get_Column_Avg $capture_cpu_PgBenchFile`

            if [ $COLLECT_SERVER_STATS == 1 ]
            then
                get_captured_server_usages
            fi

            if [ $COLLECT_query_store_stats == 1 ]
            then
                echo "'query_store' after test:---------------------------"
                PGPASSWORD=$PassWord psql -h $Server -U $UserName -d azure_sys -c  "select * from query_store.qs_view where query_sql_text like '%pgbench%' order by  query_sql_text asc, start_time asc" 
                echo "-----------------------------------------------------"
            fi

            echo "-------- End of the test iteration: $Iteration -------- "

            if [ $TestMode == $PerformanceTestMode ]; then
            # 1 iteration is enough for PerformanceTest
                break
            fi
        done
        Iteration=$((Iteration + 1))
        sleep 120
        ((j++))
    done
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

function GetLogFileNameTag()
{
    ServerName=$(echo $Server | sed s/\\..*//)
    
    track_option_list="track_io_timing
    track_functions
    track_counts
    track_activities"

    track_config=""
    for track_option in $track_option_list; do
        track_config=`PGPASSWORD=$PassWord psql -h $Server -U $UserName -d $pgbenchTestDatabase -c "SHOW ALL;" | grep $track_option | sed "s/| Collects.*//"| sed "s/|/-/"| sed "s/ //g"`_$track_config 
    done

    track_config=`echo $track_config | sed s/track_activities/T-ACT/g`
    track_config=`echo $track_config | sed s/track_counts/T-COUNT/g`
    track_config=`echo $track_config | sed s/track_functions/T-FUN/g`
    track_config=`echo $track_config | sed s/track_io_timing/T-IOTIME/g`
    #
    track_config=`echo $track_config |sed 's/T-ACT-off_T-COUNT-off_T-FUN-none_T-IOTIME-on/Io_T/'`
    track_config=`echo $track_config |sed 's/T-ACT-off_T-COUNT-off_T-FUN-all_T-IOTIME-off/FUNC/'`
    track_config=`echo $track_config |sed 's/T-ACT-off_T-COUNT-off_T-FUN-none_T-IOTIME-off/NONE/'`
    track_config=`echo $track_config |sed 's/T-ACT-on_T-COUNT-on_T-FUN-all_T-IOTIME-on/ALL/'`
    track_config=`echo $track_config |sed 's/T-ACT-on_T-COUNT-off_T-FUN-none_T-IOTIME-off/ACT/'`
    track_config=`echo $track_config |sed 's/T-ACT-off_T-COUNT-on_T-FUN-none_T-IOTIME-off/COUNTS/'`
    track_config=`echo $track_config |sed 's/T-ACT-on_T-COUNT-on_T-FUN-none_T-IOTIME-on/AzureDefault/'`
    track_config=`echo $track_config |sed 's/:/-/g'`

    echo $track_config$ServerName-$CollectViews-$views_capture_duration
}

###############################################################
##              Script Execution Starts from here
###############################################################

CheckDependencies
Current_Test_Iteration=0
while [ $Test_Iterations -gt $Current_Test_Iteration ]
do
    echo "------------------------------Executing Test Iteration: $Current_Test_Iteration at "`date`"------------------------------"
    pkill pgbench
    ReportEmail=$(grep -i "ReportEmail," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

    if [ -d Logs ]; then
        folder=OldLogs/`date|sed "s/ /_/g"| sed "s/:/_/g"`
        mkdir -p $folder
        mv Logs/* $folder/
    fi
    CurrentTime=`date +%m-%d-%T| sed 's/:/-/g'`
    filetag=Logs/LogFile_`hostname`_`GetLogFileNameTag`_$CurrentTime
    LogFile=$filetag.log

    [ ! -d Logs  ] && mkdir Logs

    pgBenchTest > $LogFile 2>&1

    cp $LogFile /home/vmuser/
    chmod 0777 /home/vmuser/LogFile_*

    SendMail $LogFile "pgbench Test Completed" /etc/hostname
    echo "------------------------------End of Test Iteration: $Current_Test_Iteration at "`date`"------------------------------"
    ((Current_Test_Iteration++))
done