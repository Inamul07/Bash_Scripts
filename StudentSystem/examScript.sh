source ~/Desktop/scripts/StudentSystem/student.sh

topperEvaluater &
topper_pid=$!

while true; do
    conductExamination
    sleep 5
done &
exam_pid=$!

echo "$topper_pid" >> $logsPath/pids.txt
echo "$exam_pid" >> $logsPath/pids.txt