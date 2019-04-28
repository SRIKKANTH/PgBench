import psycopg2
import psycopg2.extras

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
    Test_Database_Name VARCHAR(25)
);

CREATE TABLE Scheduled_tests
(
    Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
    Test_Server VARCHAR(100),
    Test_Parameters_script  VARCHAR(1000) NOT NULL
);
'''

def InsertServerInfoInToDb ():
    sql_cmd=f"""INSERT INTO {ServerInfoTableName} \
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
    Test_Database_Name \
    ) VALUES ( \
    '{Test_Server_fqdn}', \
    '{Server_Last_HeartBeat}', \
    '{Test_Server_Region}', \
    '{Test_Server_Environment}', \
    '{Test_Server_Server_Edition}', \
    {Test_Server_CPU_Cores}, \
    {Test_Server_Storage_In_MB}, \
    '{Test_Server_Username}', \
    '{Test_Server_Password}', \
    '{Test_Database_Type}', \
    '{Test_Database_Name}' );"""
   # print(sql_cmd)
    return(run_pg_query (sql_cmd))

def InsertClientInfoInDb ():
    sql_cmd=f"""INSERT INTO {ClientInfoTableName} \
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
    '{Client_Last_HeartBeat}', \
    '{Test_Server_Assigned}', \
    '{Client_Region}', \
    '{Client_Resource_Group}', \
    '{Client_VM_SKU}', \
    '{Client_Username}', \
    '{Client_Password}', \
    '{Client_FQDN}' );"""
    return(run_pg_query (sql_cmd))

def run_pg_query(sql_cmd):
    Result=False
    if sql_cmd is None or sql_cmd == "":
        print("Invalid query")
    else:
        if ( LogsDbServer is None or LogsDbServer == "") or \
            ( LogsDataBase is None or LogsDataBase == "") or \
            ( LogsDbServerUsername is None or LogsDbServerUsername == "") or \
            ( LogsDbServerPassword is None or LogsDbServerPassword == ""):
            print("Invalid ServerDeatails")
            return False

        # Try to connect
        try:
            conn=psycopg2.connect(f"host='{LogsDbServer}' dbname='{LogsDataBase}' user='{LogsDbServerUsername}' password='{LogsDbServerPassword}'")
        except:
            print(f"I am unable to connect to LogsDb '{LogsDbServer}'")
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        try:
            cur.execute(sql_cmd)
        except:
            print(f"Failed to execute query{sql_cmd} on server{LogsDbServer}")

        if "select" in sql_cmd.lower():
            Result = cur.fetchall()
            print (Result)
        else:
            try:
                # commit the changes to the database
                conn.commit()
                # close communication with the database
                cur.close()
            except (Exception, psycopg2.DatabaseError) as error:
                print(error)
            finally:
                if conn is not None:
                    conn.close()
            Result = True

    return (Result)

if __name__ == '__main__':
    Client_Hostname='perf-client-190427034433b'
    Client_Last_HeartBeat='1900-09-09 09:09:09'
    Test_Server_Assigned='blazure.com'
    Client_Region='eastus2'
    Client_Resource_Group='longhaul-perf-clients'
    Client_VM_SKU='standard_d4s_v3'
    Client_Username='user'
    Client_Password='pasword!@#'
    Client_FQDN='perf.com'

    Test_Server_fqdn=Test_Server_Assigned
    Server_Last_HeartBeat='1900-09-09 09:09:09'
    Test_Server_Region='southeastasia'
    Test_Server_Environment='Orcas'
    Test_Server_Server_Edition='GeneralPurpose'
    Test_Server_CPU_Cores=4
    Test_Server_Storage_In_MB=1048576
    Test_Server_Username='user'
    Test_Server_Password='pasword!@#'
    Test_Database_Type='postgres'
    Test_Database_Name='postgres'

    print (InsertClientInfoInDb())
    run_pg_query(f"select * from {ClientInfoTableName}")
    print(InsertServerInfoInToDb())
    run_pg_query(f"select * from {ServerInfoTableName}")
