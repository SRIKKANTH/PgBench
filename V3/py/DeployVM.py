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
import SshPython

try:
    import commands
except ImportError:
    import subprocess as commands

# Initialise parameters
with open('./Environment.json') as EnvironmentFile:  
    EnvironmentData = json.load(EnvironmentFile)
    SubscriptionName=EnvironmentData["SubscriptionName"]
    SubscriptionId=EnvironmentData["SubscriptionId"]
    ResourceGroupName=EnvironmentData["ResourceGroupName"]
    Region = EnvironmentData["Region"]
    InstanceSize = EnvironmentData["InstanceSize"].lower()
    VirtualMachineName = EnvironmentData["VirtualMachineName"]
    Username = EnvironmentData["Username"]
    Password = EnvironmentData["Password"]
    OSImage = EnvironmentData["OSImage"]
    Password = EnvironmentData["Password"]

dateTimeString = str(datetime.datetime.now().strftime("%y%m%d%H%M%S"))

NameTag = "perf-client"

# Get VM Name if 
if VirtualMachineName is None or VirtualMachineName == "":
    VirtualMachineName = f"{NameTag}-{dateTimeString}"

if InstanceSize is None or InstanceSize == "":
    InstanceSize = "Standard_D4s_v3".lower()

if ResourceGroupName is None or ResourceGroupName == "":
    ResourceGroupName = f"{NameTag}-rg-{dateTimeString}"

if OSImage is None or OSImage == "":
    OSImage = "UbuntuLTS"


# This Log will collect all the logs that are run while the Test is going on...
RunLog = logging.getLogger("RuntimeLog : ")
WRunLog = logging.FileHandler('Runtime.log','w')
RunFormatter = logging.Formatter('%(asctime)s : %(levelname)s : %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
WRunLog.setFormatter(RunFormatter)
RunLog.setLevel(logging.DEBUG)
RunScreen = logging.StreamHandler()
RunScreen.setFormatter(RunFormatter)
RunLog.addHandler(WRunLog)

def Log(text,fp):
    print(text.strip())
    fp.write(text)

def CreateResourceGroup(ResourceGroupName, Region):
    print(f"Creating new ResourceGroupName {ResourceGroupName} in {Region}")
    ReturnStatus = subprocess.check_output(f"az group create --name {ResourceGroupName} --location {Region}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["properties"]["provisioningState"]:
        print(f"FATAL: Failed")
        exit(-1)
    else:
        print(f"Success")
            
def CreateVirtualMachine(VirtualMachineName):
    FqdnName = VirtualMachineName.lower()
    VnetName = VirtualMachineName+"-vnet"
    SubnetName = VirtualMachineName+"-subnet"
    NsgName = VirtualMachineName+"-nsg"
    PublicIpName = VirtualMachineName+"-pip"
    NicName = VirtualMachineName+"-nic"

    # Create a virtual network.
    print(f"Creating VNET: {VnetName}")
    ReturnStatus = subprocess.check_output(f"az network vnet create --resource-group {ResourceGroupName} --location {Region} --name {VnetName} --subnet-name {SubnetName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["newVNet"]["subnets"][0]["provisioningState"]:
        print(f"FATAL: Failed")
        exit(-1)
    else:
        print(f"Success")

    # Create a public IP address.
    print(f"Creating Publlic IP: {PublicIpName}")
    ReturnStatus = subprocess.check_output(f"az network public-ip create --resource-group {ResourceGroupName} --location {Region} --name {PublicIpName} --allocation-method dynamic --dns-name {FqdnName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["publicIp"]["provisioningState"]:
        print(f"FATAL: Failed")
        exit(-1)
    else:
        print(f"Success")

    # Create a network security group.
    print(f"Creating Network Security Group: {NsgName}")
    ReturnStatus = subprocess.check_output(f"az network nsg create --resource-group {ResourceGroupName} --location {Region} --name {NsgName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["NewNSG"]["provisioningState"]:
        print(f"FATAL: Failed")
        exit(-1)
    else:
        print(f"Success")
    
    # Create a virtual network card and associate with public IP address and NSG.
    print(f"Creating NIC: {NicName}")
    ReturnStatus = subprocess.check_output(f"az network nic create --resource-group {ResourceGroupName} --location {Region} --name {NicName} --vnet-name {VnetName} --subnet {SubnetName} --network-security-group {NsgName} --public-ip-address {PublicIpName}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["NewNIC"]["provisioningState"]:
        print(f"FATAL: Failed!")
        exit(-1)
    else:
        print(f"Success")
    
    # Create a new virtual machine.
    print(f"Creating Virtual Machine: {VirtualMachineName}")
    ReturnStatus = subprocess.check_output(f"az vm create --resource-group {ResourceGroupName} --location {Region} --name {VirtualMachineName} --nics {NicName} --image {OSImage} --size {InstanceSize} --admin-username {Username} --admin-password {Password}", shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'VM running' != ReturnStatusJson["powerState"]:
        print(f"{VirtualMachineName} is Failed")
        exit(-1)
    else:
        print(f"Success")

    #Open port 22 to allow SSh traffic to host.
    print(f"Enabling SSH port 22 for VM: {VirtualMachineName}")
    ReturnStatus = subprocess.check_output(f'az network nsg rule create --nsg-name {NsgName} --resource-group {ResourceGroupName} -n {NsgName}-SSH --direction Inbound --priority 900 --access Allow --source-address-prefixes * --source-port-ranges * --destination-address-prefixes * --destination-port-ranges 22 --protocol tcp', shell=True, encoding='utf8')
    ReturnStatusJson = json.loads(ReturnStatus)
    if 'Succeeded' != ReturnStatusJson["provisioningState"]:
        print(f"Enabling SSH port 22 for {VirtualMachineName} is Failed")
        exit(-1)
    else:
        print(f"Success")
    
    # Collect VM details
    VirtualMachineNameDetails={}
    print("Collecting VM details..")
    VirtualMachineNameDetails["PublicIp"] = subprocess.check_output(f"az vm show -g {ResourceGroupName} -n {VirtualMachineName} --query publicIps -d --out tsv", shell=True, encoding='utf8').strip()
    VirtualMachineNameDetails["PrivateIp"] = subprocess.check_output(f"az vm show -g {ResourceGroupName} -n {VirtualMachineName} --query publicIps -d --out tsv", shell=True, encoding='utf8').strip()
    VirtualMachineNameDetails["FqdnName"] = subprocess.check_output(f"az vm show -g {ResourceGroupName} -n {VirtualMachineName} --query fqdns -d --out tsv", shell=True, encoding='utf8').strip()
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
        if 'true' not in subprocess.check_output(f"az group exists --name {ResourceGroupName}", shell=True, encoding='utf8'):
            CreateResourceGroup(ResourceGroupName, Region)
        else:
            print(f"Using ResourceGroup '{ResourceGroupName}' for the creation the of Virtual Machine '{VirtualMachineName}'")

        VirtualMachineNameDetail=CreateVirtualMachine(VirtualMachineName)
        print(VirtualMachineName, VirtualMachineNameDetail["FqdnName"], InstanceSize, Region, ResourceGroupName, VirtualMachineNameDetail["PublicIp"], Username, Password)
        #SshPython.ssh_exec_cmd(VirtualMachineNameDetail["FqdnName"],Username,Password,'ifconfig>ifconfig.log')
        #SshPython.do_sftp (VirtualMachineNameDetail["FqdnName"],Username,Password,srcfilename='ifconfig.file',operation='get',Port=22)

    except Exception as ErrMsg :
        print("Exception: "+ str(ErrMsg))