#!/bin/bash
# Reports generic-worker process status for marlin/Icinga via snmpd extend.
# Wired into snmpd.conf as: extend gw_status /usr/local/bin/snmp_check_gw.sh
# Queried by marlin via NET-SNMP-EXTEND-MIB::nsExtendOutputFull."gw_status"
if pgrep -f '/generic-worker' >/dev/null 2>&1; then
  echo "OK - generic-worker running"
  exit 0
fi
echo "CRIT - generic-worker not running"
exit 2
