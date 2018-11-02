#!/bin/bash
set +H
Duration=60
TestDataFile='ConnectionProperties.csv'

capture_duration=$((Duration -30))
filetag=Logs/LogFile_`hostname`

capture_cpu_SystemFile=/tmp/capture_cpu_System_Top.log
capture_cpu_PgBenchFile=/tmp/capture_cpu_PgBench_Top.log
capture_connectionsFile=/tmp/capture_connections.log
capture_memory_usageFile=/tmp/capture_memory_usage.log
capture_netusageFile=/tmp/capture_netusage_sar.log

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

get_Avg()
{
    inputArray=("$@")
    count=${#inputArray[@]}
    sum=$( IFS="+"; bc <<< "${inputArray[*]}" )
    unset IFS
    average=`echo $sum/$count|bc -l`
    printf "%.1f\n" $average
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

pgBenchTest ()
{
    ulimit -u unlimited

    TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))

    Server=${TestData[1]}
    ScaleFactor=${TestData[2]}
    Connections=${TestData[3]}
    Threads=${TestData[4]}

    UserName=$(grep -i "DbUserName," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
    PassWord=$(grep -i "DbPassWord," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

    echo "-------- Initializing db... -------- `date`"
        
    echo "PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/postgres"
    startTime=`date +%s`
    PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/postgres
    endTime=`date +%s`

    echo ""
    echo "-------- Initializing db... Done in $((endTime-startTime)) seconds -------- "
        
    echo "Starting the test.."
    Iteration=1
    while sleep  1
    do
        echo "-------- Starting the test iteration: $Iteration -------- `date`"
        echo "Sleeping for 15 secs.."
        sleep 15
        echo "Sleeping for 15 secs..Done!"

        echo > $capture_cpu_SystemFile
        echo > $capture_cpu_PgBenchFile
        echo > $capture_connectionsFile
        echo > $capture_memory_usageFile
        echo > $capture_netusageFile

        procs=( "capture_netusage" "capture_memory_usage" "capture_cpu" "capture_connections" )

        # run processes and store pids in array
        i=0
        for cmd in ${procs[*]}
        do
            #$cmd $Iteration &
            $cmd &
            pids[${i}]=$!
            ((i++))
        done

        echo "Executing: PGPASSWORD=$PassWord pgbench -P 30 -c $Connections -j $Threads -T $Duration -U pgadmin postgres://$Server:5432/postgres"
        
        PGPASSWORD=$PassWord pgbench -P 60 -c $Connections -j $Threads -T $Duration -U pgadmin postgres://$Server:5432/postgres
        
        echo "Waiting for all procs to exit"
        for pid in ${pids[*]}
        do
            wait $pid
        done

        echo "VM stats (Average) during test:--"
        echo "Network "`cat $capture_netusageFile| grep Average| head -1|awk '{print $5}'` ":" `cat $capture_netusageFile| grep Average|grep eth0| awk '{print $5}'`
        echo "Network "`cat $capture_netusageFile| grep Average| head -1|awk '{print $6}'` ":" `cat $capture_netusageFile| grep Average|grep eth0| awk '{print $6}'`
        echo "Memory stats OS (total,used,free): " `get_Column_Avg $capture_memory_usageFile`
        echo "Connections : " `get_Column_Avg $capture_connectionsFile`
        echo "CPU usage (OS): " `get_Column_Avg $capture_cpu_SystemFile`
        echo "CPU,MEM usage (pgbench): " `get_Column_Avg $capture_cpu_PgBenchFile`

        dmesg > $filetag-dmesg.log 
        
        echo "-------- End of the test iteration: $Iteration -------- "

        Iteration=$((Iteration + 1))
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

###############################################################
##
##              Script Execution Starts from here
###############################################################

CheckDependencies

pkill pgbench

if [ -d Logs ]; then
    folder=OldLogs/`date|sed "s/ /_/g"| sed "s/:/_/g"`
    mkdir -p $folder
    mv Logs/* $folder/
fi

LogFile=$filetag.log

[ ! -d Logs  ] && mkdir Logs

pgBenchTest > $LogFile 2>&1
