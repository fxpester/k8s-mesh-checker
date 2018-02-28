# k8s-mesh-checker

## This little script checks tcp port for fullmesh connectivity in k8s cluster

workflow:

* start centos daemon set with net=host and nc in listen mode
* start centos daemon set with default net and nc in listen mode
* with 'kubectl exec' check that port is accessible for every pod in cluster (for 7 node cluster it starts 14 pods and run 196 checks)
* remove daemonsets
