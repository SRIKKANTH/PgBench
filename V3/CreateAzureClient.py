ResourceGroupName="srm-pfs18"
az group create --name $ResourceGroupName --location westeurope
$ResourceGroupName="srm-pfs18"

$VmName="srm-test-vm"
$VMPassword=""
$VMSize='Standard_DS4_v2'
$VMUserName=''

az vm create --resource-group $ResourceGroupName     --name $VmName     --image UbuntuLTS    --admin-username $VMUserName     --admin-password $VMPassword     --size $VMSize     --use-unmanaged-disk     --storage-sku Standard_LRS

az resource list -g $ResourceGroupName -o table
az vm open-port --port 22 --resource-group $ResourceGroupName --name $VmName


az vm show -d -g $ResourceGroupName -n $VmName --query "publicIps" -o tsv
