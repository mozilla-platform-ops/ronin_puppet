#!/bin/bash
# Reports the generic-worker pool ID (workerType) for marlin/Icinga via snmpd extend.
# Wired into snmpd.conf as: extend worker_pool_id /usr/local/bin/snmp_worker_pool_id.sh
# Queried by marlin via NET-SNMP-EXTEND-MIB::nsExtendOutputFull."worker_pool_id"
#
# Reads from /etc/start-worker.yml (the worker-runner config). The
# generic-worker config at /etc/generic-worker.config is *generated
# just-in-time* per task and isn't reliably present at poll time, so we
# pull the pool ID from the always-present worker-runner config instead.
#
# Output is parsed by marlin's snmp_worker_pool_id_check.sh and written to
# InfluxDB as a host_pool record (same downstream consumer as the
# Windows/Mac pool ID checks).
CONFIG=/etc/start-worker.yml
if [ ! -f "$CONFIG" ]; then
  echo "UNKNOWN - $CONFIG not found"
  exit 3
fi
# workerPoolID is typically "<provisionerId>/<workerType>" (e.g.
# "releng-hardware/gecko-t-linux-talos-1804"). Strip the provisionerId
# prefix so the pool name alone is exposed (matches Windows/host_pool
# semantics, where pool == workerType).
RAW=$(sed -nE 's/^[[:space:]]*workerPoolID:[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' "$CONFIG" | head -1)
if [ -z "$RAW" ]; then
  echo "UNKNOWN - workerPoolID not set in $CONFIG"
  exit 3
fi
POOL="${RAW##*/}"
echo "OK - worker_pool_id=$POOL"
exit 0
