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

if [ $(grep "`hostname`," $TestDataFile| wc -l) -gt 1 ]
then
echo "you have more entries dude"
Server=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g" | awk '{print $2}'))
ScaleFactor=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g" | awk '{print $3}'))
Connections=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g" | awk '{print $4}'))
Threads=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g" | awk '{print $5}'))
else
echo "you **dont** have more entries dude"
TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))
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
#psql -U $UserName  -h $Server -p 5432 -d postgres
    ((count++))
done
}



{ 

res_ClientDetails=(`cat  ClientDetails.txt`)
count=0
while [ "x${res_ClientDetails[$count]}" != "x" ]
do
    #cat ~/.ssh/id_rsa.pub | ssh ${res_ClientDetails[$count]} 'cat >> .ssh/authorized_keys'
    ssh ${res_ClientDetails[$count]} hostname
    scp pbenchTest.sh ${res_ClientDetails[$count]}:/home/orcasql/W
    ((count++))
done

}

