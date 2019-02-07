#!/bin/bash
#set +H
Duration=$1

if [ $# == 0 ]
then
    Duration=1800
fi

capture_duration=$((Duration -60))

capture_cpu_SystemFile=/tmp/capture_server_cpu_System_Top.log
capture_connectionsFile=/tmp/capture_server_connections.log
capture_memory_usageFile=/tmp/capture_server_memory_usage.log
capture_netusageFile=/tmp/capture_server_netusage_sar.log
capture_diskusageFile=/tmp/capture_server_diskusage.log

capture_cpu(){
    sleep 10
    for i in $(seq 1 $capture_duration)
    do
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' >> $capture_cpu_SystemFile
        sleep 1
    done
}

capture_connections(){
    sleep 10
	for i in $(seq 1 $capture_duration)
	do
		#netstat -natp | grep pgbench | grep ESTA | wc -l >> $filetag-connections_$Iteration.csv
		netstat -taepn 2>/dev/null | grep 5432 | grep ESTA | wc -l >> $capture_connectionsFile
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

capture_diskusage(){
    sleep 10
    iostat -m 1 $capture_duration 2>&1 > $capture_diskusageFile
}

capture_diskusage_2(){
    sleep 10

	for i in $(seq 1 $capture_duration)
	do
        iostat -m 2>&1 >> $capture_diskusageFile
		sleep 1
	done
}

#########################################################################################

#procs=( "capture_netusage" "capture_memory_usage" "capture_cpu" "capture_connections" "capture_diskusage" )
procs=( "capture_netusage" "capture_connections" "capture_diskusage" "capture_cpu" "capture_memory_usage" )

i=0
for cmd in ${procs[*]}
do
    pkill $cmd
    ((i++))
done

pkill sleep
pkill sar

echo > $capture_cpu_SystemFile
echo > $capture_connectionsFile
echo > $capture_memory_usageFile
echo > $capture_netusageFile
echo > $capture_diskusageFile

# Start processes and store pids in array
i=0
for cmd in ${procs[*]}
do
    $cmd &
    pids[${i}]=$!
    ((i++))
done

echo "Waiting for $capture_duration."

sleep $capture_duration

echo "Waiting for all procs to exit"
for pid in ${pids[*]}
do
    kill -9 $pid 2>/dev/null 
done
