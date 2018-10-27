pkill pbenchTest
log_file=LogPbenchTest_`hostname`.log
if [ -f $log_file ]; then
    folder=OldLogs/`date|sed "s/ /_/g"| sed "s/:/_/g"`
    mkdir $folder
    mv $log_file $folder/
fi
bash pbenchTest.sh > $log_file 2>&1
