FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends snmpd snmp \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY modules/linux_snmpd/templates/snmpd.conf.erb modules/linux_snmpd/templates/snmpd.conf.erb
COPY test/docker/snmpd-permissions/test.sh test/docker/snmpd-permissions/test.sh
CMD ["bash", "test/docker/snmpd-permissions/test.sh"]
