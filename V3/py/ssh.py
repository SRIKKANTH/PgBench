import os
import json
import socket
import sys
import traceback
import paramiko
import ntpath


def exec_cmd (hostname,username,password,command,port=22):
    if hostname == None or username == None or password == None or command == None:
        print("Invalid args passed")
        return False   
    elif hostname == "" or username == "" or password == "" or command == "":
        print("Invalid args passed")
        return False

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
    except Exception:
        pass
        
        try:
            client.close()
        except:
            pass

    return(response)

def do_sftp (hostname,username,password,srcfilename,dstfilename=None,operation='put',port=22):
    if hostname == None or username == None or password == None or srcfilename == None:
        print("Invalid args passed")
        return False   
    elif hostname == "" or username == "" or password == "" or srcfilename == "" or (operation not in ['put', 'get']):
        print("Invalid args passed")
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

    except Exception:
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
