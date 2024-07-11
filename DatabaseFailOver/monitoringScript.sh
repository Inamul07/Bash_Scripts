source $PWD/scripts/failOverScript.sh

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
                touch $LOG_PATH/promote.signal
                stopMonitoring
                break
            else
                echo "$(date) -- $MODE -- Server Restarted Successfully" >> $LOG_PATH/logs.txt
            fi
        fi
        sleep 5
    done &
    master_checking_pid=$!

else

    while true; do
        ssh $MASTER_HOST "test -f $LOG_PATH/promote.signal"
        master_exit_code=$?

        if [ $master_exit_code -eq 0 ]; then
            echo "$(date) -- $MODE -- Master server is Down. Promoting Slave as Master" >> $LOG_PATH/logs.txt
            promoteDB
            promotion_exit_code=$?

            if [ $promotion_exit_code -ne 0 ]; then
                echo "$(date) -- $MODE -- Promotion Failed" >> $LOG_PATH/logs.txt
                stopMonitoring
                break
            fi
            setsid bash -c '
                source /home/test1/scripts/failOverScript.sh
                switchMode
            '
            break
        else
            echo "$MASTER_HOST:$PORT - accepting connections" >> $LOG_PATH/logs.txt
        fi
        sleep 5
    done &
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
                stopMonitoring
                break       
            fi
            echo "$(date) -- $MODE -- Server Restarted Successfully." >> $LOG_PATH/logs.txt
        fi
        sleep 5
    done &
    slave_checking_pid=$!
fi

echo "$master_checking_pid" >> $LOG_PATH/pids.txt
if [ ! -z $slave_checking_pid ]; then
    echo "$slave_checking_pid" >> $LOG_PATH/pids.txt
fi