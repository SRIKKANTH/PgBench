#!/bin/bash
pkill pbenchTest
pkill pgbench

cd /home/$USER/W/
LogFile=RunLog.log
nohup ./pbenchTest.sh > $LogFile 2>&1 &
