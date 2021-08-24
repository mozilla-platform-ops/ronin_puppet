#!/bin/bash

production_workertype=gecko-t-win10-64-1803-hw
# (test only) production_workertype=gecko-t-win10-64-ht
remote_script_dir=c:\\programdata\\puppetlabs\\ronin\\audit
remote_audit_script=$remote_script_dir\\worker_status.ps1

timestamp=$(date +%s)
mkdir "${timestamp}work_dir" >/dev/null 2>&1
cd "${timestamp}work_dir" || return
starting_cwd=$(pwd)


Help() {
  echo "Audit and recover Windows Moonshot workers"
  echo
  echo "SSH needs to be enabled and the worker_status.ps1 must be on the worker"
  echo "Must have the winaudit ssh key to work"
  echo
  echo "options:"
  echo
  echo "-c | --chassis (n)      Specify a single chassis. Options 1 through 7."
  echo "-c | --chassis all      Deploy to all 7 chassis."
  echo
  echo "To specify a range  of nodes use last octet of the IP address"
  echo
  echo "-s | --start_ip (octet) Specify the beginging of a range"
  echo "-e | --end_ip (octet)   Specify the end of the range"
  echo "-r | --redeploy         (y)es or (n)o to redeploy unrecovered nodes. defualt n"
  echo
  echo "-h | --help             Print this Help."
  echo
  echo "*EXAMPLES*"
  echo "./audit_recover.sh  -c 1"
  echo "./audit_recover.sh  -c 1 -r y"
  echo "./audit_recover.sh  -c all"
  echo "./audit_recover.sh  -s 2 -e 33"


  exit
}


while [ $# -gt 0 ] ; do
  case $1 in
    -s | --start_ip) S="$2" ;;
    -e | --end_ip) E="$2" ;;
    -c | --chassis) C="$2" ;;
    -r | --redeploy) R="$2" ;;
    -h | --help) Help ;;
  esac
  shift
done

function get_status() {
  downnodes=down_node.txt
  downnodes_2nd=down_node2.txt
  gwdown=gw_down.txt
  nonproductiongw=not_in_production.txt
  delay=45m
  [ -e $downnodes ] && rm $downnodes
  [ -e $downnodes_2nd ] && rm $downnodes_2nd
  [ -e $gwdown ] && rm $gwdown

  if [ -z "$C" ];
  then
    if [ -z "$S" ] && [ -z "$E" ]
    then
      echo Must specify range or chassis.
    elif [ -n "$S" ] && [ -n "$E" ];
    then
      if [ "$S" -le 1 ] || [ "$S" -ge 216 ];
      then
        echo Starting IP is invalid. Needs to be within range of 2 to 216.
        exit
      fi
      if [ "$E" -le 2 ] || [ "$E" -ge 217 ];
      then
        echo Ending IP is invalid. Needs to be within range of 3 to 216.
        exit
      fi
    fi
    s=$S
    e=$E
  elif [ -n "$C" ];
  then
    if [ "$C" -le 0 ] >/dev/null 2>&1 || [ "$C" -ge 8 ] >/dev/null 2>&1;
    then
      echo Valid Chassis numbers are 1 through 7
    fi
    if [ "$C" == 1 ];
    then
      s=2
      e=31
    elif [ "$C" == 2 ];
    then
      s=32
      e=61
    elif [ "$C" == 3 ];
    then
      s=62
      e=91
    elif [ "$C" == 4 ];
    then
      s=92
      e=121
    elif [ "$C" == 5 ];
    then
      s=122
      e=151
    elif [ "$C" == 6 ];
    then
      s=152
      e=181
    elif [ "$C" == 7 ];
    then
      s=182
      e=216
    elif [ "$C" == all ];
    then
      s=2
      e=216
    fi
  fi

  echo "Starting first round of Windows Moonshots audit $(date '+%d/%m/%Y %H:%M:%S')"

  for i in $(seq $s $e); do
    ip=10.49.40.$i
    timeout 15 ssh -o ConnectTimeout=5  -o StrictHostKeyChecking=no administrator@"$ip" "powershell if (!(test-path $remote_audit_script)) {exit 97}; powershell -executionpolicy bypass -file $remote_audit_script $production_workertype" 2>/dev/null
    result=$?
    if [ $result == 0 ];
    then
      :
    else

      name=$(dig @10.48.75.120 +short -x "$ip")
      if [ $result == 255 ];
      then
        echo "${name} ssh connection failed"
        echo "$ip" >> "$downnodes"
      elif [ "$result" == 97 ];
      then
        echo "$name is up but no audit script. Misconfigured."
        echo "$ip" >> "$downnodes"
      elif [ "$result" == 98 ];
      then
        echo "$ip" >> "$nonproductiongw"
      elif [ "$result" == 99 ];
      then
        echo "$name is up but gw not running"
        echo "$ip" >> "$downnodes"
      elif [ "$result" == 101 ];
      then
        echo "$name has been up for more than a day. Assuming gw is stuck."
        echo "$ip" >> "$downnodes"
      elif [ "$result" == 124 ];
      then
        echo "$name" is up but not responding
        echo "$ip" >> "$downnodes"
      # If the powershell script returns a non-zero the bash script will see it as exit 1
      # Leaving the detail exits in place for future script imporvement
      elif [ "$result" == 1 ];
      then
        echo "$name" is not productive. Will recheck.
        echo "$ip" >> "$downnodes"
      fi
    fi
    done

  echo "First round of audit complete $(date '+%d/%m/%Y %H:%M:%S')"
  echo "Waiting $delay before continuing"
  sleep "$delay"

  echo "$delay has passed rechecking down nodes"

  if [ -f "$downnodes" ];
  then
    readarray -t  down1 <  "$downnodes"

    for ip in "${down1[@]}"; do
      timeout 15 ssh -o ConnectTimeout=5  -o StrictHostKeyChecking=no administrator@"$ip" "powershell if (!(test-path $remote_audit_script)) {exit 97}; powershell -executionpolicy bypass -file $remote_audit_script $production_workertype" 2>/dev/null

      result=$?
      if [ "$result" == 0 ];
      then
        :
      else
        name=$(dig @10.48.75.120 +short -x "$ip")
        if [ "$result" == 255 ];
        then
          echo "${name} ssh connection failed"
          echo "$ip" >> "$downnodes_2nd"
            elif [ "$result" == 97 ];
            then
              echo "$name is up but no audit script. Misconfigured."
              echo "$ip" >> "$downnodes_2nd"
        elif [ "$result" == 99 ];
        then
          echo "$name is up but gw not running"
          echo "$ip" >> "$downnodes_2nd"
        elif [ "$result" == 124 ];
        then
          echo "$name is up but not responding"
          echo "$ip" >> "$downnodes_2nd"
        elif [ "$result" == 1 ];
        then
          echo "$name" is not productive. Check logs for more details.
          echo "$ip" >> "$downnodes_2nd"
        fi
      fi
    done
  else
    echo No known down workers in given IP range
    exit
  fi
}

function get_cart() {
  I=$(( 10#$1 ))
  # index 0 for simpler math
  I=$(( I - 1 ))
  if [[ $I -gt 614 ]]; then
    C=$(( ( I - 330 ) / 45 ))
    c=$(( ( I - 300 ) % 45 + 30 ))
  elif [[ $I -gt 299 ]]; then
    C=$(( ( I + 15 ) / 45 ))
    c=$(( ( I + 15 ) % 45 ))
  else
    C=$(( I / 45 ))
    c=$(( I % 45 ))
  fi
  # index 1 match ilo index
  C=$(( C + 1 ))
  n=$(( c + 1 ))
  #echo $C $n
}
export get_cart

function reset_cart () {
  type='t-w1064-ms-'
  domain='.wintest.releng.mdc1.mozilla.com.'
  num_list=list_by_num.txt
  cart_list=cart_list.txt

  [ -e "$num_list" ] && rm "$num_list"
  rm  "*${cart_list}" > /dev/null 2>&1


  readarray -t  down2 <  "$downnodes_2nd"
  for broken_ip in "${down2[@]}"; do
    name=$(dig @10.48.75.120 +short -x "$broken_ip")
    echo "$name" | sed -e "s/^$type//" -e "s/$domain//" >> "$num_list"
  done
  readarray -t num < "$num_list"

  for I in "${num[@]}"; do
    get_cart "$I"
    echo "${n}">> "${C}"-"${cart_list}"
  done
  for c in $(seq 1  7); do
    if [ -f "${c}"-"${cart_list}" ]
    then
      tr '\n' ',' < "${c}"-"${cart_list}" > 1"${c}"-"${cart_list}"
      carts=$(cat 1"${c}"-"${cart_list}")
      ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com reset cartridge power force c"${carts}"
    fi
  done
}

function recheck_status() {
  downnodes_2nd=down_node2.txt
  unrecovered=unrecoverd.txt
  gw_down=gw_down.txt

  [ -e "$unrecovered" ] && rm "$unrecovered"
  [ -e "$gw_down" ] && rm "$gw_down"

  echo Final check of problematic workers

  readarray -t  down2 <  "$downnodes_2nd"
  for ip in "${down2[@]}"; do
        timeout 15 ssh -o ConnectTimeout=5  -o StrictHostKeyChecking=no administrator@"$ip" "powershell if (!(test-path $remote_audit_script)) {exit 97}; powershell -executionpolicy bypass -file $remote_audit_script $production_workertype" 2>/dev/null

    result=$?
    if [ "$result" == 0 ];
    then
      :
    else
      type='t-w1064-ms-'
      domain='.wintest.releng.mdc1.mozilla.com.'

      name=$(dig @10.48.75.120 +short -x "$ip")
      if [ "$result" == 255 ];
      then
        echo "${name} ssh connection failed"
        echo "$ip" >> $unrecovered
      elif [ "$result" == 97 ];
      then
        echo "$name" is up but no audit script. Misconfigured
        echo "$ip" >> "$unrecovered"
      elif [ "$result" == 99 ];
      then
        echo "$name" is up but gw not running
        echo "$ip" >> "$gw_down"
      elif [ "$result" == 124 ];
      then
        echo "$name" is up but not responding
                echo "$ip" >> "$unrecovered"
      fi
    fi
  done
}

function restore() {
  if [ -f "$gw_down" ];
  then
  readarray -t  ips < "$gw_down"
  for ip in "${ips[@]}"; do
    echo "$ip" >> restore.txt
  done
    echo Attempting restore of up problematic workers
    ../restore_moonshot.sh  -f "${starting_cwd}"/restore.txt &
  else
    echo No host to restore
  fi
}

function worker_summary() {
  echo "$(tput setaf 2)COMPLETE"
  echo
  echo "$(tput setaf 2)SUMMARY"
  echo
  if [ -f "$unrecovered" ];
  then
    echo "$(tput setaf 1) Unrecovered Workers"
    readarray -t  unrecovered < $unrecovered
    for node_ip in "${unrecovered[@]}"; do
      name=$(dig @10.48.75.120 +short -x "$node_ip")
      echo "$name at $node_ip"
      oct=${node_ip//10.49.40./}
      echo "$oct" >> unrecovered2.txt
      if [ "$R" == "y" ] || [ "$R" == "yes" ];
      then
        logger -n log-aggregator.srv.releng.mdc1.mozilla.com -P 514 "WindowsAudit :: $name is down and a redeploy has been triggered."
      else
        logger -n log-aggregator.srv.releng.mdc1.mozilla.com -P 514 "WindowsAudit :: $name is down. No additional actions specified."
      fi
    done
  fi
  if [ -f "$gw_down" ];
  then
    echo Workers Restoring
    readarray -t  no_gw < "$gw_down"
    for node_ip in "${no_gw[@]}"; do
      name=$(dig @10.48.75.120 +short -x "$node_ip")
      echo "$name" at "$node_ip"
    done
  fi
  if [ -f "$nonproductiongw" ];
  then
    echo Non-Production Workers
    readarray -t  notprod < "$nonproductiongw"
    for node_ip in "${notprod[@]}"; do
      name=$(dig @10.48.75.120 +short -x "$node_ip")
      echo "$name" at "$node_ip"
      logger -n log-aggregator.srv.releng.mdc1.mozilla.com -P 514 "WindowsAudit :: $name is up but is not in production."
    done
  fi
}

function redeploy() {
  if [ "$R" == "y" ] || [ "$R" == "yes" ] && [ -f unrecovered2.txt ];
  then
    echo Redeploying unrecovered workers
    readarray -t  unrecovered2 < unrecovered2.txt
    n=0
    for ip in "${unrecovered2[@]}"; do
      n=$((n+1))
      ../moonshot_deploy.sh -1 "$ip"
      if [ "$n" -gt 15 ];
      then
        sleep 15m
        n=0
      fi
    done
  else
    :
  fi
}


get_status
reset_cart
echo "cartridge(s) have been reset. Waiting then will recheck"
sleep 5m
recheck_status
restore
worker_summary
redeploy

ending_cwd=$(pwd)

if [ "$ending_cwd" = "$starting_cwd" ];
then
  echo "$(tput setaf 7) cleaning up"
  cd ..
  rm -fr "$ending_cwd"
fi
