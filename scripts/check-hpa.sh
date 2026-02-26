#!/bin/bash
ssh -i ~/.vagrant-keys/brain_key -o StrictHostKeyChecking=no vagrant@192.168.174.10 \
  "sudo k3s kubectl get hpa ecommerce-api-hpa && echo '' && sudo k3s kubectl get pods | grep ecommerce"
