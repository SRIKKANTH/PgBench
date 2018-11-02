#!/bin/bash

cd /root/W/PgBench/
echo "-------- Triggering todays job ... -------- `date`"  >> /root/W/PgBench/DailyTriggerLog.log 
/bin/bash /root/W/PgBench/pgBenchParser.sh >> /root/W/PgBench/DailyTriggerLog.log 
