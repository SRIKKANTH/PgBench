#!/bin/bash
#
# Executes pgbench against given pg server, parse logs, push results to 
#   reports db, send updates over e-mail 
#
# Author: Srikanth Myakam
#
########################################################################

set +H

. CommonRoutines.sh

# Set defaults if you cannot get the config from logs db server
if [ -z "$Duration" ]
then
    export Duration=7200
    echo "Setting Duration to default: '$Duration'" 
else
    echo "Starting test with Duration: '$Duration'" 
fi

if [ ${#ConnectionsList[@]} == 0 ]
then
    export ConnectionsList=(1 2 4 8 16 32 48 100 200)
    echo "Setting ConnectionsList to default: '${ConnectionsList[@]}'" 
else
    echo "Starting test with ConnectionsList: '${ConnectionsList[@]}'" 
fi

if [ -z "$ScaleFactor" ]
then
    export ScaleFactor=2000
    echo "Setting ScaleFactor to default: '$ScaleFactor'" 
else
    echo "Starting test with ScaleFactor: '$ScaleFactor'" 
fi

if [ -z "$TestDatabase" ]
then
    export TestDatabase='postgres'
    echo "Setting TestDatabase to default: '$TestDatabase'" 
else
    echo "Starting test with TestDatabase: '$TestDatabase'" 
fi

#
export COLLECT_SERVER_STATS=0
export CollectViews=0
export views_capture_duration=1
export COLLECT_query_store_stats=0
export Test_Iterations=1
export ParseLogsAfterTest=1
###

export DropDBonEachRun=0
export pgbench_progress_interval=60
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

get_views()
{
    view_list_1=( 'pg_stat_activity'
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
    viewName=$1
    Server=$2
    PassWord=$3
    UserName=$4

    local LogFolder="Logs/ViewCSVs/"
    #sleep 10
    LogFile=$LogFolder/$viewName.csv

    echo "" > $LogFile

    for i in $(seq 1 $capture_duration)
    do
        echo  "["`date`"] $viewName Iteration: $i" >> $TCS_RunLog
        PGPASSWORD=$PassWord psql -h $Server -U $UserName -d $TestDatabase -c "select CURRENT_TIMESTAMP, *  $viewName" >> $LogFile
        sleep $views_capture_duration
    done
}

run_cmd()
{
    local cmd=$@
    local output_file=/tmp/cmd_output.log
    echo "Executing: $cmd"
    #$cmd > $output_file 2>&1
    $cmd  | tee $output_file 2>&1
    if [ $? != 0 ]
    then
        exit_script "Failed to execute '$cmd'" $output_file
    fi
    #cat $output_file
}

run_psql_cmd()
{
    local sql_cmd=$@
    local sql_output_file=/tmp/cmd_output.log
    
    echo "Executing: psql command: $sql_cmd"
    
    PGPASSWORD=$PassWord psql -h $Server -U $UserName -d $TestDatabase -c "$sql_cmd" > $sql_output_file 2>&1
    if [ $? != 0 ]
    then
        exit_script "Failed to execute '$sql_cmd'" $sql_output_file
    fi
    cat $sql_output_file
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
    echo "-------- Server Details -------- `date`"
    echo ""
    echo "Environment: "$Environment
    echo "Region: "$Region
    echo "TestDatabase: "$TestDatabase
    echo "TestType: "$TestType
    echo ""
    echo "ServerConfigTrackingParameters:"
    run_psql_cmd "SHOW ALL;" | grep "pg_qs.query_capture_mode\|track_activities\|track_counts\|track_functions\|track_io_timing"
    echo ""

    if [ DropDBonEachRun == 1 ]
    then
        echo "-------- Dropping test db ... -------- `date`"
        #run_psql_cmd "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = $TestDatabase AND pid <> pg_backend_pid();"
        run_psql_cmd "DROP DATABASE IF EXISTS $TestDatabase;"
        echo ""
        echo "-------- Creating test db ... -------- `date`"
        run_psql_cmd "CREATE DATABASE $TestDatabase;"
    fi

    echo ""
    echo "-------- Initializing db... -------- `date`"
    
    echo "PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/$TestDatabase"
    startTime=`date +%s`
    PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/$TestDatabase 2>&1
    endTime=`date +%s`

    echo ""
    echo "-------- Initializing db... Done in $((endTime-startTime)) seconds -------- "

    #for Connections in $ConnectionsList
    for Connections in ${ConnectionsList[@]}
    do
        Threads=$Connections
        if [ $Threads -gt `nproc` ]
        then
            Threads=`nproc`
        fi

        echo "Starting the test.."
        while sleep  1
        do
            echo "-------- Starting the test iteration: $Iteration -------- `date '+%Y-%m-%d %H:%M:%S'`"
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
             
            echo "Executing: PGPASSWORD=$PassWord pgbench -S -P $pgbench_progress_interval -c $Connections -j $Threads -T $Duration -U $UserName postgres://$Server:5432/$TestDatabase"
            
            PGPASSWORD=$PassWord pgbench $extra_options -P $pgbench_progress_interval -c $Connections -j $Threads -T $Duration -U $UserName postgres://$Server:5432/$TestDatabase 2>&1
            
            echo "Waiting for all procs to exit"
            for pid in ${pids[*]}
            do
                kill -9 $pid 2>/dev/null 
            done

            if [ $COLLECT_SERVER_STATS == 1 ]
            then
                mkdir -p Logs/$Connections/$Iteration
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

            echo "-------- End of the test iteration: $Iteration -------- `date '+%Y-%m-%d %H:%M:%S'`"

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

function UploadStatsToLogsDB ()
{
    local ToLogsDbFileCsv=$1
    if [ -f $ToLogsDbFileCsv ]
    then 
        echo "Pushing stats ($ToLogsDbFileCsv) to LogsDB '$LogsDbServer' into table '$LogsTableName'"
        PGPASSWORD=$LogsDbServerPassword psql -h $LogsDbServer -U $LogsDbServerUsername -d $LogsDataBase -c "\copy $LogsTableName(Test_Start_Time,Test_End_Time,Environment,Region,Test_Server_Edition,Test_Server_CPU_Cores,Test_Server_Storage_In_MB,Client_VM_SKU,Pg_Server,Client_Hostname,Test_Connections,Os_pg_Connections,TPS_Including_Connection_Establishing,Average_Latency,StdDev_Latency,Scaling_Factor,Test_Duration,Cpu_Threads_Used,Total_Transactions,Transaction_Type,Query_Mode,TPS_Excluding_Connection_Establishing,Client_Os_Memory_Stats_Total,Client_Os_Memory_Stats_Used,Client_Os_Memory_Stats_Free,Client_Os_Cpu_Usage,PgBench_Cpu_Usage,PgBench_Mem_Usage,Test_type,Test_database_name) FROM '$ToLogsDbFileCsv' DELIMITER ',' CSV HEADER;" 2>&1
    else
        echo "Cannot upload test results to db as file:'$ToLogsDbFileCsv' cannot exist"
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
        track_config=`PGPASSWORD=$PassWord psql -h $Server -U $UserName -d $TestDatabase -c "SHOW ALL;" | grep $track_option | sed "s/| Collects.*//"| sed "s/|/-/"| sed "s/ //g"`_$track_config 
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

Current_Test_Iteration=0

while [ $Test_Iterations -gt $Current_Test_Iteration ]
do
    echo "------------------------------Executing Test Iteration: $Current_Test_Iteration at "`date`"------------------------------"
    ReportEmail=$(grep -i "ReportEmail," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

    if [ -d Logs ]; then
        folder=OldLogs/`date|sed "s/ /_/g"| sed "s/:/_/g"`
        mkdir -p $folder
        mv Logs/* $folder/
    fi
    CurrentTime=`date +%m-%d-%T| sed 's/:/-/g'`
    filetag=LogFile_`hostname`_`GetLogFileNameTag`_$CurrentTime
    LogFile=Logs/$filetag.log

    [ ! -d Logs  ] && mkdir Logs
    echo "------------------------------ Test Started at: " `GetCurrentDateTimeInSQLFormat` > $LogFile 

    pgBenchTest >> $LogFile 2>&1
    
    echo "------------------------------ Test Finished at: " `GetCurrentDateTimeInSQLFormat` >> $LogFile 

    bash pgBenchParser.sh Logs/
    CsvFile=Logs/CSVs/$filetag.csv
    DbUploadFile=Logs/CSVs/$filetag.db
    cat $CsvFile | grep -v ^Iteration > $DbUploadFile
    sed -i "s/ms//g" $DbUploadFile
    UploadStatsToLogsDB $DbUploadFile

    if [ -e $CsvFile ]
    then   
        SendMail $CsvFile "pgbench Test Completed" /etc/hostname
    else
        SendMail $LogFile "pgbench Test Completed" /etc/hostname
    fi

    echo "------------------------------End of Test Iteration: $Current_Test_Iteration at "`date`"------------------------------"
    ((Current_Test_Iteration++))
done
