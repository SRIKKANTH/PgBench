#!/bin/bash
#
# This script starts pgbench test.
#
# Author: Srikanth Myakam
#
########################################################################

pkill pbenchTest
pkill pgbench
pkill sysbench
pkill sed
pkill psql
pkill grep

echo "" > $HOME/UpdateResourceHeathToLogsDB.log
echo "" > $HOME/runLog.log

LogFile=runLog.log
chmod +x *.sh
nohup ./pbenchTest.sh > $LogFile 2>&1 &

echo "The Test is started now."
echo "You can check current status by executing below command:"
echo "tail -f Logs/*.log"

