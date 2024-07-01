source /home/test1/StudentSystem/student.sh

topperEvaluater &
topper_pid=$!

while true; do
    while [ -f $logsPath/signal.txt ]; do
        sleep 1
    done
    touch $logsPath/signal.txt
    conductExamination
    rm -f $logsPath/signal.txt
    sleep 5
done &
exam_pid=$!

while true; do
    while [ -f $logsPath/signal.txt ]; do
        sleep 1
    done
    touch $logsPath/signal.txt
    logToppers
    rm -f $logsPath/signal.txt
    sleep 10
done &
logging_pid=$!

echo "$topper_pid" >>$logsPath/pids.txt
echo "$exam_pid" >>$logsPath/pids.txt
echo "$logging_pid" >>$logsPath/pids.txt
