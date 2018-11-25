function CollectMachinesProperties
{  
echo "vCores: "`uname`
echo "Disk:"
df -h| grep datadrive
if [ `lsmod | grep mlx| wc -l` -ge 1 ]
then
echo "AcceleratedNetwork Enabled"
else
echo "AcceleratedNetwork **NOT** Enabled"
fi
}
----
TestMode=LH
if [ $# -gt 0 ]; then
    TestMode=$1
fi
echo $TestMode

echo "Starting the test.."
Iteration=1
while sleep  1
do
if [ $TestMode == "performance" ]; then
    break
fi
echo "-------- End of the test iteration: $Iteration -------- "

Iteration=$((Iteration + 1))
done
echo "End!"

function FixValue()
{
    if [ "x$1" != "x"  ]
    then
        echo $1
    else
        echo -
    fi
}
FixValue asdad
FixValue ""
FixValue asdad
echo $(FixValue `grep srmPGPtest16 ClientDetails.txt`),$(FixValue `grep srmPGPerftest16 ClientDetails.txt`)
echo $(FixValue `grep srmPGPtest16 ClientDetails.txt`)


function TestMyServer()
{
TestDataFile='ConnectionProperties.csv'
UserName=$(grep -i "DbUserName," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
PassWord=$(grep -i "DbPassWord," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

Server=""
ScaleFactor=""
Connections=""
Threads=""
myhostname=`hostname`
if [ $(grep "$myhostname," $TestDataFile| wc -l) -gt 1 ]
then
echo "you have more entries dude"
Server=($(grep "$myhostname," $TestDataFile | sed "s/,/ /g" | awk '{print $2}'))
ScaleFactor=($(grep "$myhostname," $TestDataFile | sed "s/,/ /g" | awk '{print $3}'))
Connections=($(grep "$myhostname," $TestDataFile | sed "s/,/ /g" | awk '{print $4}'))
Threads=($(grep "$myhostname," $TestDataFile | sed "s/,/ /g" | awk '{print $5}'))
else
TestData=($(grep "$myhostname," $TestDataFile | sed "s/,/  /g"))
Server=${TestData[1]}
ScaleFactor=${TestData[2]}
Connections=${TestData[3]}
Threads=${TestData[4]}
fi

count=0
while [ "x${Server[$count]}" != "x" ]
do
#echo $UserName $PassWord $Server
pg_isready -U $UserName  -h ${Server[$count]} -p 5432 -d postgres
echo Server=$Server
echo ScaleFactor=$ScaleFactor
echo Connections$Connections
echo Threads=$Threads
echo "-----------------------"
#psql -U $UserName  -h $Server -p 5432 -d postgres
    ((count++))
done
}


function TestAllServers()
{
TestDataFile='ConnectionProperties.csv'
PerformanceTestMode="Performance"
LongHaulTestMode="LongHaul"

UserName=$(grep -i "DbUserName," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
PassWord=$(grep -i "DbPassWord," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

Server=""
ScaleFactor=""
Connections=""
Threads=""

Server=($(grep -i "$PerformanceTestMode\|$LongHaulTestMode" $TestDataFile | sed "s/,/ /g" | awk '{print $2}'))
ScaleFactor=($(grep -i "$PerformanceTestMode\|$LongHaulTestMode" $TestDataFile | sed "s/,/ /g" | awk '{print $3}'))
Connections=($(grep -i "$PerformanceTestMode\|$LongHaulTestMode" $TestDataFile | sed "s/,/ /g" | awk '{print $4}'))
Threads=($(grep -i "$PerformanceTestMode\|$LongHaulTestMode" $TestDataFile | sed "s/,/ /g" | awk '{print $5}'))
ClientVMs=($(grep -i "$PerformanceTestMode\|$LongHaulTestMode" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))

count=0
while [ "x${Server[$count]}" != "x" ]
do
#echo $UserName $PassWord $Server
echo "ClientVM= "`ssh ${ClientVMs[$count]} hostname`
echo Server=${Server[$count]}
echo ScaleFactor=${ScaleFactor[$count]}
echo Connections${Connections[$count]}
echo Threads=${Threads[$count]}
pg_isready -U $UserName  -h ${Server[$count]} -p 5432 -d postgres
echo "-----------------------"
#psql -U $UserName  -h $Server -p 5432 -d postgres
((count++))
done
}

function SetPasswordlessSSH()
{
TestDataFile='ConnectionProperties.csv'
PerformanceTestMode="Performance"
LongHaulTestMode="LongHaul"

ClientVMs=""

ClientVMs=($(grep -i "$PerformanceTestMode\|$LongHaulTestMode" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))

count=0
while [ "x${Server[$count]}" != "x" ]
do
echo "ClientVM= "`ssh ${ClientVMs[$count]} hostname`
ssh-copy-id -i ~/.ssh/id_rsa.pub ${ClientVMs[$count]} 
echo "-----------------------"
((count++))
done
}



{ 

res_ClientDetails=(`cat  ClientDetails.txt`)
count=0
while [ "x${res_ClientDetails[$count]}" != "x" ]
do
    #cat ~/.ssh/id_rsa.pub | ssh ${res_ClientDetails[$count]} 'cat >> .ssh/authorized_keys'
    ssh-copy-id -i ~/.ssh/id_rsa.pub ${res_ClientDetails[$count]} 
    ssh ${res_ClientDetails[$count]} hostname
    #scp pbenchTest.sh ${res_ClientDetails[$count]}:/home/orcasql/W
    ((count++))
done

}

