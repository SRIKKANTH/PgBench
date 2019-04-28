import os
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
        traceback.print_exc()
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

if __name__ == '__main__':
    ClientFqdn = ''
    Username = ''
    Password = '!@#'
    
    files=["CommonRoutines.sh", "RunTest.sh", "SendHeartBeat.sh", "pbenchTest.sh", "pgBenchParser.sh","ConnectionProperties.csv", "pgbenchSetupScript.sh"]
    
    for file in files:
        do_sftp(ClientFqdn,Username,Password,srcfilename=f'sh\{file}',operation='put')

    exec_cmd(ClientFqdn,Username,Password,"sudo apt-get update; sudo apt install -y  dos2unix;dos2unix *.sh ;chmod +x *.sh;bash pgbenchSetupScript.sh>pgbenchSetupScript.log")

    do_sftp(ClientFqdn,Username,Password,srcfilename='pgbenchSetupScript.log',operation='get')

    if 'performance_test_setup_success' in open('pgbenchSetupScript.log').read():
        print("performance_test_setup_success")
    else:
        print("Not found")