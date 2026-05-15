#!/bin/bash
# Reports the generic-worker pool ID (workerType) for marlin/Icinga via snmpd extend.
# Wired into snmpd.conf as: extend worker_pool_id /usr/local/bin/snmp_worker_pool_id.sh
# Queried by marlin via NET-SNMP-EXTEND-MIB::nsExtendOutputFull."worker_pool_id"
# Output is parsed by marlin's linux_worker_pool_id_check.sh and written to InfluxDB
# as a host_pool record (the same downstream consumer as the Windows pool ID check).
CONFIG=/etc/generic-worker.config
if [ ! -f "$CONFIG" ]; then
  echo "UNKNOWN - $CONFIG not found"
  exit 3
fi
POOL=$(sed -nE 's/^[[:space:]]*"workerType":[[:space:]]*"([^"]+)".*/\1/p' "$CONFIG" | head -1)
if [ -z "$POOL" ]; then
  echo "UNKNOWN - workerType not set in $CONFIG"
  exit 3
fi
echo "OK - worker_pool_id=$POOL"
exit 0
