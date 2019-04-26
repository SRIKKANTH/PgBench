
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
    Test_Server VARCHAR(100) NOT NULL PRIMARY KEY, 
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

CREATE TABLE ResourceHealth
(
    Client_Hostname VARCHAR(100) NOT NULL PRIMARY KEY, 
    Test_Server VARCHAR(100),
    Test_Server_Environment VARCHAR(25),
    Test_Server_Region VARCHAR(25),
    Test_Database_Type  VARCHAR(25),
    Test_Type VARCHAR(25),
    Client_Last_HeartBeat timestamp,
    Server_Last_HeartBeat timestamp,
    Is_Test_Server_Accessible_From_Client VARCHAR(25),
    Is_Test_Executing VARCHAR(25),
    Current_Test_Active_Connections int,
    Client_Memory_Usage_Percentage float,
    Client_Cpu_Usage_Percentage float,
    Client_Root_Disk_Usage_Percentage float,
    Recent_Test_Logs VARCHAR(300),
    Client_Last_Reboot VARCHAR(50)
);

CREATE TABLE pgbenchperf
(
    Iteration SERIAL PRIMARY KEY, 
    Test_Start_Time timestamp,
    Test_End_Time timestamp,
    Environment VARCHAR(25),
    Region VARCHAR(25),
    Test_Server_Edition VARCHAR(25),
    Test_Server_CPU_Cores INT,
    Test_Server_Storage_In_MB INT,
    Client_VM_SKU VARCHAR(25),
    Pg_Server VARCHAR(100),
    Client_Hostname VARCHAR(100),
    Test_Connections INT,
    Os_pg_Connections float,
    TPS_Including_Connection_Establishing float,
    Average_Latency float,
    StdDev_Latency float,
    Scaling_Factor INT,
    Test_Duration INT,
    Cpu_Threads_Used INT,
    Total_Transactions INT,
    Transaction_Type VARCHAR(50),
    Query_Mode VARCHAR(50),
    TPS_Excluding_Connection_Establishing float,
    Client_Os_Memory_Stats_Total float,
    Client_Os_Memory_Stats_Used float,
    Client_Os_Memory_Stats_Free float,
    Client_Os_Cpu_Usage float,
    PgBench_Cpu_Usage float,
    PgBench_Mem_Usage float
)
