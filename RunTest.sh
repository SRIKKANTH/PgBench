#!/bin/bash
pkill pbenchTest
pkill pgbench
cd /home/orcasql/W/

nohup ./pbenchTest.sh > RunLog.log 2>&1 &
