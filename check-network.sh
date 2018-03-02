#!/bin/sh

if [ $# != 2 ]; then
        echo "Usage: $0 port check-hostnetwork(yes|no)  ## checks port for fullmesh connectivity in k8s cluster"
        exit
fi



cat <<EOF3 | kubectl create -f -
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: k8s-mesh-checker
spec:
  template:
    metadata:
      labels:
        name: k8s-mesh-checker
    spec:
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule" 
      containers:
        - image: centos
          name: centos
          command: ["/bin/sh"]
          args: ["-c", "python -m SimpleHTTPServer $1"]


EOF3
	
sleep 10	
	
kubectl get pod -o wide | grep k8s-mesh-checker | awk '{print $1}' | xargs -I % -n 1 kubectl expose pod %  --port $1


if [ "$2" == "yes" ] ; 
then

cat <<EOF2 | kubectl create -f -
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: k8s-mesh-checker-hostnetwork
spec:
  template:
    metadata:
      labels:
        name: k8s-mesh-checker-hostnetwork
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
          args: ["-c", "python -m SimpleHTTPServer $1"]
          securityContext:
            privileged: true


EOF2


fi




sleep 120 


export failures=''

ips=$(kubectl get pod -o wide | grep k8s-mesh-checker | awk '{print $6}')
pods=$(kubectl get pod -o wide | grep k8s-mesh-checker | awk '{print $1}')
svcs=$(kubectl get svc -o wide | grep k8s-mesh-checker  | awk '{print $3}')

for pod in $pods

do


 for ip in $ips
 do
 echo "checking pod - $pod connection to host ${ip}:${1}"
 kubectl exec $pod -- curl --connect-timeout 2 -f -s -o /dev/null ${ip}:${1} || failures="$failures \n pod - $pod cant connect to host at $ip:${1}"
 done


  
 for svc in $svcs
 do
 echo "checking pod - $pod connection to svc ${svc}:${1}" 
 kubectl exec $pod -- curl --connect-timeout 2 -f -s -o /dev/null ${ip}:${1} || failures="$failures \n pod - $pod cant connect to svc at $svc:${1}"
 done

done




echo -e "failed hosts: $failures"


if [ "$2" == "yes" ] ;
then
kubectl delete ds k8s-mesh-checker-hostnetwork
fi

kubectl delete ds k8s-mesh-checker
kubectl get svc -o wide |  grep k8s-mesh-checker | awk '{print $1}' | xargs kubectl delete svc



