#!/bin/bash
pkill pbenchTest
pkill pgbench

cd /$HOME/W/
LogFile=RunLog.log
nohup ./pbenchTest.sh > $LogFile 2>&1 &
