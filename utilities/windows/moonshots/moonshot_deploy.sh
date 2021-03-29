#!/bin/bash

timestamp=$(date +%s)
mkdir "${timestamp}deploy_dir" >/dev/null 2>&1
cd "${timestamp}deploy_dir" || return
starting_cwd=$(pwd)

Help()
{
   echo "Deploy Windows Moonshot workers."
   echo
   echo "This will only work if a default task sequence is set in This will only work if a default task sequence is set in
MDT's rules.ini file."
   echo "Must have the relops or winaudit ssh key to work"
   echo
   echo "options:"
   echo
   echo "-c | --chassis (n)      Specify a single chassis. Options 1 through 7."
   echo "-c | --chassis all      Deploy to all 7 chassis."
   echo
   echo "To specify a single node or range use last octet of the IP address"
   echo
   echo "-1 | --1_ip (octet)     Deploy to a single."
   echo "-s | --start_ip (octet) Specify the beginging of a range"
   echo "-e | --end_ip (octent)  Specify the end of the range"
   echo
   echo "-h | --help             Print this Help."
   echo
   echo "*EXAMPLES*"
   echo "./moonshot_deploy.sh -c 1"
   echo "./moonshot_deploy.sh -c all"
   echo "./moonshot_deploy.sh -s 2 -e 33"

   exit
}

while [ $# -gt 0 ] ; do
  case $1 in
    -s | --start_ip) S="$2" ;;
    -e | --end_ip) E="$2" ;;
    -1 | --1_ip) O="$2" ;;
    -h | --help) Help ;;
    -c | --chassis) C="$2" ;;

  esac
  shift
done

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
}
export get_cart

function predeploy() {

  node_list=nodes.txt

  [ -e $node_list ] && rm $node_list
  if [ -z "$C" ] && [ -z "$O" ];
  then
    if [ -z "$S" ] && [ -z "$E" ] && [ -z "$O" ];
    then
      echo Must specify range or single ip address!
      exit
    elif [ -n "$S" ] && [ -n "$E" ] && [ -n "$O" ];
    then
      echo Must be either range or an ip address. Not both.
    elif [ -n "$S" ] && [ -n "$E" ] && [ -z "$O" ];
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
    for i in $(seq "$S" "$E"); do
      ip=10.49.40."$i"
      name=$(dig @10.48.75.120 +short -x "$ip")
      echo "$name >> $node_list"
    done
  elif [ -n "$O" ];
  then
    ip=10.49.40."$O"
    name=$(dig @10.48.75.120 +short -x "$ip")
    echo "$name >> $node_list"
  elif [ -n "$C" ] && [ -z "$O" ];
  then
    if [ "$C" -le 0 ] >/dev/null 2>&1  || [ "$C" -ge 8 ] >/dev/null 2>&1;
    then
      echo Valid Chassis numbers are 1 through 7
      exit 3
    fi
    if [ "$C" == 1 ];
    then
      S=2
      E=31
    elif [ "$C" == 2 ];
    then
      S=32
      E=61
    elif [ "$C" == 3 ];
    then
      S=62
      E=91
    elif [ "$C" == 4 ];
    then
      S=92
      E=121
    elif [ "$C" == 5 ];
    then
      S=122
      E=151
    elif [ "$C" == 6 ];
    then
      S=152
      E=181
    elif [ "$C" == 7 ];
    then
      S=182
      E=216
    elif [ "$C" == all ];
    then
      S=2
      E=6
    fi
    for i in $(seq "$S" "$E"); do
      ip=10.49.40.$i
      name=$(dig @10.48.75.120 +short -x "$ip")
      echo "$name >> $node_list"
    done
  fi
}

function map_carts() {

  node_list=nodes.txt
  cart_list=cart_list.txt
  num_list=list_by_num.txt
  type='t-w1064-ms-'
  domain='.wintest.releng.mdc1.mozilla.com.'

  if [ -n "$O" ];
  then
    N=$(echo "$name" | sed -e "s/^$type//" -e "s/$domain//")
    get_cart "$N"
  else
    readarray -t  nodes <  $node_list

    for name in "${nodes[@]}"; do
      echo "$name" | sed -e "s/^$type//" -e "s/$domain//" >> $num_list
    done
    readarray -t num < $num_list
    for n in "${num[@]}"; do
     get_cart "$n"
     echo "${n}">>"${C}"-"${cart_list}"
   done
 fi
}
function deploy() {

  cart_list=cart_list.txt
  setpxe_delay=15s
  deploy_delay=15m

  if [ -n "$O" ];
  then
    echo "Deploying $name"
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${C}".inband.releng.mdc1.mozilla.com set node bootonce pxe c"${n}n1"
    sleep 5s
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${C}".inband.releng.mdc1.mozilla.com  set node power off force c"${n}n1"
    sleep 5s
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${C}".inband.releng.mdc1.mozilla.com  set node power on  c"${n}n1"
  else
  for c in $(seq 1  7); do
    if [ -f "${c}"-"${cart_list}" ]
    then
      readarray -t  carts <  "${c}"-"${cart_list}"
      for C in "${carts[@]}"; do
        if [ "$C" -le 30 ];
        then
          C1+=("${C}n1,")
          echo "${C}" >> "${c}"-deploy1.txt
        else
          C2+=("${C}n1,")
          echo "${C}" >> "${c}"-deploy2.txt
        fi
      done
      if [ -f "${c}"-deploy1.txt ];
      then
        tr '\n' ',' < "${c}"-deploy1.txt > "${c}"-1deploy1.txt
      fi
      if [ -f "${c}"-deploy2.txt ];
      then
        tr '\n' ',' < "${c}"-deploy2.txt > "${c}"-1deploy2.txt
      fi
      if [ -f "${c}"-1deploy1.txt ];
      then
        echo "Setting applicable nodes to pxe boot for nodes 16 - 30 Chassis $c"
        deploy1=$(cat "${c}"-1deploy1.txt)
        deploya="${deploy1%?}"
        echo "Waiting $setpxe_delay then resetting cartridges"
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com set node bootonce pxe c"${deploya}n1"
        sleep "$setpxe_delay"
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com  set node power off force  c"${deploya}n1"
        sleep "$setpxe_delay"
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com  set node power on  c"${deploya}n1"
        echo Cartridges have been reset waiting $deploy_delay before initiating more deployments
        sleep "$deploy_delay"
      fi
      if [ -f "${c}"-1deploy2.txt ];
      then
        echo "Setting applicable nodes to pxe boot for nodes 31 - 45 Chassis $c"
        deploy2=$(cat "${c}"-1deploy2.txt)
        deployb="${deploy2%?}"
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com set node bootonce pxe c"${deployb}"n1
        echo "Waiting $setpxe_delay then resetting cartridges"
        sleep "$setpxe_delay"
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com  set node power off force c"${deployb}n1"
        sleep "$setpxe_delay"
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no winaudit@moon-chassis-"${c}".inband.releng.mdc1.mozilla.com  set node power on  c"${deployb}n1"
        echo "Cartridges have been reset waiting $deploy_delay before initiating more deployments"
        sleep "$deploy_delay"
      fi
    fi
  done
  fi
}

predeploy
map_carts
deploy
ending_cwd=$(pwd)
if [ "$ending_cwd" = "$starting_cwd" ];
then
  echo cleaning up
  cd ..
  rm -fr "$ending_cwd"
fi
