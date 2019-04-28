import json
import datetime
import subprocess
import logging
import string
import os
import time
import os.path
import array
import linecache
import sys
import re
import ssh

try:
    import commands
except ImportError:
    import subprocess as commands

# Initialise parameters
with open('./Environment.json') as EnvironmentFile:  
    EnvironmentData = json.load(EnvironmentFile)
    SubscriptionName=EnvironmentData["SubscriptionName"]
    SubscriptionId=EnvironmentData["SubscriptionId"]
    
    # Get Client Info
    Client_Hostname = EnvironmentData["Client_Hostname"]
    Client_Region = EnvironmentData["Client_Region"]
    Client_Resource_Group=EnvironmentData["Client_Resource_Group"]
    Client_VM_SKU = EnvironmentData["Client_VM_SKU"].lower()
    Client_Username = EnvironmentData["Client_Username"]
    Client_Password = EnvironmentData["Client_Password"]
    OSImage = EnvironmentData["OSImage"]

    # Get Server Info
    Test_Server_fqdn = EnvironmentData["ServerDetails"]["Test_Server_fqdn"]
    Test_Server_Region = EnvironmentData["ServerDetails"]["Test_Server_Region"]
    Test_Server_Environment = EnvironmentData["ServerDetails"]["Test_Server_Environment"] # It should be 'Stage' or 'Prod' or 'Orcas' ; Orcas -> Current Azure PG PaaS or Sterling PG
    Test_Server_Server_Edition = EnvironmentData["ServerDetails"]["Test_Server_Server_Edition"]
    Test_Server_CPU_Cores = EnvironmentData["ServerDetails"]["Test_Server_CPU_Cores"]
    Test_Server_Storage_In_MB = EnvironmentData["ServerDetails"]["Test_Server_Storage_In_MB"]
    Test_Server_Username = EnvironmentData["ServerDetails"]["Test_Server_Username"]
    Test_Server_Password = EnvironmentData["ServerDetails"]["Test_Server_Password"]
    Test_Database_Type = EnvironmentData["ServerDetails"]["Test_Database_Type"]
    Test_Database_Name = EnvironmentData["ServerDetails"]["Test_Database_Name"]

    # Get Logs/Results DB Info
    LogsDbServer = EnvironmentData["LogsDBConfig"]["LogsDbServer"]
    LogsDbServerUsername = EnvironmentData["LogsDBConfig"]["LogsDbServerUsername"]
    LogsDbServerPassword = EnvironmentData["LogsDBConfig"]["LogsDbServerPassword"]
    LogsDataBase = EnvironmentData["LogsDBConfig"]["LogsDataBase"]
    LogsTableName = EnvironmentData["LogsDBConfig"]["LogsTableName"]
    ResourceHealthTableName = EnvironmentData["LogsDBConfig"]["ResourceHealthTableName"]
    ServerInfoTableName = EnvironmentData["LogsDBConfig"]["ServerInfoTableName"]
    ClientInfoTableName = EnvironmentData["LogsDBConfig"]["ClientInfoTableName"]
    ScheduledTestsTable = EnvironmentData["LogsDBConfig"]["ScheduledTestsTable"]

    # Get Test Info
    Test_Parameters_script = EnvironmentData["TestConfig"]["Test_Parameters_script"]


dateTimeString = str(datetime.datetime.now().strftime("%y%m%d%H%M%S"))

NameTag = "perf-client"

# Get VM Name if 
if Client_Hostname is None or Client_Hostname == "":
    Client_Hostname = f"{NameTag}-{dateTimeString}"

if Client_VM_SKU is None or Client_VM_SKU == "":
    Client_VM_SKU = "Standard_D4s_v3".lower()

if Client_Resource_Group is None or Client_Resource_Group == "":
    Client_Resource_Group = f"{NameTag}-rg-{dateTimeString}"

if OSImage is None or OSImage == "":
    OSImage = "UbuntuLTS"

def CreateResourceGroup(Client_Resource_Group, Client_Region):
    print(f"Creating new Client_Resource_Group {Client_Resource_Group} in {Client_Region}")
    ReturnStatus = subprocess.check_output(f"az group create --name {Client_Resource_Group} --location {Client_Region}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["properties"]["provisioningState"]:
        print(f"FATAL: Failed")
        exit(-1)
    else:
        print(f"Success")

def RollBack():
    print(f"FATAL: Occured unrecovered failure. Trying to roll back changes and exit.")
    exit(-1)

def CreateVirtualMachine(Client_Hostname):
    FqdnName = Client_Hostname.lower()
    VnetName = Client_Hostname+"-vnet"
    SubnetName = Client_Hostname+"-subnet"
    NsgName = Client_Hostname+"-nsg"
    PublicIpName = Client_Hostname+"-pip"
    NicName = Client_Hostname+"-nic"

    # Create a virtual network.
    print(f"Creating VNET: {VnetName}")
    ReturnStatus = subprocess.check_output(f"az network vnet create --resource-group {Client_Resource_Group} --location {Client_Region} --name {VnetName} --subnet-name {SubnetName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["newVNet"]["subnets"][0]["provisioningState"]:
        print(f"FATAL: Failed to create SubnetName: {SubnetName}")
        RollBack()
    else:
        print(f"Success")

    # Create a public IP address.
    print(f"Creating Publlic IP: {PublicIpName}")
    ReturnStatus = subprocess.check_output(f"az network public-ip create --resource-group {Client_Resource_Group} --location {Client_Region} --name {PublicIpName} --allocation-method dynamic --dns-name {FqdnName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["publicIp"]["provisioningState"]:
        print(f"FATAL: Failed to create PublicIp: {PublicIpName}")
        RollBack()
    else:
        print(f"Success")

    # Create a network security group.
    print(f"Creating Network Security Group: {NsgName}")
    ReturnStatus = subprocess.check_output(f"az network nsg create --resource-group {Client_Resource_Group} --location {Client_Region} --name {NsgName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["NewNSG"]["provisioningState"]:
        print(f"FATAL: Failed to create NSG: {NsgName}")
        RollBack()
    else:
        print(f"Success")
    
    # Create a virtual network card and associate with public IP address and NSG.
    print(f"Creating NIC: {NicName}")
    ReturnStatus = subprocess.check_output(f"az network nic create --resource-group {Client_Resource_Group} --location {Client_Region} --name {NicName} --vnet-name {VnetName} --subnet {SubnetName} --network-security-group {NsgName} --public-ip-address {PublicIpName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["NewNIC"]["provisioningState"]:
        print(f"FATAL: Failed to create NIC: {NicName}")
        RollBack()
    else:
        print(f"Success")
    
    # Create a new virtual machine.
    print(f"Creating Virtual Machine: {Client_Hostname}")
    ReturnStatus = subprocess.check_output(f"az vm create --resource-group {Client_Resource_Group} --location {Client_Region} --name {Client_Hostname} --nics {NicName} --image {OSImage} --size {Client_VM_SKU} --admin-username {Client_Hostname} --admin-password {Client_Password}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'VM running' != ReturnStatusJson["powerState"]:
        print(f"FATAL: Failed to create virtual machine: {Client_Hostname}")
        RollBack()
    else:
        print(f"Success")

    #Open port 22 to allow SSh traffic to host.
    print(f"Enabling SSH port 22 for VM: {Client_Hostname}")
    ReturnStatus = subprocess.check_output(f'az network nsg rule create --nsg-name {NsgName} --resource-group {Client_Resource_Group} -n {NsgName}-SSH --direction Inbound --priority 900 --access Allow --source-address-prefixes * --source-port-ranges * --destination-address-prefixes * --destination-port-ranges 22 --protocol tcp', shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["provisioningState"]:
        print(f"Enabling SSH port 22 for {Client_Hostname} is Failed")
        RollBack()
    else:
        print(f"Success")
    
    # Collect VM details
    VirtualMachineNameDetails={}
    print("Collecting VM details..")
    VirtualMachineNameDetails["PublicIp"] = subprocess.check_output(f"az vm show -g {Client_Resource_Group} -n {Client_Hostname} --query publicIps -d --out tsv", shell=True, encoding='utf8').strip()
    VirtualMachineNameDetails["PrivateIp"] = subprocess.check_output(f"az vm show -g {Client_Resource_Group} -n {Client_Hostname} --query publicIps -d --out tsv", shell=True, encoding='utf8').strip()
    VirtualMachineNameDetails["FqdnName"] = subprocess.check_output(f"az vm show -g {Client_Resource_Group} -n {Client_Hostname} --query fqdns -d --out tsv", shell=True, encoding='utf8').strip()
    return (VirtualMachineNameDetails)

##-------------------------------------------------------------------
# Script starts from here
##--------------------------------------------------------------------

if __name__ == '__main__':
    try:
        print(f"Setting Azure subscription: '{SubscriptionName}'..")
        ReturnStatus=os.system(f"az account set --subscription {SubscriptionId}")
        if ReturnStatus != 0:
            print(f"Failed to select azure subscription:'{SubscriptionId}'")
            print('Exiting...')
            exit(-1)
        else:
            print("Success")

        # Checking given Resource Group is exists or not
        if 'true' not in subprocess.check_output(f"az group exists --name {Client_Resource_Group}", shell=True, encoding='utf8'):
            CreateResourceGroup(Client_Resource_Group, Client_Region)
        else:
            print(f"Using existing ResourceGroup '{Client_Resource_Group}' for the creation the of Virtual Machine '{Client_Hostname}'")

        VirtualMachineNameDetail=CreateVirtualMachine(Client_Hostname)
        print(Client_Hostname, VirtualMachineNameDetail["FqdnName"], Client_VM_SKU, Client_Region, Client_Resource_Group, VirtualMachineNameDetail["PublicIp"], Client_Hostname, Client_Password)
        ClientFqdn=VirtualMachineNameDetail["FqdnName"]
        
        files=["CommonRoutines.sh", "RunTest.sh", "SendHeartBeat.sh", "pbenchTest.sh", "pgBenchParser.sh","ConnectionProperties.csv", "pgbenchSetupScript.sh"]
        
        for file in files:
            ssh.do_sftp(ClientFqdn,Client_Hostname,Client_Password,srcfilename=f'sh\{file}',operation='put')

        ssh.exec_cmd(ClientFqdn,Client_Hostname,Client_Password,"sudo apt-get update; sudo apt install -y  dos2unix;dos2unix *.sh ;chmod +x *.sh;bash pgbenchSetupScript.sh>pgbenchSetupScript.log")

        ssh.do_sftp(ClientFqdn,Client_Hostname,Client_Password,srcfilename='pgbenchSetupScript.log',operation='get')

        if 'performance_test_setup_success' in open('pgbenchSetupScript.log').read():
            print("performance_test_setup_success")
        else:
            print("Performance test setup Failed")

    except Exception as ErrMsg :
        print("Exception: "+ str(ErrMsg))