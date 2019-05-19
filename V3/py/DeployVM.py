import json
import datetime
import subprocess
import os
import time
import db
import ssh
import logging

try:
    import commands
except ImportError:
    import subprocess as commands

ConfigurationFile='./Environment.json'
TestDataFile='./TestData.json'

#logging.basicConfig(level=logging.INFO)
#logger = logging.getLogger(__name__)

try:
    # Initialise parameters
    with open(ConfigurationFile) as EnvironmentFile:  
        EnvironmentData = json.load(EnvironmentFile)

except IOError:
    print(f"Cannot find ConfigurationFile({ConfigurationFile}). Please check and re-try!")
    exit(1)

try:
    # Initialise parameters
    with open(TestDataFile) as TestDataFileHandler:  
        TestData = json.load(TestDataFileHandler)

except IOError:
    print(f"Cannot find TestDataFile({TestDataFile}). Please check and re-try!")
    exit(1)

def ValidateAndFixParameters(EnvironmentData, TestData):
    # Use only lowercase for simplicity
    TestData["Operation"]=TestData["Operation"].lower()
    TestData["ClientDetails"]["Client_Region"]=TestData["ClientDetails"]["Client_Region"].lower()
    TestData["ClientDetails"]["Client_VM_SKU"]=TestData["ClientDetails"]["Client_VM_SKU"].lower()
    TestData["ServerDetails"]["Test_Server_Region"] = TestData["ServerDetails"]["Test_Server_Region"].lower()
    TestData["ServerDetails"]["Test_Server_Server_Edition"] = TestData["ServerDetails"]["Test_Server_Server_Edition"].lower()
    TestData["ServerDetails"]["Test_Database_Topology"] = TestData["ServerDetails"]["Test_Database_Topology"].lower()
    TestData["ServerDetails"]["Test_Database_Type"] = TestData["ServerDetails"]["Test_Database_Type"].lower()
    TestData["ServerDetails"]["Test_Database_Name"] = TestData["ServerDetails"]["Test_Database_Name"].lower()
    TestData["ServerDetails"]["Test_Server_Environment"]  = TestData["ServerDetails"]["Test_Server_Environment"].lower()

    Operation=TestData["Operation"]
    Client_Hostname = TestData["ClientDetails"]["Client_Hostname"]
    Client_Region = TestData["ClientDetails"]["Client_Region"]

    Test_Database_Type = TestData["ServerDetails"]["Test_Database_Type"]
    Test_Server_fqdn = TestData["ServerDetails"]["Test_Server_fqdn"]
    Test_Server_Username = TestData["ServerDetails"]["Test_Server_Username"]
    Test_Server_Password = TestData["ServerDetails"]["Test_Server_Password"]
    Test_Database_Name = TestData["ServerDetails"]["Test_Database_Name"]
    Test_Server_Region = TestData["ServerDetails"]["Test_Server_Region"]

    LogsDbServer = EnvironmentData["LogsDBConfig"]["LogsDbServer"]
    LogsDbServerUsername = EnvironmentData["LogsDBConfig"]["LogsDbServerUsername"]
    LogsDbServerPassword = EnvironmentData["LogsDBConfig"]["LogsDbServerPassword"]
    LogsDataBase = EnvironmentData["LogsDBConfig"]["LogsDataBase"]
    ServerInfoTableName = EnvironmentData["LogsDBConfig"]["ServerInfoTableName"]

    # Get VM Name if 
    if ( len(Client_Hostname) != 0 ) and (Operation == 'create'):
        print(f"Option 'Client_Hostname'({Client_Hostname}) is not empty and you asked to create new client.")
        if input(f"Do you want to create new client VM with '{Client_Hostname}' name? [yes/no]: ") != 'yes':
            TestData["ClientDetails"]["Client_Hostname"] = ""
        else: 
            print(f"New Client will be created with '{Client_Hostname}' name")

    # Check Test_Server details
    if Test_Server_fqdn == "" or Test_Server_fqdn == None:
        print(f"Missing 'Test_Server_fqdn' cannot continue. Please config 'Test_Server_fqdn' \
            in {ConfigurationFile} and try again")
        exit(1)
    else:
        if Test_Database_Type=='postgres':
            # Check Test_Server accessibility.
            print(f"Access to Test_Server_fqdn: {Test_Server_fqdn}:") 
            result=db.check_connectivity (Test_Server_fqdn, Test_Server_Username, \
                Test_Server_Password,Test_Database_Name)
            if not result:
                print(f"**Failed**.\nCheck your settings and re-try. Without this tests cannot be scheduled and executed")
                exit(1)
            else:
                print(f"Success!\n")

    # Verify regions of both client and server
    if Test_Server_Region != Client_Region:
        print(f"Server region ({Test_Server_Region}) is not same as client VM region ({Client_Region}) is this the valid config?")
        cross_region_test=input("Do you want to continue? [yes/no]: ")
        if cross_region_test == 'no':
            RollBack()
        else: 
            print(f"This will be a cross region test. The performance will be a lot less than same region tests due to higher network latencies")

    # Check LogsDbServer accessibility.
    print(f"Access to LogsDbServer: {LogsDbServer}:")
    result=db.check_connectivity (LogsDbServer, LogsDbServerUsername, LogsDbServerPassword, LogsDataBase)
    if not result:
        print(f"**Failed**. \n Check your setting and re-try. \nWithout this tests cannot be scheduled or executed")
        RollBack()
    else:
        print(f"Success!\n")
    
    # Check if there is server config already exists
    result=db.check_row_exists(LogsDbServer, LogsDbServerUsername, LogsDbServerPassword, LogsDataBase, ServerInfoTableName, Column="test_server_fqdn", Value=Test_Server_fqdn)
    if result:
        print (f"There exists an entry for given server: '{Test_Server_fqdn}' in ServerInfoTableName '{ServerInfoTableName}'.\n Which means it might be assigned for other client already.")
        overwrite=input("Do you want to free the test server and assign it to the new VM client? [yes/no]: ")
        if overwrite=='no':
            RollBack()
        else: 
            print(f"Config for given server: '{Test_Server_fqdn}' in ServerInfoTableName will be modifed for new client")

def CreateResourceGroup(TestData):
    Client_Region = TestData["ClientDetails"]["Client_Region"]
    Client_Resource_Group=TestData["ClientDetails"]["Client_Resource_Group"]
    
    print(f"Creating new Client_Resource_Group {Client_Resource_Group} in {Client_Region}")
    ReturnStatus = subprocess.check_output(f"az group create --name {Client_Resource_Group} \
        --location {Client_Region}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["properties"]["provisioningState"]:
        print(f"Failed to create resource group: {Client_Resource_Group}")
        RollBack()
    else:
        print(f"Success!\n")

def RollBack():
    print(f"FATAL: Occured unrecovered failure. Trying to roll back changes and exit.")
    exit(-1)

def CreateVirtualMachine(TestData):
    Client_Region = TestData["ClientDetails"]["Client_Region"]
    Client_Resource_Group=TestData["ClientDetails"]["Client_Resource_Group"]
    Client_VM_SKU = TestData["ClientDetails"]["Client_VM_SKU"]
    Client_Hostname = TestData["ClientDetails"]["Client_Hostname"]
    Client_Username = TestData["ClientDetails"]["Client_Username"]
    Client_Password = TestData["ClientDetails"]["Client_Password"]
    OSImage = TestData["ClientDetails"]["OSImage"]
    

    if Client_VM_SKU is None or Client_VM_SKU == "":
        Client_VM_SKU = "Standard_D4s_v3".lower()

    if OSImage is None or OSImage == "":
        OSImage = "UbuntuLTS"

    VnetName = Client_Hostname+"-vnet"
    SubnetName = Client_Hostname+"-subnet"
    NsgName = Client_Hostname+"-nsg"
    PublicIpName = Client_Hostname+"-pip"
    NicName = Client_Hostname+"-nic"

    # Create a virtual network.
    print(f"Creating VNET: {VnetName}")
    ReturnStatus = subprocess.check_output(f"az network vnet create --resource-group {Client_Resource_Group} \
        --location {Client_Region} --name {VnetName} --subnet-name {SubnetName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["newVNet"]["subnets"][0]["provisioningState"]:
        print(f"FATAL: Failed to create SubnetName: {SubnetName}")
        RollBack()
    else:
        print(f"Success!\n")

    # Create a public IP address.
    print(f"Creating Publlic IP: {PublicIpName}")
    ReturnStatus = subprocess.check_output(f"az network public-ip create --resource-group {Client_Resource_Group} \
         --location {Client_Region} --name {PublicIpName} --allocation-method dynamic --dns-name {Client_Hostname.lower()}", \
         shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["publicIp"]["provisioningState"]:
        print(f"FATAL: Failed to create PublicIp: {PublicIpName}")
        RollBack()
    else:
        print(f"Success!\n")

    # Create a network security group.
    print(f"Creating Network Security Group: {NsgName}")
    ReturnStatus = subprocess.check_output(f"az network nsg create --resource-group {Client_Resource_Group} \
        --location {Client_Region} --name {NsgName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["NewNSG"]["provisioningState"]:
        print(f"FATAL: Failed to create NSG: {NsgName}")
        RollBack()
    else:
        print(f"Success!\n")
    
    # Create a virtual network card and associate with public IP address and NSG.
    print(f"Creating NIC: {NicName}")
    ReturnStatus = subprocess.check_output(f"az network nic create --resource-group {Client_Resource_Group} \
        --location {Client_Region} --name {NicName} --vnet-name {VnetName} --subnet {SubnetName} \
        --network-security-group {NsgName} --public-ip-address {PublicIpName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["NewNIC"]["provisioningState"]:
        print(f"FATAL: Failed to create NIC: {NicName}")
        RollBack()
    else:
        print(f"Success!\n")
    
    # Create a new virtual machine.
    print(f"Creating Virtual Machine: {Client_Hostname}")
    ReturnStatus = subprocess.check_output(f"az vm create --resource-group {Client_Resource_Group} \
        --location {Client_Region} --name {Client_Hostname} --nics {NicName} --image {OSImage} \
        --size {Client_VM_SKU} --admin-username {Client_Username} --admin-password {Client_Password}", \
        shell=True, encoding='utf8')
    print(ReturnStatus)
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'VM running' != ReturnStatusJson["powerState"]:
        print(f"FATAL: Failed to create virtual machine: {Client_Hostname}")
        RollBack()
    else:
        print(f"Success!\n")

    #Open port 22 to allow SSH traffic to host.
    print(f"Enabling SSH port 22 for VM: {Client_Hostname}")
    ReturnStatus = subprocess.check_output(f'az network nsg rule create --nsg-name {NsgName} \
        --resource-group {Client_Resource_Group} -n {NsgName}-SSH --direction Inbound --priority 900 \
        --access Allow --source-address-prefixes * --source-port-ranges * --destination-address-prefixes * \
        --destination-port-ranges 22 --protocol tcp', shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["provisioningState"]:
        print(f"Enabling SSH port 22 for {Client_Hostname} is Failed")
        RollBack()
    else:
        print(f"Success!\n")

    TestData["ClientDetails"]["Client_FQDN"] = subprocess.check_output(f"az vm show -g {Client_Resource_Group} \
        -n {Client_Hostname} --query fqdns -d --out tsv", shell=True, encoding='utf8').strip()

def SetupClientVM(EnvironmentData, TestData):
    files=["CommonRoutines.sh", "RunTest.sh", "SendHeartBeat.sh", "pbenchTest.sh", "pgBenchParser.sh", \
        "ConnectionProperties.csv", "pgbenchSetupScript.sh"]
    
    CreateConfigFileForClient(EnvironmentData)
    
    Client_FQDN = TestData["ClientDetails"]["Client_FQDN"]
    Client_Username = TestData["ClientDetails"]["Client_Username"]
    Client_Password = TestData["ClientDetails"]["Client_Password"]

    for file in files:
        ssh.do_sftp(Client_FQDN, Client_Username, Client_Password, srcfilename=f'..\sh\{file}', operation='put')

    ssh.exec_cmd(Client_FQDN, Client_Username, Client_Password, "sudo apt-get update; sudo apt install -y \
        dos2unix;dos2unix * ;chmod +x *.sh;bash pgbenchSetupScript.sh>pgbenchSetupScript.log")

    ssh.do_sftp(Client_FQDN, Client_Username, Client_Password, srcfilename='pgbenchSetupScript.log', operation='get')

    if 'performance_test_setup_success' not in open('pgbenchSetupScript.log').read():
        print("Performance test setup Failed")
        RollBack()
    else:
        print("Performance test setup completed")
        return True
    return False

def CreateConfigFileForClient(EnvironmentData):
    filep = open("../sh/ConnectionProperties.csv","w")
    filep.write(f"LogsDbServer,{EnvironmentData['LogsDBConfig']['LogsDbServer']}\n")
    filep.write(f"LogsDbServerUsername,{EnvironmentData['LogsDBConfig']['LogsDbServerUsername']}\n")
    filep.write(f"LogsDbServerPassword,{EnvironmentData['LogsDBConfig']['LogsDbServerPassword']}\n")
    filep.write(f"LogsDataBase,{EnvironmentData['LogsDBConfig']['LogsDataBase']}\n")
    filep.write(f"LogsTableName,{EnvironmentData['LogsDBConfig']['LogsTableName']}\n")
    filep.write(f"ResourceHealthTableName,{EnvironmentData['LogsDBConfig']['ResourceHealthTableName']}\n")
    filep.write(f"ServerInfoTableName,{EnvironmentData['LogsDBConfig']['ServerInfoTableName']}\n")
    filep.write(f"ClientInfoTableName,{EnvironmentData['LogsDBConfig']['ClientInfoTableName']}\n")
    filep.write(f"ScheduledTestsTable,{EnvironmentData['LogsDBConfig']['ScheduledTestsTable']}\n")
    filep.close()

def UpdateConfig(EnvironmentData, TestData, Client_Hostname = None):
    if Client_Hostname is None:
        Client_Hostname = TestData["ClientDetails"]["Client_Hostname"]

    Client_FQDN = TestData["ClientDetails"]["Client_FQDN"]
    Client_Username = TestData["ClientDetails"]["Client_Username"]
    Client_Password = TestData["ClientDetails"]["Client_Password"]

    if SetupClientVM(EnvironmentData, TestData):
        if db.InsertServerInfoIntoDb(EnvironmentData, TestData):
            if db.InsertClientInfoIntoDb(EnvironmentData, TestData):
                if db.InsertTestInfoIntoDb(EnvironmentData, TestData):
                    print("Done configuring tests.")
                    print("Starting a dry run...")
                    # Start the test now instead of waiting for next trigger interval
                    ssh.exec_cmd(Client_FQDN, Client_Username, Client_Password, "bash RunTest.sh")
                    print("Getting the first heartbeat")
                    # Generate First Hearbeat instead of waiting for next interval
                    ssh.exec_cmd(Client_FQDN, Client_Username, Client_Password, "sleep 5; bash SendHeartBeat.sh")
                else:
                    print("Failed to InsertTestInfoIntoDb")
                    return False
            else:
                print("Failed to InsertClientInfoIntoDb")
                return False
        else:
            print("Failed to InsertServerInfoIntoDb")
            return False
    else:
        print("Failed to SetupClientVM")
        return False
    return True

def CreateClientVirtualMachine (EnvironmentData, TestData):
    SubscriptionId=TestData["ClientDetails"]["SubscriptionId"]
    Client_Region = TestData["ClientDetails"]["Client_Region"]
    Client_Resource_Group=TestData["ClientDetails"]["Client_Resource_Group"]
    Client_VM_SKU = TestData["ClientDetails"]["Client_VM_SKU"]
    Client_Username = TestData["ClientDetails"]["Client_Username"]
    Client_Password = TestData["ClientDetails"]["Client_Password"]

    print(f"Setting Azure subscriptionId: '{SubscriptionId}'..")
    ReturnStatus=os.system(f"az account set --subscription {SubscriptionId}")
    if ReturnStatus != 0:
        print(f"Failed to select azure subscription:'{SubscriptionId}'")
        print(f"Check SubscriptionId in {ConfigurationFile}. If that is the right one re-login \
            into azure account by executing 'az login'")
        print('Exiting...')
        return False
    else:
        print("Success!\n")

    NameTag = "perf-client-"+str(datetime.datetime.now().strftime("%y%m%d%H%M%S"))

    if Client_Resource_Group is None or Client_Resource_Group == "":
        Client_Resource_Group = f"{NameTag}-rg"
    

    # Checking given Resource Group exists or not
    if 'true' not in subprocess.check_output(f"az group exists --name {Client_Resource_Group}", \
        shell=True, encoding='utf8'):
        CreateResourceGroup(TestData)
    else:
        print(f"Using existing ResourceGroup '{Client_Resource_Group}' for the creation the of test client")
    
    if TestData["ClientDetails"]["Client_Hostname"] == "":
        TestData["ClientDetails"]["Client_Hostname"] = NameTag
    else:
        output=""
        try:
            # Checking given Resource Group exists or not
            output = subprocess.check_output(f"az vm show -g {Client_Resource_Group}  -n {TestData['ClientDetails']['Client_Hostname']}", shell=True, encoding='utf8')
        except:
            pass

        if TestData["ClientDetails"]["Client_Hostname"] in output:
            print(f"FATAL: There exists a VM with name '{TestData['ClientDetails']['Client_Hostname']}' in '{Client_Resource_Group}' and you asked to creat new VM with same name.")
            RollBack()

    CreateVirtualMachine(TestData)    
    print(TestData["ClientDetails"]["Client_Hostname"], TestData["ClientDetails"]["Client_FQDN"], \
        Client_VM_SKU, Client_Region, Client_Resource_Group)

    Client_FQDN = TestData["ClientDetails"]["Client_FQDN"]
    
    reTryTimes=6
    for reTry in range(0, reTryTimes):
        if ssh.check_connectivity (Client_FQDN, Client_Username, Client_Password):
            print("Connected!\n")
            break
        else:
            print(f"VM is not accessible at this point. Will re-try after 5 seconds..({reTry})")
            time.sleep(10)
    else:
        print(f"Failed to connect to created VM")
        return False

    return True

##-------------------------------------------------------------------
# Script starts from here
##--------------------------------------------------------------------

if __name__ == '__main__':
    ValidateAndFixParameters(EnvironmentData, TestData)
    ProvisionedResources={}
    Operation=TestData["Operation"]

    try:
        if Operation == 'create':
            if CreateClientVirtualMachine(EnvironmentData, TestData):
                print("Virtual machine created succesfully!")
            else:
                print("Failed to create Virtual machine!")
                RollBack()

        if Operation in ['update', 'create']:
            print("Updating the config")
            if UpdateConfig(EnvironmentData, TestData):
                print("Config updated succesfully!")
            else:
                print("Failed to update configuration!")
                RollBack()
        else:
            print(f"Invalid option Operation: '{Operation}'")
            RollBack()

    except Exception as ErrMsg :
        print("Exception: "+ str(ErrMsg))