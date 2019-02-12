
testDisk()
{
        log_file_name=$1
        disk_list=( 'sda' 'sdf' )
        #disk_list=( 'sdf' )
        #disk_list=( `cat $log_file_name |grep "ServerDiskReadMBpsMinMax s"| awk '{print $2}'| sort| uniq`)
        count=0
        while [ "x${disk_list[$count]}" != "x" ]
        do
            echo "Parsing for '${disk_list[$count]}'"
            Temp=(`grep "ServerDisk ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskAverage_Server[$count,$j]=${Temp[$j]}
                echo ${Temp[$j]}-${res_ServerDiskAverage_Server[$count,$j]} - res_ServerDiskAverage_Server[$count,$j]
                ((j++))
            done

            Temp=(`grep "ServerDiskIOPSMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxIOPS_Server[$count,$j]=${Temp[$j]}
                #echo ${Temp[$j]}
                ((j++))
            done

            Temp=(`grep "ServerDiskReadMBpsMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxReadMBps_Server[$count,$j]=${Temp[$j]}
                
                ((j++))
            done

            Temp=(`grep "ServerDiskWriteMBpsMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`) 
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxWriteMBps_Server[$count,$j]=${Temp[$j]}
                ((j++))
            done
            
            ((count++))
        done
        
        TitleString=""
        i=0
        while [ "x${disk_list[$i]}" != "x" ]
        do
            TitleString=$TitleString"${disk_list[$i]}-IOPSAvg,${disk_list[$i]}-MbpsReadAvg,${disk_list[$i]}-MbpsWriteAvg,${disk_list[$i]}-IOPSMin,${disk_list[$i]}-IOPSMax,${disk_list[$i]}-ReadMBpsMin,${disk_list[$i]}-ReadMBpsMax,${disk_list[$i]}-WriteMBpsMin,${disk_list[$i]}-WriteMBpsMax,,"
            ((i++))
        done  
        #echo "sdcIOPSAvg,sdcMbpsReadAvg,sdcMbpsWriteAvg,sdcIOPSMin,sdcIOPSMax,sdcReadMBpsMin,sdcReadMBpsMax,sdcWriteMBpsMin,sdcWriteMBpsMax,sddIOPSAvg,sddMbpsReadAvg,sddMbpsWriteAvg,sddIOPSMin,sddIOPSMax,sddReadMBpsMin,sddReadMBpsMax,sddWriteMBpsMin,sddWriteMBpsMax" 
        
        echo $TitleString

        j=0
        while [ "x${res_ServerDiskAverage_Server[0,$j]}" != "x" ]
        do
            i=0
            ResString=""
            while [ "x${disk_list[$i]}" != "x" ]
            do
                echo "for: ${disk_list[$i]}-${res_ServerDiskAverage_Server[$i,$j]} - res_ServerDiskAverage_Server[$i,$j]"
                ResString=$ResString"${res_ServerDiskAverage_Server[$i,$j]},-${res_ServerDiskMinMaxIOPS_Server[$i,$j]},-${res_ServerDiskMinMaxReadMBps_Server[$i,$j]},-${res_ServerDiskMinMaxWriteMBps_Server[$i,$j]},," 
                ((i++))
            done
           #echo $ResString
            ((j++))
        done

}

--
testDisk()
{
        log_file_name=$1
        disk_list=( `cat $log_file_name |grep "ServerDiskReadMBpsMinMax s"| awk '{print $2}'| sort| uniq`)
        count=0
        while [ "x${disk_list[$count]}" != "x" ]
        do
            echo "Parsing for '${disk_list[$count]}'"
            Temp=(`grep "ServerDisk ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskAverage_Server[$count,$j]=${Temp[$j]}
                ((j++))
            done

            Temp=(`grep "ServerDiskIOPSMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxIOPS_Server[$count,$j]=${Temp[$j]}
                ((j++))
            done

            Temp=(`grep "ServerDiskReadMBpsMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxReadMBps_Server[$count,$j]=${Temp[$j]}
                ((j++))
            done

            Temp=(`grep "ServerDiskWriteMBpsMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`) 
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxWriteMBps_Server[$count,$j]=${Temp[$j]}
                ((j++))
            done
            
            ((count++))
        done
        
        TitleString=""
        i=0
        while [ "x${disk_list[$i]}" != "x" ]
        do
            TitleString=$TitleString"${disk_list[$i]}-IOPSAvg,${disk_list[$i]}-MbpsReadAvg,${disk_list[$i]}-MbpsWriteAvg,${disk_list[$i]}-IOPSMin,${disk_list[$i]}-IOPSMax,${disk_list[$i]}-ReadMBpsMin,${disk_list[$i]}-ReadMBpsMax,${disk_list[$i]}-WriteMBpsMin,${disk_list[$i]}-WriteMBpsMax,,"
            ((i++))
        done  
        #echo "sdcIOPSAvg,sdcMbpsReadAvg,sdcMbpsWriteAvg,sdcIOPSMin,sdcIOPSMax,sdcReadMBpsMin,sdcReadMBpsMax,sdcWriteMBpsMin,sdcWriteMBpsMax,sddIOPSAvg,sddMbpsReadAvg,sddMbpsWriteAvg,sddIOPSMin,sddIOPSMax,sddReadMBpsMin,sddReadMBpsMax,sddWriteMBpsMin,sddWriteMBpsMax" 
        
        echo $TitleString

        j=0
        while [ "x${res_ServerDiskAverage_Server[$j]}" != "x" ]
        do
            i=0
            ResString=""
            while [ "x${disk_list[$i]}" != "x" ]
            do
                ResString=$ResString"${res_ServerDiskAverage_Server[$i,$j]},${res_ServerDiskMinMaxIOPS_Server[$i,$j]},${res_ServerDiskMinMaxReadMBps_Server[$i,$j]},${res_ServerDiskMinMaxWriteMBps_Server[$i,$j]},," 
                ((i++))
            done
            echo $ResString
            ((j++))
        done

}

--

testDisk()
{
        log_file_name=$1
        disk_list=( 'sda' 'sdf' )
        #disk_list=( 'sdf' )
        #disk_list=( `cat $log_file_name |grep "ServerDiskReadMBpsMinMax s"| awk '{print $2}'| sort| uniq`)
        count=0
        while [ "x${disk_list[$count]}" != "x" ]
        do
            echo "Parsing for '${disk_list[$count]}'"
            Temp=(`grep "ServerDisk ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskAverage_Server[$count,$j]=${Temp[$j]}
                echo ${Temp[$j]}-${res_ServerDiskAverage_Server[$count,$j]} - res_ServerDiskAverage_Server[$count,$j]
                ((j++))
            done

            Temp=(`grep "ServerDiskIOPSMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxIOPS_Server[$count,$j]=${Temp[$j]}
                #echo ${Temp[$j]}
                ((j++))
            done

            Temp=(`grep "ServerDiskReadMBpsMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`)
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxReadMBps_Server[$count,$j]=${Temp[$j]}
                
                ((j++))
            done

            Temp=(`grep "ServerDiskWriteMBpsMinMax ${disk_list[$count]}" $log_file_name  |awk '{print $4}'`) 
            j=0
            while [ "x${Temp[$j]}" != "x" ]
            do
                res_ServerDiskMinMaxWriteMBps_Server[$count,$j]=${Temp[$j]}
                ((j++))
            done
            
            ((count++))
        done
        
        TitleString=""
        i=0
        while [ "x${disk_list[$i]}" != "x" ]
        do
            TitleString=$TitleString"${disk_list[$i]}-IOPSAvg,${disk_list[$i]}-MbpsReadAvg,${disk_list[$i]}-MbpsWriteAvg,${disk_list[$i]}-IOPSMin,${disk_list[$i]}-IOPSMax,${disk_list[$i]}-ReadMBpsMin,${disk_list[$i]}-ReadMBpsMax,${disk_list[$i]}-WriteMBpsMin,${disk_list[$i]}-WriteMBpsMax,,"
            ((i++))
        done  
        #echo "sdcIOPSAvg,sdcMbpsReadAvg,sdcMbpsWriteAvg,sdcIOPSMin,sdcIOPSMax,sdcReadMBpsMin,sdcReadMBpsMax,sdcWriteMBpsMin,sdcWriteMBpsMax,sddIOPSAvg,sddMbpsReadAvg,sddMbpsWriteAvg,sddIOPSMin,sddIOPSMax,sddReadMBpsMin,sddReadMBpsMax,sddWriteMBpsMin,sddWriteMBpsMax" 
        
        echo $TitleString

        j=0
        while [ "x${res_ServerDiskAverage_Server[0,$j]}" != "x" ]
        do
            i=0
            ResString=""
            while [ "x${disk_list[$i]}" != "x" ]
            do
                echo "for: ${disk_list[$i]}-${res_ServerDiskAverage_Server[$i,$j]} - res_ServerDiskAverage_Server[$i,$j]"
                ResString=$ResString"${res_ServerDiskAverage_Server[$i,$j]},-${res_ServerDiskMinMaxIOPS_Server[$i,$j]},-${res_ServerDiskMinMaxReadMBps_Server[$i,$j]},-${res_ServerDiskMinMaxWriteMBps_Server[$i,$j]},," 
                ((i++))
            done
           #echo $ResString
            ((j++))
        done

}

--


function get_MinMax()
{
    inputArray=("$@")
    count=${#inputArray[@]}
    lastIndex=$((count-1))

    IFS=$'\n' sorted=($(sort -n <<<"${inputArray[*]}"))
    unset IFS
    min=`printf "%.f\n" ${sorted[0]}`
    max=`printf "%.f\n" ${sorted[$lastIndex]}`
    echo "$min,$max"
}


get_Avg()
{
    inputArray=("$@")
    count=${#inputArray[@]}
    sum=$( IFS="+"; bc <<< "${inputArray[*]}" )
    unset IFS
    average=`echo $sum/$count|bc -l`
    printf "%.3f\n" $average
}

get_Column_Avg()
{
    local filename=$1
    local results
    columns=`tail -1 $filename |wc -w`
    i=0
    for j in $(seq 1 $columns)
    do
        results[$i]=`get_Avg $(cat $filename | awk -vcol=$j '{print $col}')`
        ((i++))
    done
    echo ${results[*]}| sed 's/ /,/g'
}


get_captured_server_usages(){
    echo "Server VM stats (Average) during test:--"
    if [ -f $capture_server_netusageFile ]
    then
        echo "ServerNetwork "`cat $capture_server_netusageFile| grep Average| head -1|awk '{print $5}'` ":" `cat $capture_server_netusageFile| grep Average|grep eth0| awk '{print $5}'`
        echo "ServerNetwork "`cat $capture_server_netusageFile| grep Average| head -1|awk '{print $6}'` ":" `cat $capture_server_netusageFile| grep Average|grep eth0| awk '{print $6}'`
    fi
    echo "ServerConnections : " `get_Column_Avg $capture_server_connectionsFile`
    echo "CPU usage (OS): " `get_Column_Avg $capture_cpu_SystemFile`
    echo "Memory stats OS (total,used,free): " `get_Column_Avg $capture_memory_usageFile`

    echo "ServerDiskUsage: IOPS,MbpsRead,MbpsWrite" 
    disk_list=(`cat $capture_server_diskusageFile | grep ^sd| awk '{print $1}' |sort |uniq`)

    count=0
    while [ "x${disk_list[$count]}" != "x" ]
    do
        disk=${disk_list[$count]}
        
        cat $capture_server_diskusageFile | grep ^$disk| awk '{print $2"\t"$3"\t"$4}' > $capture_server_diskusageFile.tmp
        echo "ServerDisk "$disk ": "`get_Column_Avg $capture_server_diskusageFile.tmp`
        ((count++))
    done   

    echo "ServerDiskUsageIOPS: Min,Max" 

    count=0
    while [ "x${disk_list[$count]}" != "x" ]
    do
        disk=${disk_list[$count]}
        
        IOPS_Array=(`cat $capture_server_diskusageFile | grep ^$disk| awk '{print $2}'`)
        echo "ServerDiskIOPSMinMax "$disk ": "`get_MinMax $IOPS_Array`
        ((count++))
    done   
}


-------------------
echo "Nooooo"



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

CurrentTpsAvg=23;ReferenceTpsAvg=100
echo $(($CurrentTpsAvg-$ReferenceTpsAvg))

bash
function get_Percentage ()
{
    printf "%.1f\n" `echo 100*$1/$2 |bc -l`
}


function HowGoodIsIt()
{
    CurrentValue=$1
    ReferenceValue=$2
    
    Difference=`echo $CurrentValue-$ReferenceValue |bc -l`
    Difference=`get_Percentage $Difference $ReferenceValue`

    if [ `echo "$CurrentValue == 0" | bc -l` != 0 ]
    then 
        echo "Aborted ($Difference%)"
    elif [ `echo "$Difference >= 0" | bc -l` != 0 ]
    then
        Difference="+$Difference"
        echo "Good ($Difference%)"
    elif [ `echo "$Difference >= -5" | bc -l` != 0 ]
    then
        echo "Normal ($Difference%)"
    elif [ `echo "$Difference >= -20" | bc -l` != 0 ]
    then
        echo "Bad ($Difference%)"
    elif [ `echo "$Difference < -20" | bc -l` != 0 ]
    then
        echo "Worst ($Difference%)"

    fi
}
HowGoodIsIt 4122 3856

NUMBERS="9 7 3 8 37.53 98 95 92 101 102 123 154"

for CurrentTpsAvg in `echo $NUMBERS`  # for number in 9 7 3 8 37.53
do
    Difference=`HowGoodIsIt $CurrentTpsAvg 100`

    echo $CurrentTpsAvg  
    echo $Difference 
    #echo $diff 
done

exit

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
