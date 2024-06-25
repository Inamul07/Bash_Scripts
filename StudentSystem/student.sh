#!/bin/bash

IFS=","
scriptPath=$PWD
logsPath=$scriptPath/logs

addStudent() {
    >> $logsPath/students.txt
    count=$(wc -l < $logsPath/students.txt)
    read -p "Enter Student Name: " name
    id=$(( count + 1))
    echo "$id,$name,0,0,0" >> $logsPath/students.txt
}

viewAllStudents() {
    printf "%-10s %-10s\n" Id Name
    while read -r id name mark1 mark2 mark3; do
        printf "%-10s %-10s\n" $id $name
    done < $logsPath/students.txt
}

findByName() {
    read -p "Enter Name To Search: " searchName
    found=0

    while read -r id name mark1 mark2 mark3; do
        if [ $name == $searchName ]; then
            echo "Id = $id"
            echo "Name = $name"
            echo "Mark1 = $mark1"
            echo "Mark2 = $mark2"
            echo "Mark3 = $mark3"
            echo
            found=1
        fi
    done < $logsPath/students.txt

    if [ $found -eq 0 ]; then
        echo "$searchName Not Found"
    fi
}

conductExamination() {
    declare -A students
    while read -r id name mark1 mark2 mark3; do
        mark1=$((RANDOM % 101))
        mark2=$((RANDOM % 101))
        mark3=$((RANDOM % 101))

        students[$id]="$id,$name,$mark1,$mark2,$mark3"
    done < $logsPath/students.txt

    > $logsPath/students.txt

    count=${#students[@]}
    for (( id=1; id<=$count; id++ )); do
        echo "${students[$id]}" >> $logsPath/students.txt
    done
    kill -SIGUSR1 $topper_pid 2>/dev/null
}

evaluateTopper() {
    maxMark=0
    while read -r id name mark1 mark2 mark3; do
        total=$(( mark1 + mark2 + mark3 ))
        if [ $total -gt $maxMark ]; then
            maxMark=$total
            topper=$name
        fi
    done < $logsPath/students.txt
    echo "Topper = $topper; Total = $maxMark" >> $logsPath/toppers.txt
}

topperEvaluater() {
    trap 'evaluateTopper' SIGUSR1
    while true; do
        sleep 1
    done
}

viewResults() {
    printf "%-10s %-10s %-10s %-10s %-10s\n" Id Name Mark1 Mark2 Mark3
    while read -r id name mark1 mark2 mark3; do
        printf "%-10s %-10s %-10s %-10s %-10s\n" $id $name $mark1 $mark2 $mark3
    done < $logsPath/students.txt
}

startExaminations() {
    > $logsPath/toppers.txt
    if [[ -s $logsPath/pids.txt ]]; then
        echo "Examination process is already running"
        return
    fi

    if [ ! -s $logsPath/students.txt ]; then
        echo "No Students Found"
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
    done < $logsPath/pids.txt
    > $logsPath/pids.txt
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