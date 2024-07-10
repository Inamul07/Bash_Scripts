PRIMARY_HOST=zlabs-auto3
REPLICA_HOST=zlabs-auto6
DATA=$HOME/pgsql/data
PORT=22400
PG_PATH=$HOME/pgsql/bin
LOG_PATH=$HOME/logs
DB_NAME=studentdb

MASTER_PROCESS_CLEARED=false
SLAVE_PROCESS_CLEARED=false

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
        echo "$(date) -- $MODE -- DB returned code $restart_code. Restarting Server. Trial $((restart_count+1))"
        restartServer $host $((restart_count+1))
        return $?
    fi
}

promoteDB() {
    $PG_PATH/pg_ctl promote -D $DATA >> $LOG_PATH/logs.txt
}

stopMonitoring() {
    if [ $MASTER_PROCESS_CLEARED == true ]; then
        MASTER_PROCESS_CLEARED=false
    else
        echo "Master Checking"
        kill $master_checking_pid
        wait $master_checking_pid &>/dev/null
    fi

    if [ $MODE == slave ] && [ $SLAVE_PROCESS_CLEARED == true ]; then
        SLAVE_PROCESS_CLEARED=false
    elif [ $MODE == slave ] && [ $SLAVE_PROCESS_CLEARED == false ]; then
        echo "Slave Checking"
        kill $slave_checking_pid
        wait $slave_checking_pid &>/dev/null
    fi
}

startMonitoring() {
    failRestart=false
    > $LOG_PATH/logs.txt

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

    if [ $MODE == master ]; then

        while true; do
            checkStatus $MASTER_HOST
            master_exit_code=$?

            if [ $master_exit_code -ne 0 ]; then
                echo "$(date) -- $MODE -- DB returned code $master_exit_code. Restarting Server. Trial 1" >> $LOG_PATH/logs.txt
                restartServer $MASTER_HOST 1

                restart_exit_code=$?
                if [ $restart_exit_code -ne 0 ]; then
                    echo "$(date) -- $MODE -- Restart Failed. Promoting Slave As Master" >> $LOG_PATH/logs.txt
                    MASTER_PROCESS_CLEARED=true
                    break
                else
                    echo "$(date) -- $MODE -- Server Restarted Successfully" >> $LOG_PATH/logs.txt
                fi
            fi
            sleep 5
        done & disown
        master_checking_pid=$!

    else

        while true; do
            checkStatus $MASTER_HOST
            master_exit_code=$?

            if [ $master_exit_code -ne 0 ]; then
                echo "$(date) -- $MODE -- Master Server returned code $master_exit_code. Waiting For Confirmation (15 secs)" >> $LOG_PATH/logs.txt
                sleep 15

                checkStatus $MASTER_HOST
                master_exit_code=$?

                if [ $master_exit_code -ne 0 ]; then
                    echo "$(date) -- $MODE -- Master server is Down. Promoting Slave as Master" >> $LOG_PATH/logs.txt
                    promoteDB
                    promotion_exit_code=$?

                    if [ $promotion_exit_code -ne 0 ]; then
                        echo "$(date) -- $MODE -- Promotion Failed" >> $LOG_PATH/logs.txt
                        continue
                    fi
                    kill -SIGUSR1 $mode_switching_pid
                else
                    echo "$(date) -- $MODE -- Master Server is Ok." >> $LOG_PATH/logs.txt
                fi
            fi
            sleep 5
        done & disown
        master_checking_pid=$!

        while true; do
            checkStatus $SLAVE_HOST
            slave_exit_code=$?

            if [ $slave_exit_code -ne 0 ]; then
                echo "$(date) -- $MODE -- Slave Server returned code $slave_exit_code. Restarting Server. Trial 1" >> $LOG_PATH/logs.txt
                restartServer $SLAVE_HOST 1
                slave_exit_code=$?

                if [ $slave_exit_code -ne 0 ]; then
                    echo "$(date) -- $MODE -- Restart Failed." >> $LOG_PATH/logs.txt
                    SLAVE_PROCESS_CLEARED=true
                    break
                fi
                echo "$(date) -- $MODE -- Server Restarted Successfully." >> $LOG_PATH/logs.txt
            fi
            sleep 5
        done & disown
        slave_checking_pid=$!
    fi
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

modeSwitched() {
    stopMonitoring
    MODE=master
    SLAVE_HOST=$MASTER_HOST
    MASTER_HOST=$(hostname)
    echo "Mode Switched" >> $LOG_PATH/logs.txt
    # start
}

modeSwitcher() {
    trap 'modeSwitched' SIGUSR1
    while true; do
        sleep 1
    done
}

logLatency() {
    echo "$(date)" >> $LOG_PATH/pgbench.txt
    $PG_PATH/pgbench -c 50 -j 2 -t 50 -d $DB_NAME -p 22400 >> $LOG_PATH/pgbench.txt 2>/dev/null
    echo "" >> $LOG_PATH/pgbench.txt
}

logPgBench() {
    > $LOG_PATH/pgbench.txt
    while true; do
        logLatency
        sleep 10
    done &
    log_pgbench_pid=$!
}

stopLogPgBench() {
    kill $log_pgbench_pid
    wait $log_pgbench_pid &>/dev/null
}

stopMonitoringProcess() {
    stopMonitoring
    echo "Mode Switching"
    kill $mode_switching_pid
    wait $mode_switching_pid &>/dev/null
}

startMonitoringProcess() {
    modeSwitcher &
    mode_switching_pid=$!
    startMonitoring $1 # -f
    # Start PgBench
}

startMonitoringProcess

