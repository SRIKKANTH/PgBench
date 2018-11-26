TestDataFile=ConnectionProperties.csv

LogsDbServer=`grep "LogsDbServer\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
LogsDbServerUsername=`grep "LogsDbServerUsername\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
LogsDbServerPassword=`grep "LogsDbServerPassword\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
LogsDataBase=`grep "LogsDataBase" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
LogsTableName=`grep "LogsTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

TestType='LongHaul'
Environment='Staging'
ServerType='StandalonePG'
ServerVcores=32
TPSIncConnEstablishing='12523,12701,12645'

ReferenceTpsAvg=`GetReferenceTpsAvg $TestType $Environment $ServerType $ServerVcores` 
function GetReferenceTpsAvg ()
{
    local TestType=$1
    local Environment=$2
    local ServerType=$3
    local ServerVcores=$4
    
    local LogsDbServer=`grep "LogsDbServer\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsDbServerUsername=`grep "LogsDbServerUsername\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsDbServerPassword=`grep "LogsDbServerPassword\b" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsDataBase=`grep "LogsDataBase" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`
    local LogsTableName=`grep "LogsTableName" $TestDataFile | sed "s/,/ /g"| awk '{print $2}'`

    local ReferenceValue=`sqlcmd -S $LogsDbServer -U $LogsDbServerUsername -P $LogsDbServerPassword  -d $LogsDataBase  -I -Q "SELECT  Avg(AverageTPS)  FROM $LogsTableName WHERE TestType = '$TestType' and ServerType='$ServerType' and Environment = '$Environment' and ServerVcores = $ServerVcores and AverageTPS != 0"` 
    echo $ReferenceValue | awk '{print $2}'  | sed 's/\..*//' 2>&1
}

ReferenceTpsAvg=`echo $ReferenceTpsAvg | awk '{print $2}'  | sed 's/\..*//' 2>&1`


local 

re='^[0-9]+$'
if [[ $ReferenceTpsAvg =~ $re ]] ; then
   echo "Hurrah: A number!"
fi

echo $TPSIncConnEstablishing|awk -F"," '{print $1}' 

CurrentTpsAvg=`echo $TPSIncConnEstablishing|awk -F"," '{print $3}'`

HowGoodIsIt $CurrentTpsAvg $ReferenceTpsAvg 

function HowGoodIsIt()
{
    CurrentValue=$1
    ReferenceValue=$2
    if [ $CurrentValue -ge $ReferenceValue ]
    then
        echo "Good"
    elif [ $CurrentValue == 0 ]
    then 
        echo "Aborted"
    elif [ $CurrentValue -ge `echo $ReferenceValue*95/100 | bc` ]
    then
        echo "Normal"
    elif [ $CurrentValue -le `echo $ReferenceValue*95/100 | bc` ]
    then
        echo "Bad"
    elif [ $CurrentValue -le `echo $ReferenceValue*80/100 | bc` ]
    then
        echo "Worst"
    fi
}

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
MatchingPatter="$PerformanceTestMode\|$LongHaulTestMode"

Server=($(grep -i "$MatchingPatter" $TestDataFile | sed "s/,/ /g" | awk '{print $2}'))
ScaleFactor=($(grep -i "$MatchingPatter" $TestDataFile | sed "s/,/ /g" | awk '{print $3}'))
Connections=($(grep -i "$MatchingPatter" $TestDataFile | sed "s/,/ /g" | awk '{print $4}'))
Threads=($(grep -i "$MatchingPatter" $TestDataFile | sed "s/,/ /g" | awk '{print $5}'))
ClientVMs=($(grep -i "$MatchingPatter" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))

count=0
while [ "x${Server[$count]}" != "x" ]
do

echo "ClientVM= "`ssh ${ClientVMs[$count]} hostname`
echo Server=${Server[$count]}
echo ScaleFactor=${ScaleFactor[$count]}
echo Connections${Connections[$count]}
echo Threads=${Threads[$count]}
pg_isready -U $UserName  -h ${Server[$count]} -p 5432 -d postgres
echo "-----------------------"

((count++))
done
}

function SetUpClients()
{
TestDataFile='ConnectionProperties.csv'
PerformanceTestMode="Performance"
LongHaulTestMode="LongHaul"

matchPatter="$PerformanceTestMode\|$LongHaulTestMode"

ClientVMs=""

ClientVMs=($(grep -i "$matchPatter" $TestDataFile | sed "s/,/ /g" | awk '{print $8}'))

count=0
while [ "x${ClientVMs[$count]}" != "x" ]
do
echo "ClientVM= "`ssh ${ClientVMs[$count]} hostname`
VMUser=`echo ${ClientVMs[$count]} | sed 's/@.*//'`
    
ssh-copy-id -i ~/.ssh/id_rsa.pub ${ClientVMs[$count]} 2>/dev/null
ssh ${ClientVMs[$count]} "[ -d /home/$VMUser/W/Logs/ ] || mkdir -p /home/$VMUser/W/Logs/"
scp pbenchTest.sh ${ClientVMs[$count]}:/home/$VMUser/W
scp RunTest.sh ${ClientVMs[$count]}:/home/$VMUser/W
scp $TestDataFile ${ClientVMs[$count]}:/home/$VMUser/W
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

TestDataFile='ConnectionProperties.csv'



scp pbenchTest.sh ${ClientVMs[$count]}:/home/$VMUser/W
scp RunTest.sh ${ClientVMs[$count]}:/home/$VMUser/W

count=1
while [ "x${res_ClientDetails[$count]}" != "x" ]
do
    #VMUser=`echo ${res_ClientDetails[$count]} | sed 's/@.*//'`
    VMUser=`ssh ${res_ClientDetails[$count]} 'echo $USER'`
    ssh ${res_ClientDetails[$count]} 'hostname' 
    #scp ${res_ClientDetails[$count]}:/home/$VMUser/W/Logs/* $log_folder/ 
    #scp $TestDataFile ${res_ClientDetails[$count]}:/home/$VMUser/W/
    #ssh ${res_ClientDetails[$count]} "bash /home/orcasql/W/RunTest.sh"
    ssh ${res_ClientDetails[$count]} "ls /home/$VMUser/W/"
    ((count++))
done
echo "Getting logs from clients.. done!"    


function FixOutput ()
{
    [ -z "$1" ] && echo $2 || echo $1
}
