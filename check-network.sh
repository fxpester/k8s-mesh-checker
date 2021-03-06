#!/bin/sh

if [ $# != 3 ]; then
        echo "Usage: $0 port check-hostnetwork(yes|no) send-results-to-telegram(yes|no)  ## checks port for fullmesh connectivity in k8s cluster, telegram token and chatid should be declared as vars TELEGRAM_TOKEN and TELEGRAM_CHAT"
        exit
fi

starttime=$(date)

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
        - image: alpine
          name: alpine
          command: ["/bin/sh"]
          args: ["-c", "apk update && apk add python curl && dd if=/dev/urandom of=/test.data bs=1024 count=100000 && python -m SimpleHTTPServer $1"]


EOF3
	
sleep 30	
	
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
        - image: alpine
          name: alpine
          command: ["/bin/sh"]
          args: ["-c", "apk update && apk add python curl && dd if=/dev/urandom of=/test.data bs=1024 count=100000 && python -m SimpleHTTPServer $1"]
          securityContext:
            privileged: true


EOF2



fi

sleep 30 





export failures=''

ips=$(kubectl get pod -o wide | grep k8s-mesh-checker | awk '{print $6}')
pods=$(kubectl get pod -o wide | grep k8s-mesh-checker | awk '{print $1}')
svcs=$(kubectl get svc -o wide | grep k8s-mesh-checker  | awk '{print $3}')

for pod in $pods

do


 for ip in $ips
 do
 
 node=$(kubectl get pod -o wide | grep $ip | awk '{print $7}')
 kubectl exec $pod -- curl --retry 2 --connect-timeout 2 -f -s -o /dev/null ${ip}:${1} || failures="$failures \n pod - $pod cant connect to host at $ip:${1} running on node $node"
 echo "checking pod - $pod connection to pod on ${ip}:${1} it took $(kubectl exec $pod -- curl  -w "%{time_total}" --retry 2 --connect-timeout 2 -f -s -o /dev/null ${ip}:${1}/test.data)" 
 done


  
 for svc in $svcs
 do
 
 node=$(kubectl get pod -o wide | grep $ip | awk '{print $7}')
 kubectl exec $pod -- curl --retry 2 --connect-timeout 2 -f -s -o /dev/null ${svc}:${1} || failures="$failures \n pod - $pod cant connect to svc at $svc:${1} running on node $node"
 echo "checking pod - $pod connection to svc on ${svc}:${1} it took $(kubectl exec $pod -- curl  -w "%{time_total}" --retry 2 --connect-timeout 2 -f -s -o /dev/null ${svc}:${1}/test.data)" 
 done
 
 podnode=$(kubectl get pod -o wide | grep $pod | awk '{print $7}')
 kubectl exec $pod -- curl --retry 2 --connect-timeout 2 -Lkfso /dev/null https://api.telegram.org/ || failures="$failures \n pod - $pod running on ${podnode} cant connect to telegram"    
 echo "checking pod - $pod running on ${podnode} connection to telegram API"
done



if [ "$3" == "yes" ] ;
then
 if [ "${#failures}" -gt "3000" ];
 then
 echo -e "data was truncated to 3000 chars" | ./telegram.sh -v  -
 fi
echo -e "${failures:0:3000}" | ./telegram.sh -
fi


if [ "$2" == "yes" ] ;
then
kubectl delete ds k8s-mesh-checker-hostnetwork
fi

kubectl delete ds k8s-mesh-checker
kubectl get svc -o wide |  grep k8s-mesh-checker | awk '{print $1}' | xargs kubectl delete svc

sleep 60 

echo -e "failed hosts: $failures"
echo starttime is $starttime - endtime is $(date)
