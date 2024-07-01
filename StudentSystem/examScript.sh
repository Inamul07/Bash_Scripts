source /home/test1/StudentSystem/student.sh

topperEvaluater &
topper_pid=$!

while true; do
    conductExamination
    sleep 5
done &
exam_pid=$!

while true; do
    while [ -s $logsPath/signal.txt ]; do
        sleep 1
    done
    logToppers
    sleep 10
done &
logging_pid=$!

echo "$topper_pid" >>$logsPath/pids.txt
echo "$exam_pid" >>$logsPath/pids.txt
echo "$logging_pid" >>$logsPath/pids.txt
