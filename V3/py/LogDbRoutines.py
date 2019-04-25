import psycopg2

def update_server_info(Test_Server, Test_Server_Region, Test_Server_Environment, Test_Database_Type, vCores, Storage_In_MB, Test_Server_Username, Test_Server_Password, Test_Database_Name="", Server_Last_HeartBeat='1900-01-01 00:00:00'):
    PG_Query=f"""INSERT INTO {ServerInfoTableName} ( \
    Test_Server,  \
    Server_Last_HeartBeat,  \
    Test_Server_Region,  \
    Test_Server_Environment,  \
    Test_Database_Type,  \
    vCores,  \
    Storage_In_MB,  \
    Test_Server_Username,  \
    Test_Server_Password,  \
    Test_Database_Name  \
    ) VALUES ( \
        '{Test_Server}', \
        '{Server_Last_HeartBeat}', \
        '{Test_Server_Region}', \
        '{Test_Server_Environment}', \
        '{Test_Database_Type}', \
         {vCores}, \
         {Storage_In_MB}, \
        '{Test_Server_Username}',  \
        '{Test_Server_Password}',  \
        '{Test_Database_Name}'  \
    );"""
    return (Run_SQL_Query(PG_Query=PG_Query))

def update_client_info(Client_Hostname, Client_Region, Client_Resource_Group, Client_SKU, Client_Username, Client_Password, Client_FQDN,Client_Last_HeartBeat='1900-01-01 00:00:00', Test_Server_Assigned="None"):
    PG_Query=f"""INSERT INTO {ClientInfoTableName} ( \
        Client_Hostname,  \
        Client_Last_HeartBeat,  \
        Test_Server_Assigned,  \
        Client_Region,  \
        Client_Resource_Group,  \
        Client_SKU,  \
        Client_Username,  \
        Client_Password,  \
        Client_FQDN \
    ) VALUES ( \
        '{Client_Hostname}', \
        '{Client_Last_HeartBeat}', \
        '{Test_Server_Assigned}',  \
        '{Client_Region}',  \
        '{Client_Resource_Group}',  \
        '{Client_SKU}',  \
        '{Client_Username}',  \
        '{Client_Password}',  \
        '{Client_FQDN}' \
    );"""

    return (Run_SQL_Query(DbServer=LogsDbServer,DataBase=LogsDataBase,DbServerUsername=LogsDbServerUsername,DbServerPassword=LogsDbServerPassword,PG_Query=PG_Query))

#def Run_SQL_Query(DbServer,DataBase,DbServerUsername,DbServerPassword,):
def Run_SQL_Query(PG_Query,DbServer=LogsDbServer,DataBase=LogsDataBase,DbServerUsername=LogsDbServerUsername,DbServerPassword=LogsDbServerPassword):
    try:
        conn = psycopg2.connect(f"dbname='{DataBase}' user='{DbServerUsername}' host='{DbServer}' password='{DbServerPassword}'")
    except:
        print (f"I am unable to connect to the database:'{DbServer}'")

    cur = conn.cursor()
    try:
        cur.execute(PG_Query)
        print('Success')
    except:
        print (f"Failed to execute sql query: {PG_Query}")

    conn.commit()
    cur.close()
    return (True)

#-------------------------------------------------------------------
# Script starts from here
#--------------------------------------------------------------------

if __name__ == '__main__':
    Client_Hostname="QuadrantLinuxDesktop_2"
    Client_Last_HeartBeat='1900-01-01 00:00:00'
    Test_Server_Assigned="OB-longterm"
    Client_Region="southeastasia"
    Client_Resource_Group="longhaul-perf-clients"
    Client_SKU="Standard_D4s_v3"
    Client_Username="cloud"
    Client_Password="admin"
    Client_FQDN="QuadrantLinuxDesktop_2.southeastasia.cloudapp.azure.com"
    #--
    LogsDbServer="longhaulperfdb"
    LogsDbServerUsername="cloudsa@longhaulperfdb"
    LogsDbServerPassword="pgadmin"
    LogsDataBase="postgres"
    LogsTableName="pgbenchperf"
    ResourceHealthTableName="ResourceHealth"
    ServerInfoTableName="Server_Info"
    ClientInfoTableName="Client_info"
    TestType="pgbench"
    TestDatabaseType="postgres"
    #--
    Test_Server=LogsDbServer
    Server_Last_HeartBeat='1900-01-01 00:00:00'
    Test_Server_Region=Client_Region
    Test_Server_Environment='prod'
    Test_Database_Type=TestDatabaseType
    vCores=1024
    Storage_In_MB=1020202
    Test_Server_Username=Client_Username
    Test_Server_Password=Client_Password
    Test_Database_Name=TestDatabaseType

    print(f"Inserting new client details into ClientInfoTableName: {ClientInfoTableName}")
    update_client_info(Client_Hostname, Client_Region, Client_Resource_Group, Client_SKU, Client_Username, Client_Password, Client_FQDN)

    print(f"Inserting new client details into ServerInfoTableName: {ServerInfoTableName}")
    update_server_info(Test_Server,Test_Server_Region,Test_Server_Environment,Test_Database_Type,vCores,Storage_In_MB,Test_Server_Username,Test_Server_Password,Test_Database_Name)
