#!/bin/bash
pkill pbenchTest
pkill pgbench
cd /home/orcasql/W/
LogFile=LogPbenchTest_`hostname`.log
LogFileLast=Last_$LogFile

if [ -f $LogFile ]; then
    folder=OldLogs/`date|sed "s/ /_/g"| sed "s/:/_/g"`
    mkdir -p $folder
    cp $LogFile $folder/
    mv $LogFile $LogFileLast 
fi
nohup ./pbenchTest.sh > $LogFile 2>&1 &
