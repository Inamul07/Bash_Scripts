#!/bin/bash

scriptPath=$PWD
logsPath=$scriptPath/logs

psql="~/pgsql/bin/psql -p 22400 -d studentdb"
remote=test1@zlabs-auto3

addStudent() {
    read -p "Enter Student Name: " name
    ssh $remote $psql" -c \"INSERT INTO student (name) VALUES ('$name')\"" &>/dev/null
}

viewAllStudents() {
    printf "%-10s %-10s\n" Id Name
    students=$(ssh $remote $psql" -q -t -c \"COPY (SELECT stu_id, name FROM student) TO STDOUT (DELIMITER '|');\"")
    echo "$students" | while IFS="|" read -r id name; do
        printf "%-10s %-10s\n" $id $name
    done
}

findByName() {
    read -p "Enter Name To Search: " searchName
    student=$(ssh $remote $psql" -q -t -c \"COPY (SELECT * FROM student WHERE name='$searchName') TO STDOUT (DELIMITER ',');\"")

    if [ -z "$student" ]; then
        echo "$searchName Not Found"
        return
    fi

    echo $student | while IFS=" " read -r id name mark1 mark2 mark3 total; do
        echo "Id = $id"
        echo "Name = $name"
        echo "Mark1 = $mark1"
        echo "Mark2 = $mark2"
        echo "Mark3 = $mark3"
        echo
    done
}

conductExamination() {
    students=$(ssh $remote $psql" -q -t -c \"COPY (SELECT * FROM student) TO STDOUT (DELIMITER '|');\"")
    echo "$students" >$scriptPath/tmp/students.txt

    IFS="|"
    while read -r id name mark1 mark2 mark3 total; do
        mark1=$((RANDOM % 101))
        mark2=$((RANDOM % 101))
        mark3=$((RANDOM % 101))

        export id mark1 mark2 mark3 remote psql
        setsid bash -c 'ssh $remote $psql" -c \"UPDATE student SET mark1=$mark1, mark2=$mark2, mark3=$mark3 WHERE stu_id=$id;\""' &>/dev/null 2>/dev/null
    done <$scriptPath/tmp/students.txt

    kill -SIGUSR1 $topper_pid 2>/dev/null
    rm $scriptPath/tmp/students.txt
}

evaluateTopper() {
    student=$(ssh $remote $psql" -c \"COPY (SELECT name, total FROM student ORDER BY total DESC LIMIT 1) TO STDOUT (DELIMITER ',');\"")
    IFS=","
    read -r name total <<<"$student"
    echo "Topper = $name; Total = $total" >>$logsPath/toppers.txt
}

topperEvaluater() {
    trap 'evaluateTopper' SIGUSR1
    while true; do
        sleep 1
    done
}

logToppers() {
    scp $logsPath/toppers.txt test1@zlabs-auto2:/home/test1/exam_logs/$(date +%d-%m-%Y--%H-%M-%S).txt
}

# topperLogger() {
#     trap 'logToppers' SIGUSR1
#     while true; do
#         sleep 1
#     done
# }

viewResults() {
    students=$(ssh $remote $psql" -q -t -c \"COPY (SELECT * FROM student) TO STDOUT (DELIMITER '|');\"")
    printf "%-10s %-10s %-10s %-10s %-10s %-10s\n" Id Name Mark1 Mark2 Mark3 Total
    echo "$students" | while IFS='|' read -r id name mark1 mark2 mark3 total; do
        printf "%-10s %-10s %-10s %-10s %-10s %-10s\n" $id $name $mark1 $mark2 $mark3 $total
    done
}

startExaminations() {
    >$logsPath/toppers.txt
    if [[ -s $logsPath/pids.txt ]]; then
        echo "Examination process is already running"
        return
    fi

    setsid bash -c $scriptPath'/examScript.sh'
}

stopExaminations() {
    if [[ ! -s $logsPath/pids.txt ]]; then
        echo "No Examination Process is currently running"
        return
    fi

    while read -r process_pid; do
        kill $process_pid
        wait $process_pid 2>/dev/null
    done <$logsPath/pids.txt
    >$logsPath/pids.txt
}

runPrompt() {
    i=1
    while [ $i -gt 0 ] && [ $i -lt 8 ]; do
        echo
        echo "1. Add Student"
        echo "2. View All Students"
        echo "3. Find Student By Name"
        echo "4. Conduct Examination"
        echo "5. View Results"
        echo "6. Start Examinations"
        echo "7. Stop Examinations"
        echo "8. Exit"
        read -p "Enter ur Choice: " i
        echo

        case $i in
        1)
            addStudent
            ;;
        2)
            viewAllStudents
            ;;
        3)
            findByName
            ;;
        4)
            conductExamination
            ;;
        5)
            viewResults
            ;;
        6)
            startExaminations
            ;;
        7)
            stopExaminations
            ;;
        esac
    done
}
