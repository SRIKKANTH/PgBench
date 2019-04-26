import subprocess
ResourceGroupName="srm-test-env"
#ReturnStatus=subprocess.check_output(f"az group exists --name {ResourceGroupName}", shell=True, encoding='utf8')
if 'true' in subprocess.check_output(f"az group exists --name {ResourceGroupName}", shell=True, encoding='utf8'):
    print("Exists")
else:
    print("It Doesn't")
