#!/bin/bash
pkill CollectSer

cd /$HOME/W/

LogFile=RunLog.log
chmod +x ./CollectServerStats.sh
nohup ./CollectServerStats.sh > $LogFile 2>&1 &
