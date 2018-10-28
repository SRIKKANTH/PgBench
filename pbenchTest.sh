#!/bin/bash
set +H
Duration=1800
UserName="pgadmin"
PassWord="pgadmin123!@#"

Server=$(grep "`hostname`," ConnectionProperties.csv | sed "s/,/ /g"| awk '{print $2}')
ScaleFactor=$(grep "`hostname`," ConnectionProperties.csv | sed "s/,/ /g"| awk '{print $3}')
Connections=$(grep "`hostname`," ConnectionProperties.csv | sed "s/,/ /g"| awk '{print $4}')
Threads=$(grep "`hostname`," ConnectionProperties.csv | sed "s/,/ /g"| awk '{print $5}')

echo "-------- Initializing db... -------- `date`"
    
echo "PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/postgres"
PGPASSWORD=$PassWord pgbench -i -s $ScaleFactor -U $UserName postgres://$Server:5432/postgres
echo ""
echo "-------- Initializing db... Done! -------- "
    
echo "Starting the test.."
Iteration=1
while sleep  1
do
    echo "-------- Starting the test iteration: $Iteration -------- `date`"
    echo "Sleeping for 10 secs.."
    sleep 15
    echo "Sleeping for 10 secs..Done!"
    echo "Executing: PGPASSWORD=$PassWord pgbench -P 30 -c $Connections -j $Threads -T $Duration -U pgadmin postgres://$Server:5432/postgres"
    PGPASSWORD=$PassWord pgbench -P 60 -c $Connections -j $Threads -T $Duration -U pgadmin postgres://$Server:5432/postgres
    echo "-------- End of the test iteration: $Iteration -------- "
    Iteration=$((Iteration + 1))
done
