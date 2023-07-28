#!/bin/bash

########################
###   COMMON BLOCK   ###
########################
common() {
              mkdir -p /home/ubuntu/boundary
              echo "${priv_key}" >> /home/ubuntu/.ssh/id_rsa
              chown ubuntu /home/ubuntu/.ssh/id_rsa
              chgrp ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              apt-get update -y
              apt-get install ansible -y 
}

########################
###    Worker BLOCK   ###
########################
worker_config() {

tee /home/ubuntu/boundary/pki-worker.hcl > /dev/null <<EOF

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

hcp_boundary_cluster_id = ` echo ${boundary_cluster_addr} | cut -c 9- | cut -d . -f 1` 

worker {
  public_addr = $(public_ip)

  auth_storage_path = "/home/ubuntu/boundary/worker1"

  #initial_upstreams = [ "${boundary_cluster_addr}" ]

  tags {
    type = ["webservers"]
  }

  controller_generated_activation_token = "${worker_token}"
}

EOF
}

####################
#####   MAIN   #####
####################

common
worker_config
