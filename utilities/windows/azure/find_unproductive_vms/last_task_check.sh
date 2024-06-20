#!/bin/bash
echo Looking for last task of questionable VMs

while [ $# -gt 0 ] ; do
  case $1 in
    -d | --work_dir) D="$2" ;;
  esac
  shift
done


export TASKCLUSTER_ROOT_URL='https://firefox-ci-tc.services.mozilla.com/'
# eval `taskcluster signin`


readarray -t vm_rgs < "${D}/questions.txt"


for vm_rg in "${vm_rgs[@]}"; do
  IFS=':' read -r vm rg wp<<< "${vm_rg}"
  IFS='/' read -r prov wtype<<< "${wp}"
  taskcluster api queue getWorker "$prov" "$wtype" "$rg" "$vm" > /dev/null 2>&1
  result=$?
  if [ $result == 1 ];
  then
    echo "${rg}":"${vm}" &>>"${D}/unproductive.txt"
    echo "${rg}":"${vm}" no return
  else
     taskcluster api queue getWorker "$prov" "$wtype" "$rg" "$vm" > "${D}/${vm}.json" 2>&1
     mapfile -t vmtasks < <(jq -r '.recentTasks[].taskId' "${D}/${vm}.json")
     for task in "${vmtasks[@]}"; do
        taskcluster api queue status "$task" > "${D}/${task}.json" 2>&1
         current_time=$(date -u +"%Y-%m-%d %T")
         START=$(jq -r '.status.runs[0].started' "${D}/${task}.json")
         START_time=${START//T/ }
         #echo $START_time

         start_time="${START_time::-5}"
         declare -i minutes=$(( ($(date --date="${current_time}" +%s) - $(date --date="${start_time}" +%s))/60 ))
         declare -a last_start
         last_start+=($minutes)
     done
     last_task=${last_start[-1]}
     echo "$vm" last task "$task"
     echo last start time "$last_task"
     if [ "$last_task" -gt 136 ];
     then
       echo "$vm" in "$rg" seems unproudcitve.
       echo last task started "$last_task" minutes ago
       echo "${rg}":"${vm}" &>>"${D}/unproductive.txt"
     fi
     unset "last_start[@]"
     unset "vmtasks[@]"
     #read -p "Press enter to continue"
  fi
done

echo
echo Summary of non-productive VMs
echo Inactive
if [[ -f ${D}/unproductive.txt ]];
then
  cat "${D}/unproductive.txt"
else
  echo none
fi
