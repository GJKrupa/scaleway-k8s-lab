# Scaleway Kubernetes Cluster Configuration

This project installs a Kubernetes cluster using kubadm and Helm that includes an Ingress and Letsencrypt certificates but not much else.

This cluster is not production ready and is intended for cloud labs.  It includes only a single master/API server and any number of worker nodes as well as persistent storage using Rook and Ceph.

Running the script again will wipe and reset the cluster.

## Requirements

  1. A domain
  2. A sub-domain called k8s-master._domain_name_ pointing at your k8s-master public IP
  3. A scaleway account
  4. Installed Scaleway CLI already logged in
  5. Existing servers named k8s-master and k8s-worker-_n_ (any number of workers should be supported)
     * All nodes must be running Ubuntu 16.04
     * All nodes must have a public IP
     * All nodes must be accessible via SSH without a password (i.e. keys set up correctly)
     * All additional node volumes (/dev/vbd onwards) must be unused and unattached.  They _WILL_ be wiped.
  6. kubectl (latest version) on your ${PATH}

## Instructions

  1. Change the DOMAIN variable at the top of the go.sh script
  2. Run go.sh
