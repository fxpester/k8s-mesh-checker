#!/bin/sh

if [ $# != 2 ]; then
        echo "Usage: $0 port check-hostnetwork(yes|no)  ## checks port for fullmesh connectivity in k8s cluster"
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
          args: ["-c", "python -m SimpleHTTPServer $1"]
          imagePullPolicy: Always


EOF3
	
sleep 10	
	
kubectl get pod -o wide | grep echoserver | awk '{print $1}' | xargs -I % -n 1 kubectl expose pod %  --port $1


if [ "$2" == "yes" ] ; 
then

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
          args: ["-c", "python -m SimpleHTTPServer $1"]
          imagePullPolicy: Always
          securityContext:
            privileged: true


EOF2


fi




sleep 120 


export failures=''

ips=$(kubectl get pod -o wide | grep echoserver | awk '{print $6}')
pods=$(kubectl get pod -o wide | grep echoserver | awk '{print $1}')
svcs=$(kubectl get svc -o wide | grep echoserver  | awk '{print $3}')

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
kubectl delete ds echoserver-hostnetwork
fi

kubectl delete ds echoserver
kubectl get svc -o wide |  grep echoserver | awk '{print $1}' | xargs kubectl delete svc



