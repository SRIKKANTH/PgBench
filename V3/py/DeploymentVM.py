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
region = "centralus"
instanceSize = "Standard_D2s_v3"
resourceName = "orcasbreadth-vteam"
dateTimeString = str(datetime.datetime.now().strftime("%Y%m%d%H%M%S"))
rgName = resourceName+"-rg"
VMName = str(resourceName+"-vm-01")
fqdnName = re.sub('\W+','', VMName.lower())
vnetName = ""
subnetName = ""
nsgName = ""
publicIpName = ""
nicName = ""

#THIS LOG WILL COLLECT ALL THE LOGS THAT ARE RUN WHILE THE TEST IS GOING ON...
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
        print('"'+message+'" is SUCCESS.')
    else:
        print('"'+message+'" is FAILED.')

##
#-------------------------------------------------------------------
# Script starts from here
#--------------------------------------------------------------------

if __name__ == '__main__':
    try:
        print(f"Setting Azure subscription: '{subscription_name}'..")
        ReturnStatus=os.system(f"az account set --subscription {subscription_id}")
        if ReturnStatus != 0:
            print(f"Failed to select azure subscription:'{subscription_id}'")
            print('Exiting...')
            exit(-1)
        else:
            print("Checking is RG exists "+rgName)
        
        
        ReturnStatus=subprocess.check_output(f"az group exists --name {rgName}s", shell=True, encoding='utf8')

        if 'true' not in ReturnStatus:
            print(rgName+" is not EXISTS")
            rgName = rgName+"-"+dateTimeString
            print("Creating new RG with name "+rgName+" in "+region)
            print('"'+rgName+'" creation is RUNNING..')
            rgStatus = subprocess.check_output('az group create --name "'+rgName+'" --location "'+region+'"', shell=True, encoding='utf8')
            CheckCMDStatus(rgStatus, "RG creation")
        else:
            print(f"Using existing resource group {rgName}")


        # Create a virtual network.
        vnetName = VMName+"-VNET"
        subnetName = VMName+"-Subnet"
        print(f"Creating VNET: {vnetName}")
        
        ReturnStatus=subprocess.check_output(f"az network vnet create --resource-group {rgName} --name {vnetName} --subnet-name {subnetName}", shell=True, encoding='utf8')
        ReturnStatusJson = json.loads(ReturnStatus)

        if 'Succeeded' not in ReturnStatusJson["newVNet"]["subnets"][0]["provisioningState"]:
            print(f"Failed")
        else:
            print('Done')
        
        
        
        
        vnetStatus = subprocess.check_output('az network vnet create --resource-group "'+rgName+'" --name "'+vnetName+'" --subnet-name "'+subnetName+'"', shell=True, encoding='utf8')
        CheckCMDStatus(vnetStatus, "VNET creation")
        
        # Create a public IP address.
        publicIpName = VMName+"-PublicIp"
        print('"'+publicIpName+'" creation is RUNNING..')
        publicIpStatus = subprocess.check_output('az network public-ip create --resource-group "'+rgName+'" --name "'+publicIpName+'" --allocation-method dynamic --dns-name "'+fqdnName+'"', shell=True, encoding='utf8')
        CheckCMDStatus(publicIpStatus, "PublicIP creation")
    
        # Create a network security group.
        nsgName = VMName+"-NSG"
        print('"'+nsgName+'" creation is RUNNING..')
        nsgStatus = subprocess.check_output('az network nsg create --resource-group "'+rgName+'" --name "'+nsgName+'"', shell=True, encoding='utf8')
        CheckCMDStatus(nsgStatus, "NSG creation")
        
        # Create a virtual network card and associate with public IP address and NSG.
        nicName = VMName+"-NIC"
        print('"'+nicName+'" creation is RUNNING..')
        nicStatus = subprocess.check_output('az network nic create --resource-group "'+rgName+'" --name "'+nicName+'" --vnet-name "'+vnetName+'" --subnet "'+subnetName+'" --network-security-group "'+nsgName+'" --public-ip-address "'+publicIpName+'"', shell=True, encoding='utf8')
        CheckCMDStatus(nicStatus, "NIC creation")
        
        # Create a new virtual machine.
        print('"'+VMName+'" creation is RUNNING..')
        VMStatus = subprocess.check_output('az vm create --resource-group "'+rgName+'" --name "'+VMName+'" --nics "'+nicName+'" --image "'+imageName+'" --size "'+instanceSize+'" --admin-username "'+user+'" --admin-password "'+password+'"', shell=True, encoding='utf8')
        CheckCMDStatus(VMStatus, "VM creation")

        #Open port 22 to allow SSh traffic to host.
        print('SSH port 22 enabling is RUNNING..')
        sshPortStatus = subprocess.check_output('az vm open-port --port 22 --resource-group "'+rgName+'" --name "'+VMName+'"', shell=True, encoding='utf8')
        CheckCMDStatus(sshPortStatus, "SSH port enable")
        
        # Collect VM details
        instanceSize = subprocess.check_output('az vm show -g "'+rgName+'" -n "'+VMName+'" --query hardwareProfile -d --out tsv', shell=True, encoding='utf8').strip()
        PublicIp = subprocess.check_output('az vm show -g "'+rgName+'" -n "'+VMName+'" --query publicIps -d --out tsv', shell=True, encoding='utf8').strip()
        PrivateIp = subprocess.check_output('az vm show -g "'+rgName+'" -n "'+VMName+'" --query publicIps -d --out tsv', shell=True, encoding='utf8').strip()
        fqdnName = subprocess.check_output('az vm show -g "'+rgName+'" -n "'+VMName+'" --query fqdns -d --out tsv', shell=True, encoding='utf8').strip()

        print(PublicIp)
        # print(Str(PublicIp).rstrip())
        print(fqdnName)
        
        f = open("AzureVMDeploymentInfo.csv", "w")
        Log("VMName,FQDNName,InstanceSize,RGName,Region,PublicIp\n",f)
        string="{},{},{},{},{},{}\n".format(VMName, fqdnName, instanceSize, rgName, region, PublicIp)
        Log(string,f)
        f.close()
        print("Check this file AzureVMDeploymentInfo.csv for VM details")
    except Exception as ErrMsg :
        print("Exception: "+ str(ErrMsg))