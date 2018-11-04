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
