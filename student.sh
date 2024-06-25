#!/bin/bash

declare -A students
IFS=","

addStudent() {
    count=${#students[@]}
    read -p "Enter Student Name: " name
    students[$((count + 1))]="$name,0,0,0"
}

viewAllStudents() {
    printf "%-10s %-10s\n" Id Name
    count="${#students[@]}"
    for (( id=1;id<=$count;id++ )); do
        IFS=","
        read -r name mark1 mark2 mark3 <<< ${students[$id]}
        printf "%-10s %-10s\n" $id $name
    done
}

findByName() {
    read -p "Enter Name To Search: " searchName
    found=0
    for id in ${!students[@]}; do
        IFS=","
        read -r name mark1 mark2 mark3 <<< ${students[$id]}
        if [ $name == $searchName ]; then
            echo "Id = $id"
            echo "Name = $name"
            echo "Mark1 = $mark1"
            echo "Mark2 = $mark2"
            echo "Mark3 = $mark3"
            echo
            found=1
        fi
    done
    if [ $found -eq 0 ]; then
        echo "$searchName Not Found"
    fi
}

conductExamination() {
    IFS=" "
    read -r -a stu_array <<< "$(<students.txt)"
    count="${#stu_array[@]}"
    for (( id=0;id<$count;id++ )); do
        IFS=","
        read -r name mark1 mark2 mark3 <<< ${stu_array[$id]}
        mark1=$((RANDOM % 101))
        mark2=$((RANDOM % 101))
        mark3=$((RANDOM % 101))
        stu_array[$id]="$name,$mark1,$mark2,$mark3"
    done
    echo "${stu_array[@]}" > students.txt
    kill -SIGUSR1 $topper_pid 2>/dev/null
}

evaluateTopper() {
    IFS=" "
    read -r -a stu_array <<< "$(<students.txt)"
    count="${#stu_array[@]}"
    maxMark=0
    for(( id=0; id<$count; id++ )); do
        IFS=","
        read -r name mark1 mark2 mark3 <<< ${stu_array[$id]}
        total=$(( mark1 + mark2 + mark3 ))
        if [ $total -gt $maxMark ]; then
            maxMark=$total
            topper=$name
        fi
    done
    echo "Topper = $topper; Total = $maxMark" >> toppers.txt
}

topperEvaluater() {
    trap 'evaluateTopper' SIGUSR1
    while true; do
        sleep 1
    done
}

viewResults() {
    printf "%-10s %-10s %-10s %-10s %-10s\n" Id Name Mark1 Mark2 Mark3
    count="${#students[@]}"
    for (( id=1;id<=$count;id++ )); do
        IFS=","
        read -r name mark1 mark2 mark3 <<< ${students[$id]}
        printf "%-10s %-10s %-10s %-10s %-10s\n" $id $name $mark1 $mark2 $mark3
    done
}

startExaminations() {
    > toppers.txt
    if [[ -s pids.txt ]]; then
        echo "Examination process is already running"
        return
    fi

    studentCount=${#students[@]}
    if [ $studentCount -eq 0 ]; then
        echo "No Students Found"
        return
    fi

    echo "${students[@]}" > students.txt
    echo "${students[@]}"

    setsid bash -c '
        source ~/Desktop/scripts/student.sh

        topperEvaluater &
        topper_pid=$!

        while true; do
            conductExamination
            sleep 5
        done &
        exam_pid=$!

        echo "$topper_pid $exam_pid" > pids.txt
    '
}

stopExaminations() {
    if [[ ! -s pids.txt ]]; then
        echo "No Examination Process is currently running"
        return
    fi

    IFS=" "
    read -r -a pids <<< "$(<pids.txt)"
    IFS=","
    for (( idx=0; idx<2; idx++ )); do
        kill "${pids[$idx]}"
        wait "${pids[$idx]}" 2>/dev/null
    done
    > pids.txt
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