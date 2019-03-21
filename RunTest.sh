#!/bin/bash
pkill pbenchTest
pkill pgbench
pkill sysbench
pkill sed
pkill psql
pkill grep


cd /$HOME/W/
LogFile=runLog.log
nohup ./pbenchTest.sh > $LogFile 2>&1 &
