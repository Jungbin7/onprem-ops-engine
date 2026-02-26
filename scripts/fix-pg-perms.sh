#!/bin/bash
KEY=/mnt/c/project/onprem-ops-engine/.vagrant/machines/memory/vmware_desktop/private_key
chmod 600 "$KEY"
scp -i "$KEY" -o StrictHostKeyChecking=no \
  /mnt/c/project/onprem-ops-engine/tmp-check.sh \
  vagrant@192.168.174.30:/tmp/fix-pg.sh
ssh -i "$KEY" -o StrictHostKeyChecking=no vagrant@192.168.174.30 bash /tmp/fix-pg.sh
