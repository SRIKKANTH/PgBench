import psycopg2
import psycopg2.extras
import json

'''
Table defs:
CREATE TABLE Client_info
(
    Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
    Client_Last_HeartBeat timestamp,
    Test_Server_Assigned VARCHAR(100),
    Client_Region VARCHAR(25),
    Client_Resource_Group VARCHAR(25),
    Client_VM_SKU VARCHAR(25),
    Client_Username VARCHAR(25),
    Client_Password VARCHAR(25),
    Client_FQDN VARCHAR(100)
);

CREATE TABLE Server_Info
(
    Test_Server_fqdn VARCHAR(100) NOT NULL PRIMARY KEY, 
    Server_Last_HeartBeat timestamp,
    Test_Server_Region VARCHAR(25),
    Test_Server_Environment VARCHAR(25),
    Test_Server_Server_Edition VARCHAR(25),
    Test_Server_CPU_Cores INT,
    Test_Server_Storage_In_MB INT,
    Test_Server_Username VARCHAR(25),
    Test_Server_Password VARCHAR(25),
    Test_Database_Type  VARCHAR(25),
    Test_Database_Topology  VARCHAR(25),
    Test_Database_Name VARCHAR(25)
);

CREATE TABLE Scheduled_tests
(
    Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
    Test_Server VARCHAR(100),
    Test_Parameters_script  VARCHAR(1000) NOT NULL
);
'''

def InsertServerInfoIntoDb (EnvironmentData, TestData):
    print(f"Trying to InsertServerInfoIntoDb")

    if TestData['ServerDetails']['Test_Server_fqdn'] == None:
        print(f"Invalid Client_Hostname") 
        return False

    if TestData['ServerDetails']['Test_Server_fqdn'] == "":
        print(f"Invalid Client_Hostname") 
        return False

    # Check if there is server config already exists
    result=check_row_exists(EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        EnvironmentData['LogsDBConfig']['LogsDataBase'], \
        EnvironmentData['LogsDBConfig']['ServerInfoTableName'], Column="test_server_fqdn", \
        Value=TestData['ServerDetails']['Test_Server_fqdn'])
    if result:
        print(f"Updating 'InsertServerInfoIntoDb' as there is already a row exists for '{TestData['ServerDetails']['Test_Server_fqdn']}'")
        
        PgQuery=f"""UPDATE {EnvironmentData['LogsDBConfig']['ServerInfoTableName']} \
        set Server_Last_HeartBeat = '1900-01-01 00:00:00', \
        Test_Server_Region = '{TestData['ServerDetails']['Test_Server_Region']}', \
        Test_Server_Environment = '{TestData['ServerDetails']['Test_Server_Environment']}', \
        Test_Server_Server_Edition = '{TestData['ServerDetails']['Test_Server_Server_Edition']}', \
        Test_Server_CPU_Cores = {TestData['ServerDetails']['Test_Server_CPU_Cores']}, \
        Test_Server_Storage_In_MB = {TestData['ServerDetails']['Test_Server_Storage_In_MB']}, \
        Test_Server_Username = '{TestData['ServerDetails']['Test_Server_Username']}', \
        Test_Server_Password = '{TestData['ServerDetails']['Test_Server_Password']}', \
        Test_Database_Type = '{TestData['ServerDetails']['Test_Database_Type']}', \
        Test_Database_Topology = '{TestData['ServerDetails']['Test_Database_Topology']}', \
        Test_Database_Name = '{TestData['ServerDetails']['Test_Database_Name']}'
        where Test_Server_fqdn = '{TestData['ServerDetails']['Test_Server_fqdn']}'"""
    else:
        print(f"Inserting '{TestData['ServerDetails']['Test_Server_fqdn']}' details into 'InsertServerInfoIntoDb' ")
        PgQuery=f"""INSERT INTO {EnvironmentData['LogsDBConfig']['ServerInfoTableName']} \
        (Test_Server_fqdn, \
        Server_Last_HeartBeat, \
        Test_Server_Region, \
        Test_Server_Environment, \
        Test_Server_Server_Edition, \
        Test_Server_CPU_Cores, \
        Test_Server_Storage_In_MB, \
        Test_Server_Username, \
        Test_Server_Password, \
        Test_Database_Type, \
        Test_Database_Topology, \
        Test_Database_Name \
        ) VALUES ( \
        '{TestData['ServerDetails']['Test_Server_fqdn']}', \
        '1900-01-01 00:00:00', \
        '{TestData['ServerDetails']['Test_Server_Region']}', \
        '{TestData['ServerDetails']['Test_Server_Environment']}', \
        '{TestData['ServerDetails']['Test_Server_Server_Edition']}', \
        {TestData['ServerDetails']['Test_Server_CPU_Cores']}, \
        {TestData['ServerDetails']['Test_Server_Storage_In_MB']}, \
        '{TestData['ServerDetails']['Test_Server_Username']}', \
        '{TestData['ServerDetails']['Test_Server_Password']}', \
        '{TestData['ServerDetails']['Test_Database_Type']}', \
        '{TestData['ServerDetails']['Test_Database_Topology']}', \
        '{TestData['ServerDetails']['Test_Database_Name']}' );"""

    if run_pg_query ( EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        PgQuery,PgDatabase=EnvironmentData['LogsDBConfig']['LogsDataBase']):
        print("Success!\n")
        return(True)
    else:
        print(f"Failed to execute PgQuery: '{PgQuery}'\n")
        return(False)

#def InsertTestInfoIntoDb(EnvironmentData, Client_Hostname):
def InsertTestInfoIntoDb(EnvironmentData, TestData):
    print(f"Trying to InsertTestInfoIntoDb")
    Client_Hostname = TestData["ClientDetails"]["Client_Hostname"]

    if Client_Hostname == None:
        print(f"Invalid Client_Hostname") 
        return False
    if Client_Hostname == "":
        print(f"Invalid Client_Hostname") 
        return False

    # Check if there is a test config already exists for '{TestData['ServerDetails']['Test_Server_fqdn']}'
    result=check_row_exists(EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        EnvironmentData['LogsDBConfig']['LogsDataBase'], \
        EnvironmentData['LogsDBConfig']['ScheduledTestsTable'], Column="test_server", \
        Value=TestData['ServerDetails']['Test_Server_fqdn'])

    if result:
        print(f"There is already a row exists for '{TestData['ServerDetails']['Test_Server_fqdn']}' in '{EnvironmentData['LogsDBConfig']['ScheduledTestsTable']}' table")
        print(f"Deleting existing Config for given server: '{TestData['ServerDetails']['Test_Server_fqdn']}' in {EnvironmentData['LogsDBConfig']['ScheduledTestsTable']}")

        PgQuery=f"DELETE FROM {EnvironmentData['LogsDBConfig']['ScheduledTestsTable']} where test_server='{TestData['ServerDetails']['Test_Server_fqdn']}'"
        if run_pg_query (EnvironmentData['LogsDBConfig']['LogsDbServer'], \
            EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
            EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
            PgQuery,PgDatabase=EnvironmentData['LogsDBConfig']['LogsDataBase']):
            print("Success!\n")
        else:
            print("Failed!\n")
            return(False)

    # Fixing 'ClientInfoTableName' table. Free current test server from other clients
    print(f"Fixing '{EnvironmentData['LogsDBConfig']['ClientInfoTableName']}' table. Free the current test server from other clients")
    PgQuery=f"update {EnvironmentData['LogsDBConfig']['ClientInfoTableName']} set test_server_assigned='None' where test_server_assigned='{TestData['ServerDetails']['Test_Server_fqdn']}'"
    if run_pg_query (EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        PgQuery,PgDatabase=EnvironmentData['LogsDBConfig']['LogsDataBase']):
        print("Success!\n")
    else:
        print("Failed!\n")
        return(False)

    # Check if there is a test config already exists for 'Client_Hostname'
    result=check_row_exists(EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        EnvironmentData['LogsDBConfig']['LogsDataBase'], \
        EnvironmentData['LogsDBConfig']['ScheduledTestsTable'], Column="Client_Hostname", \
        Value=Client_Hostname)
    if result:
        print(f"There is already a row exists for '{Client_Hostname}' in 'ScheduledTestsTable' table")
        print(f"Config for given Client: '{Client_Hostname}' in {EnvironmentData['LogsDBConfig']['ScheduledTestsTable']} will be modifed with new details")

        PgQuery=f"UPDATE {EnvironmentData['LogsDBConfig']['ScheduledTestsTable']} set \
        Test_Server='{TestData['ServerDetails']['Test_Server_fqdn']}', \
        Test_Type='{TestData['TestConfig']['Test_Type']}', \
        Test_Database_Type='{TestData['ServerDetails']['Test_Database_Type']}', \
        Report_Emails='{TestData['TestConfig']['Report_Emails']}', \
        Test_Parameters_script='{TestData['TestConfig']['Test_Parameters_script']}' \
        WHERE Client_Hostname='{Client_Hostname}'"
    else:
        PgQuery=f"INSERT INTO {EnvironmentData['LogsDBConfig']['ScheduledTestsTable']} (\
        Client_Hostname, \
        Test_Server, \
        Test_Type, \
        Test_Database_Type, \
        Report_Emails, \
        Test_Parameters_script \
        ) VALUES ( \
        '{Client_Hostname}', \
        '{TestData['ServerDetails']['Test_Server_fqdn']}', \
        '{TestData['TestConfig']['Test_Type']}', \
        '{TestData['ServerDetails']['Test_Database_Type']}', \
        '{TestData['TestConfig']['Report_Emails']}', \
        '{TestData['TestConfig']['Test_Parameters_script']}');" 

    if run_pg_query (EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        PgQuery,PgDatabase=EnvironmentData['LogsDBConfig']['LogsDataBase']):
        print("Success!\n")
        return(True)
    else:
        print("Failed to execute PgQuery: '{PgQuery}'\n")
        return(False)

def InsertClientInfoIntoDb (EnvironmentData, TestData):
    print(f"Trying to InsertClientInfoIntoDb")
    Client_Hostname = TestData["ClientDetails"]["Client_Hostname"]
    if Client_Hostname == None:
        print(f"Invalid Client_Hostname") 
        return False
    if Client_Hostname == "":
        print(f"Invalid Client_Hostname") 
        return False

    # Check if there is a config already exists for 'Client_Hostname'
    result=check_row_exists(EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        EnvironmentData['LogsDBConfig']['LogsDataBase'], \
        EnvironmentData['LogsDBConfig']['ClientInfoTableName'], Column="Client_Hostname", \
        Value=Client_Hostname)
    if result:
        print(f"There is already a row exists for '{Client_Hostname}' in 'ClientInfoTableName' table")
        print(f"Config for given Client: '{Client_Hostname}' in {EnvironmentData['LogsDBConfig']['ClientInfoTableName']} will be modifed for new client")

        PgQuery=f"UPDATE {EnvironmentData['LogsDBConfig']['ScheduledTestsTable']} set \
        Test_Server='{TestData['ServerDetails']['Test_Server_fqdn']}' \
        WHERE Client_Hostname='{Client_Hostname}' ;"
        if run_pg_query (EnvironmentData['LogsDBConfig']['LogsDbServer'], \
            EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
            EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
            PgQuery,PgDatabase=EnvironmentData['LogsDBConfig']['LogsDataBase']):
            print("Success!\n")
        else:
            print("Failed!\n")
            return(False)

        PgQuery=f"""UPDATE {EnvironmentData['LogsDBConfig']['ClientInfoTableName']} \
        set Client_Last_HeartBeat = '1900-01-01 00:00:00', \
        Test_Server_Assigned = '{TestData['ServerDetails']['Test_Server_fqdn']}', \
        Client_Region = '{TestData['ClientDetails']['Client_Region']}', \
        Client_Resource_Group = '{TestData['ClientDetails']['Client_Resource_Group']}', \
        Client_VM_SKU = '{TestData['ClientDetails']['Client_VM_SKU']}', \
        Client_Username = '{TestData['ClientDetails']['Client_Username']}', \
        Client_Password = '{TestData['ClientDetails']['Client_Password']}', \
        Client_FQDN = '{TestData["ClientDetails"]["Client_FQDN"]}' \
        where Client_Hostname='{Client_Hostname}';"""

    else:
        PgQuery=f"""INSERT INTO {EnvironmentData['LogsDBConfig']['ClientInfoTableName']} \
        (Client_Hostname, \
        Client_Last_HeartBeat, \
        Test_Server_Assigned, \
        Client_Region, \
        Client_Resource_Group, \
        Client_VM_SKU, \
        Client_Username, \
        Client_Password, \
        Client_FQDN \
        ) VALUES ( \
        '{Client_Hostname}', \
        '1900-01-01 00:00:00', \
        '{TestData['ServerDetails']['Test_Server_fqdn']}', \
        '{TestData['ClientDetails']['Client_Region']}', \
        '{TestData['ClientDetails']['Client_Resource_Group']}', \
        '{TestData['ClientDetails']['Client_VM_SKU']}', \
        '{TestData['ClientDetails']['Client_Username']}', \
        '{TestData['ClientDetails']['Client_Password']}', \
        '{TestData["ClientDetails"]["Client_FQDN"]}' );"""

    if run_pg_query (EnvironmentData['LogsDBConfig']['LogsDbServer'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerUsername'], \
        EnvironmentData['LogsDBConfig']['LogsDbServerPassword'], \
        PgQuery,PgDatabase=EnvironmentData['LogsDBConfig']['LogsDataBase']):
        print("Success!\n")
        return(True)
    else:
        print("Failed!\n")
        return(False)

def run_pg_query(PgServer, PgServerUsername, PgServerPassword, PgQuery, PgDatabase='postgres'):
    Result=False

    if PgQuery is None or PgQuery == "":
        print("Invalid query")
    else:
        if ( PgServer is None or PgServer == "") or \
            ( PgDatabase is None or PgDatabase == "") or \
            ( PgServerUsername is None or PgServerUsername == "") or \
            ( PgServerPassword is None or PgServerPassword == ""):
            print("Invalid ServerDeatails")
            return False

        # Try to connect
        try:
            conn=psycopg2.connect(f"host='{PgServer}' dbname='{PgDatabase}' \
                user='{PgServerUsername}' password='{PgServerPassword}'")
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
            try:
                cur.execute(PgQuery)
                if "select" in PgQuery.lower(): # In case of select return the output
                    Result = cur.fetchall()
                else:
                    # commit the changes to the database
                    conn.commit()
                    Result = True
                try:
                    # close communication with the database
                    cur.close()
                except (Exception, psycopg2.DatabaseError) as error:
                    print(error)
                finally:
                    if conn is not None:
                        conn.close()
            except:
                print(f"Failed to execute query{PgQuery} on server{PgServer}")
        except:
            print(f"Unable to connect to PgServer: '{PgServer}'")

    return (Result)

def check_connectivity (PgServer, PgServerUsername, PgServerPassword,PgDatabase='postgres'):
    try:
        responce = run_pg_query(PgServer, PgServerUsername, PgServerPassword, "select 1;",PgDatabase)
        if responce[0][0] == 1:
            return (True)
        else:
            return (False)
    except:
        return (False)

def check_row_exists(PgServer, PgServerUsername, PgServerPassword, PgDatabase, PG_Table, Column, Value):
    PgQuery=f"SELECT COUNT (*) FROM {PG_Table} where \
        {Column}='{Value}'"

    try:
        responce = run_pg_query(PgServer, PgServerUsername, PgServerPassword, PgQuery,PgDatabase)
        if responce[0][0] >= 1:
            return (True)
        else:
            return (False)
    except:
        return (False)

####
# ----------------------------------------------------------------------------------------------------------
####

if __name__ == '__main__':
    ConfigurationFile='./Environment.json'
    try:
        # Initialise parameters
        with open(ConfigurationFile) as EnvironmentFile:  
            EnvironmentData = json.load(EnvironmentFile)

            # Get Client Info
            SubscriptionId=TestData['ClientDetails']['SubscriptionId']
            Client_Hostname = TestData['ClientDetails']['Client_Hostname']
            Client_Region = TestData['ClientDetails']['Client_Region']
            Client_Resource_Group=TestData['ClientDetails']['Client_Resource_Group']
            Client_VM_SKU = TestData['ClientDetails']['Client_VM_SKU'].lower()
            Client_Username = TestData['ClientDetails']['Client_Username']
            Client_Password = TestData['ClientDetails']['Client_Password']
            OSImage = TestData['ClientDetails']['OSImage']

            # Get Server Info
            Test_Server_fqdn = TestData['ServerDetails']['Test_Server_fqdn']
            Test_Server_Region = TestData['ServerDetails']['Test_Server_Region']
            Test_Server_Environment = TestData['ServerDetails']['Test_Server_Environment'] # It should be 'Stage' or 'Prod' or 'Orcas' ; Orcas -> Current Azure PG PaaS or Sterling PG
            Test_Server_Server_Edition = TestData['ServerDetails']['Test_Server_Server_Edition']
            Test_Server_CPU_Cores = TestData['ServerDetails']['Test_Server_CPU_Cores']
            Test_Server_Storage_In_MB = TestData['ServerDetails']['Test_Server_Storage_In_MB']
            Test_Server_Username = TestData['ServerDetails']['Test_Server_Username']
            Test_Server_Password = TestData['ServerDetails']['Test_Server_Password']
            Test_Database_Type = TestData['ServerDetails']['Test_Database_Type']
            Test_Database_Name = TestData['ServerDetails']['Test_Database_Name']

            # Get Logs/Results DB Info
            LogsDbServer = EnvironmentData['LogsDBConfig']['LogsDbServer']
            LogsDbServerUsername = EnvironmentData['LogsDBConfig']['LogsDbServerUsername']
            LogsDbServerPassword = EnvironmentData['LogsDBConfig']['LogsDbServerPassword']
            LogsDataBase = EnvironmentData['LogsDBConfig']['LogsDataBase']
            LogsTableName = EnvironmentData['LogsDBConfig']['LogsTableName']
            ResourceHealthTableName = EnvironmentData['LogsDBConfig']['ResourceHealthTableName']
            ServerInfoTableName = EnvironmentData['LogsDBConfig']['ServerInfoTableName']
            ClientInfoTableName = EnvironmentData['LogsDBConfig']['ClientInfoTableName']
            ScheduledTestsTable = EnvironmentData['LogsDBConfig']['ScheduledTestsTable']

            # Get Test Info
            Test_Parameters_script = TestData['TestConfig']['Test_Parameters_script']
    except IOError:
        print(f"Cannot find ConfigurationFile({ConfigurationFile}). Please check and re-try!")
        exit(1)

   

