PRIMARY_HOST=zlabs-auto3
REPLICA_HOST=zlabs-auto6
DATA=$HOME/pgsql/data
PORT=22400
PG_PATH=$HOME/pgsql/bin
LOG_PATH=$HOME/scripts/logs
DB_NAME=studentdb

if [ -f $DATA/standby.signal ]; then
    MODE=slave
    if [ $(hostname) == $PRIMARY_HOST ]; then
        MASTER_HOST=$REPLICA_HOST
        SLAVE_HOST=$PRIMARY_HOST
    else
        MASTER_HOST=$PRIMARY_HOST
        SLAVE_HOST=$REPLICA_HOST
    fi
else 
    MODE=master
    if [ $(hostname) == $PRIMARY_HOST ]; then
        MASTER_HOST=$PRIMARY_HOST
        SLAVE_HOST=$REPLICA_HOST
    else 
        MASTER_HOST=$REPLICA_HOST
        SLAVE_HOST=$PRIMARY_HOST
    fi
fi

checkStatus() {
    local host=$1

    $PG_PATH/pg_isready -h $host -d $DB_NAME -p $PORT >> $LOG_PATH/logs.txt
    return $?
}

restartServer() {
    local host=$1
    local restart_count=$2

    if [ $failRestart == true ]; then
        /bin/false
    else
        $PG_PATH/pg_ctl -D $DATA -l $PG_PATH/../logfile restart >> $LOG_PATH/logs.txt
    fi
    restart_code=$?

    if [ $restart_code -ne 0 ]; then
        if [ $((restart_count+1)) == 4 ]; then
            return 1
        fi
        sleep 5
        echo "$(date) -- $MODE -- DB returned code $restart_code. Restarting Server. Trial $((restart_count+1))"  >> $LOG_PATH/logs.txt
        restartServer $host $((restart_count+1))
        return $?
    fi
}

promoteDB() {
    $PG_PATH/pg_ctl promote -D $DATA >> $LOG_PATH/logs.txt
}

stopMonitoring() {
    if [ ! -s $LOG_PATH/pids.txt ]; then
        echo "No monitoring process running"
        return
    fi

    IFS=
    while read -r process_id; do
        if [ -z $process_id ]; then
            continue
        fi
        
        kill $process_id
        wait $process_id &>/dev/null
    done < $LOG_PATH/pids.txt

    master_checking_pid=
    slave_checking_pid=
    > $LOG_PATH/pids.txt
}

startMonitoring() {
    export failRestart=false
    > $LOG_PATH/logs.txt
    > $LOG_PATH/pids.txt
    rm -f $LOG_PATH/promote.signal

    local OPTIND
    while getopts "f" opt; do
        case ${opt} in
            f)
                failRestart=true
            ;;
            ?)
                echo "Invalid Option ${OPT}"
            ;;
        esac
    done

    setsid bash -c './scripts/monitoringScript.sh'
}

switchMode() {
    stopMonitoring
    startMonitoring
}

makeAsSlave() {
    if [ $(hostname) == $SLAVE_HOST ]; then
        echo "Current Host is Already a Slave of $MASTER_HOST:$PORT server"
        return 1
    fi

    read -p "Clear $DATA contents? (y/n)" choice
    if [ $choice != "y" ]; then
        echo "Operation Aborted..."
        return 1
    fi

    rm -rf $DATA/*
    $PG_PATH/pg_basebackup -h $SLAVE_HOST --checkpoint=fast -D $DATA -R --slot=data_replication -C --port=$PORT
    echo "$MASTER_HOST is converted into slave"
    MODE=slave
    MASTER_HOST=$SLAVE_HOST
    SLAVE_HOST=$(hostname)
}