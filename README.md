# k8s-mesh-checker

## This little script checks tcp port for fullmesh connectivity in k8s cluster

workflow:

* start centos daemon set with net=host, inside pod start python HTTP server
* start centos daemon set with default net and expose it, inside pod start python HTTP server
* with 'kubectl exec' check that python HTTP server is accessible for every pod that we started (for 7 node cluster it starts 14 pods, runs 294 checks and takes 5 minutes if all ports are accessible) 
* send telegram msg if needed
* remove daemonsets and services

example usage:

`export TELEGRAM_TOKEN=xxx && export TELEGRAM_CHAT=xxx && ./check-network.sh 38743 yes yes`
