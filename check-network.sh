#!/bin/sh

if [ $# != 1 ]; then
        echo "Usage: $0 port ## checks port for fullmesh connectivity in k8s cluster"
        exit
fi



cat <<EOF3 | kubectl create -f -
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: echoserver
spec:
  template:
    metadata:
      labels:
        name: echoserver
    spec:
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule" 
      containers:
        - image: centos
          name: centos
          command: ["/bin/sh"]
          args: ["-c", "yum install nmap-ncat-6.40-7.el7.x86_64 -y && nc -l -k -n -p $1"]
          imagePullPolicy: Always


EOF3
	
sleep 10	
	
kubectl get pod -o wide | grep echoserver | awk '{print $1}' | xargs -I % -n 1 kubectl expose pod %  --port $1



cat <<EOF2 | kubectl create -f -
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: echoserver-hostnetwork
spec:
  template:
    metadata:
      labels:
        name: echoserver-hostnetwork
    spec:
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule" 
      hostNetwork: true
      containers:
        - image: centos
          name: centos
          command: ["/bin/sh"]
          args: ["-c", "yum install nmap-ncat-6.40-7.el7.x86_64 -y && nc -l -k -n -p $1"]
          imagePullPolicy: Always
          securityContext:
            privileged: true


EOF2





sleep 120 


export failures=''

hosts=$(kubectl get pod -o wide | grep echoserver | awk '{print $6}')
kubehosts=$(kubectl get pod -o wide | grep echoserver | awk '{print $1}')
svcs=$(kubectl get svc -o wide | grep echoserver  | awk '{print $3}')

for host in $hosts
do


 for kubehost in $kubehosts
 do
 echo "checking pod - $kubehost connection to host ${host}:${1}"
 kubectl exec $kubehost -- timeout 2 echo dummy-payload  > /dev/tcp/$host/$1 || failures="$failures \n pod - $kubehost cant connect to host $host:${1}"


  for svc in $svcs  
  do
  echo "checking pod - $kubehost connection to svc ${svc}:${1}" 
  kubectl exec $kubehost -- timeout 2 echo dummy-payload  > /dev/tcp/$svc/$1 || failures="$failures \n pod - $kubehost cant connect to svc at $svc:${1}"
    

  done

 done

done



echo -e "failed hosts: $failures"



kubectl delete ds echoserver-hostnetwork
kubectl delete ds echoserver
kubectl get svc -o wide |  grep echoserver | awk '{print $1}' | xargs kubectl delete svc



