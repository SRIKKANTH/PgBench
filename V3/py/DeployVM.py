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

try:
    import commands
except ImportError:
    import subprocess as commands

# Initial parameters
subscription_name=""
subscription_id=""
user = ""
password = ""
imageName = "UbuntuLTS"
region = "southcentralus"
instanceSize = "Standard_D2s_v3".lower()
resourceName = "perf"
existingRG = None
dateTimeString = str(datetime.datetime.now().strftime("%y%m%d%H%M%S"))
rgName = resourceName+"-rg-"+dateTimeString
VMName = str(resourceName+"-vm-"+dateTimeString)
fqdnName = resourceName.lower()+dateTimeString
vnetName = VMName+"-VNET"
subnetName = VMName+"-Subnet"
nsgName = VMName+"-NSG"
publicIpName = VMName+"-PublicIp"
nicName = VMName+"-NIC"

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

def CheckCMDStatus(status, message):
    print("Current Status: ")
    print(status)
    if (('true' in status) or ('Succeeded' in status) or ('running' in status)):
        print(f"{message} is SUCCESS.")
    else:
        print(f"{message} is FAILED.")

##-------------------------------------------------------------------
# Script starts from here
##--------------------------------------------------------------------

if __name__ == '__main__':
    try:
        print(f"Setting Azure subscription: {subscription_name}..")
        ReturnStatus=os.system(f"az account set --subscription {subscription_id}")
        if ReturnStatus != 0:
            print(f"Failed to select azure subscription:'{subscription_id}'")
            print('Exiting...')
            exit(-1)
        else:
            print(f"Set Azure subcription ({subscription_name}) is Completed.")

        # Checking given Resource Group is exists or not
        if existingRG is not None:
            ReturnStatus=subprocess.check_output(f"az group exists --name {existingRG}", shell=True, encoding='utf8')
            if 'true' not in ReturnStatus:
                print(existingRG+" is not EXISTS")
                print("Creating new RG with name "+rgName+" in "+region)
                print(f'Creating Resource Group: {rgName}')
                ReturnStatus = subprocess.check_output(f"az group create --name {rgName} --location {region}", shell=True, encoding='utf8')
                ReturnStatusJson = json.loads(ReturnStatus)
                if 'Succeeded' != ReturnStatusJson["properties"]["provisioningState"]:
                    print(f"{rgName} is Failed")
                    exit(-1)
                else:
                    print(f"{rgName} is Completed")
            else:
                print(f"Using existing resource group {existingRG}")
                rgName = existingRG
        else:
            print("Creating new RG with name "+rgName+" in "+region)
            print(f'Creating Resource Group: {rgName}')
            ReturnStatus = subprocess.check_output(f"az group create --name {rgName} --location {region}", shell=True, encoding='utf8')
            ReturnStatusJson = json.loads(ReturnStatus)
            if 'Succeeded' != ReturnStatusJson["properties"]["provisioningState"]:
                print(f"{rgName} is Failed")
                exit(-1)
            else:
                print(f"{rgName} is Completed")

        # Create a virtual network.
        print(f"Creating VNET: {vnetName}")
        ReturnStatus = subprocess.check_output(f"az network vnet create --resource-group {rgName} --location {region} --name {vnetName} --subnet-name {subnetName}", shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)
        if 'Succeeded' != ReturnStatusJson["newVNet"]["subnets"][0]["provisioningState"]:
            print(f"{vnetName} is Failed")
            exit(-1)
        else:
            print(f"{vnetName} is Completed")

        # Create a public IP address.
        print(f"Creating Publlic IP: {publicIpName}")
        ReturnStatus = subprocess.check_output(f"az network public-ip create --resource-group {rgName} --location {region} --name {publicIpName} --allocation-method dynamic --dns-name {fqdnName}", shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)
        if 'Succeeded' != ReturnStatusJson["publicIp"]["provisioningState"]:
            print(f"{publicIpName} is Failed")
            exit(-1)
        else:
            print(f"{publicIpName} is Completed")
    
        # Create a network security group.
        print(f"Creating Network Security Group: {nsgName}")
        ReturnStatus = subprocess.check_output(f"az network nsg create --resource-group {rgName} --location {region} --name {nsgName}", shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)
        if 'Succeeded' != ReturnStatusJson["NewNSG"]["provisioningState"]:
            print(f"{nsgName} is Failed")
            exit(-1)
        else:
            print(f"{nsgName} is Completed")
        
        # Create a virtual network card and associate with public IP address and NSG.
        print(f"Creating NIC: {nicName}")
        ReturnStatus = subprocess.check_output(f"az network nic create --resource-group {rgName} --location {region} --name {nicName} --vnet-name {vnetName} --subnet {subnetName} --network-security-group {nsgName} --public-ip-address {publicIpName}", shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)
        if 'Succeeded' != ReturnStatusJson["NewNIC"]["provisioningState"]:
            print(f"{nicName} is Failed")
            exit(-1)
        else:
            print(f"{nicName} is Completed")
        
        # Create a new virtual machine.
        print(f"Creating Virtual Machine: {VMName}")
        ReturnStatus = subprocess.check_output(f"az vm create --resource-group {rgName} --location {region} --name {VMName} --nics {nicName} --image {imageName} --size {instanceSize} --admin-username {user} --admin-password {password}", shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)
        if 'VM running' != ReturnStatusJson["powerState"]:
            print(f"{VMName} is Failed")
            exit(-1)
        else:
            print(f"{VMName} is Completed")

        #Open port 22 to allow SSh traffic to host.
        print(f"Enabling SSH port 22 for VM: {VMName}")
        ReturnStatus = subprocess.check_output(f'az network nsg rule create --nsg-name {nsgName} --resource-group {rgName} -n {nsgName}-SSH --direction Inbound --priority 900 --access Allow --source-address-prefixes * --source-port-ranges * --destination-address-prefixes * --destination-port-ranges 22 --protocol tcp', shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)
        if 'Succeeded' != ReturnStatusJson["provisioningState"]:
            print(f"Enabling SSH port 22 for {VMName} is Failed")
            exit(-1)
        else:
            print(f"Enabling SSH prot 22 for {VMName} is Completed")
                
        # Collect VM details
        print("Collecting VM details..")
        instanceSize = subprocess.check_output(f"az vm show -g {rgName} -n {VMName} --query hardwareProfile -d --out tsv", shell=True, encoding='utf8').strip()
        PublicIp = subprocess.check_output(f"az vm show -g {rgName} -n {VMName} --query publicIps -d --out tsv", shell=True, encoding='utf8').strip()
        PrivateIp = subprocess.check_output(f"az vm show -g {rgName} -n {VMName} --query publicIps -d --out tsv", shell=True, encoding='utf8').strip()
        fqdnName = subprocess.check_output(f"az vm show -g {rgName} -n {VMName} --query fqdns -d --out tsv", shell=True, encoding='utf8').strip()
        print(VMName, fqdnName, instanceSize, region, rgName, PublicIp, user, password)
    except Exception as ErrMsg :
        print("Exception: "+ str(ErrMsg))