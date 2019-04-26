import os
import socket
import sys
import traceback
import paramiko

# setup logging
paramiko.util.log_to_file("ssh.log")
# Paramiko client configuration
UseGSSAPI = (
    paramiko.GSS_AUTH_AVAILABLE
)  # enable "gssapi-with-mic" authentication, if supported by your python installation
DoGSSAPIKeyExchange = (
    paramiko.GSS_AUTH_AVAILABLE
)  # enable "gssapi-kex" key exchange, if supported by your python installation
# UseGSSAPI = False
# DoGSSAPIKeyExchange = False

def ssh_exec_cmd (hostname,username,password,command,port = 22):
    # now, connect and use paramiko Client to negotiate SSH2 across the connection
    try:
        client = paramiko.SSHClient()
        client.load_system_host_keys()
        client.set_missing_host_key_policy(paramiko.WarningPolicy())
        print("*** Connecting...")
        if not UseGSSAPI and not DoGSSAPIKeyExchange:
            client.connect(hostname, port, username, password)
        else:
            try:
                client.connect(
                    hostname,
                    port,
                    username,
                    gss_auth=UseGSSAPI,
                    gss_kex=DoGSSAPIKeyExchange,
                )
            except Exception:
                print("*** Caught exception: %s: %s" % (e.__class__, e))
                traceback.print_exc()
                sys.exit(1)

        client.exec_command(command)
        client.close()

    except Exception as e:
        print("*** Caught exception: %s: %s" % (e.__class__, e))
        traceback.print_exc()
        try:
            client.close()
        except:
            pass
        sys.exit(1)

def do_sftp (hostname,username,password,srcfilename,dstfilename=None,operation='put',Port=22):
    if srcfilename == None or operation not in ['put', 'get']:
        print ('Error: Invalid parameters passed!')
        return False

    # get host key, if we know one
    hostkeytype = None
    hostkey = None
    try:
        host_keys = paramiko.util.load_host_keys(
            os.path.expanduser("~/.ssh/known_hosts")
        )
    except IOError:
        try:
            # try ~/ssh/ too, because windows can't have a folder named ~/.ssh/
            host_keys = paramiko.util.load_host_keys(
                os.path.expanduser("~/ssh/known_hosts")
            )
        except IOError:
            print("*** Unable to open host keys file")
            host_keys = {}

    if hostname in host_keys:
        hostkeytype = host_keys[hostname].keys()[0]
        hostkey = host_keys[hostname][hostkeytype]
        print("Using host key of type %s" % hostkeytype)

    # now, connect and use paramiko Transport to negotiate SSH2 across the connection
    try:
        t = paramiko.Transport((hostname, Port))
        t.connect(
            hostkey,
            username,
            password,
            gss_host=socket.getfqdn(hostname),
            gss_auth=UseGSSAPI,
            gss_kex=DoGSSAPIKeyExchange,
        )
        sftp = paramiko.SFTPClient.from_transport(t)
        if dstfilename == None:
            dstfilename = srcfilename

        if operation == 'put':
            sftp.put(srcfilename, dstfilename)
        else:
            sftp.get(srcfilename, dstfilename)

        t.close()

    except Exception as e:
        print("*** Caught exception: %s: %s" % (e.__class__, e))
        traceback.print_exc()
        try:
            t.close()
        except:
            pass
        sys.exit(1)
    return True

if __name__ == '__main__':
##########
    hostname = ''
    username = ''
    password = ''

    ssh_exec_cmd(hostname,username,password,'ifconfig>ifconfig.log')
    do_sftp (hostname,username,password,srcfilename='ifconfig.file',operation='get',Port=22)
