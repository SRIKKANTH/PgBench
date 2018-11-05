function TestServers()
{
TestDataFile='ConnectionProperties.csv'
TestData=($(grep "`hostname`," $TestDataFile | sed "s/,/ /g"))

Server=${TestData[1]}
ScaleFactor=${TestData[2]}
Connections=${TestData[3]}
Threads=${TestData[4]}

UserName=$(grep -i "DbUserName," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')
PassWord=$(grep -i "DbPassWord," $TestDataFile | sed "s/,/ /g" | awk '{print $2}')

echo $UserName $PassWord $Server

psql -U $UserName  -h $Server -p 5432 -d postgres
}


res_ClientDetails=(`cat  ClientDetails.txt`)
count=0
while [ "x${res_ClientDetails[$count]}" != "x" ]
do
    #cat ~/.ssh/id_rsa.pub | ssh ${res_ClientDetails[$count]} 'cat >> .ssh/authorized_keys'
    ssh ${res_ClientDetails[$count]} hostname
    ((count++))
done

