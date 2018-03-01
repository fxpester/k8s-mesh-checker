# k8s-mesh-checker

## This little script checks tcp port for fullmesh connectivity in k8s cluster

workflow:

* start centos daemon set with net=host, inside pod running nc in listen mode
* start centos daemon set with default net and expose it, inside pod running nc in listen mode
* with 'kubectl exec' check that nc port is accessible for every pod that we started (for 7 node cluster it starts 14 pods, runs 294 checks and takes 5 minutes if all ports are accessible) 
* remove daemonsets and services

example usage:

`./check-network.sh 36721 yes`
