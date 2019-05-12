import os
import json
import socket
import sys
import traceback
import paramiko
import ntpath

# setup logging
paramiko.util.log_to_file("ssh.log")

def exec_cmd (hostname,username,password,command,port=22):
    response=''
    # now, connect and use paramiko Client to negotiate SSH2 across the connection
    try:
        ssh=paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname,port,username,password)
        print(f"Executing '{command}' on '{hostname}'")
        stdin,stdout,stderr=ssh.exec_command(command)
        outlines=stdout.readlines()
        response=''.join(outlines)
    except Exception as e:
        pass
        #traceback.print_exc()
        try:
            client.close()
        except:
            pass

    return(response)

def do_sftp (hostname,username,password,srcfilename,dstfilename=None,operation='put',port=22):
    if srcfilename == None or operation not in ['put', 'get']:
        print ('Error: Invalid parameters passed!')
        return False

    # Now, connect and use paramiko Transport to negotiate SSH2 across the connection
    try:
        transport = paramiko.Transport((hostname, port))
        transport.connect(username = username, password = password)
        sftp = paramiko.SFTPClient.from_transport(transport)

        if dstfilename == None:
            dstfilename = ntpath.basename(srcfilename)

        if operation == 'put':
            print(f"Uploading '{srcfilename}' to '{hostname}'")
            sftp.put(srcfilename, dstfilename)
        else:
            print(f"Downloading '{srcfilename}' from '{hostname}'")
            sftp.get(srcfilename, dstfilename)

        sftp.close()
        transport.close()

    except Exception as e:
        traceback.print_exc()
        try:
            transport.close()
        except:
            pass

    return True

def check_connectivity (hostname,username,password,port=22):
    responce = exec_cmd (hostname,username,password,'uname -a',port=22)
    if 'Linux' in responce:
        return(True)
    else:
        return(False)

if __name__ == '__main__':
    ConfigurationFile='./Environment.json'

    # Initialise parameters
    with open(ConfigurationFile) as EnvironmentFile:  
        EnvironmentData = json.load(EnvironmentFile)

        # Get Client Info
        SubscriptionId=EnvironmentData["ClientDetails"]["SubscriptionId"]
        Client_Hostname = EnvironmentData["ClientDetails"]["Client_Hostname"]
        Client_Region = EnvironmentData["ClientDetails"]["Client_Region"]
        Client_Resource_Group=EnvironmentData["ClientDetails"]["Client_Resource_Group"]
        Client_VM_SKU = EnvironmentData["ClientDetails"]["Client_VM_SKU"].lower()
        Client_Username = EnvironmentData["ClientDetails"]["Client_Username"]
        Client_Password = EnvironmentData["ClientDetails"]["Client_Password"]
        OSImage = EnvironmentData["ClientDetails"]["OSImage"]

    print(f"{Client_Username},{Client_Password}:")

    