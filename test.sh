#!/bin/bash
 
set -e

SELF="$(basename $0)"

usage() {
    cat <<USAGE
Usage: $SELF [ --show | --perform | --put-metrics ]
USAGE
}

main() {

which aws >/dev/null || {
  echo >&2 "'aws' not found: please install https://github.com/aws/aws-cli"
  exit 1
}

which jq >/dev/null || {
  echo >&2 "'jq' not found: please install http://stedolan.github.io/jq/"
  exit 1
}

case "$1" in
    --put-metrics )
        loadData;
        ;;
    --perform )
        perform;
        ;;
    --show )
        loadData;
        ;;
    *)
        usage;
        ;;
esac
}
waitUntil () {
            echo -n "Wait until state is $1"
            while [ "$(getState)" != "$1" ]; do
                echo -n "."
                sleep 1
            done
        echo
	}
    
    
      getState () {
            aws elb describe-instance-health \
                --load-balancer-name $lbname \
                --instance $instanceids | jq '.InstanceStates[].State' -r
        }
        
        
echo "Registering"
        register () {
            aws elb register-instances-with-load-balancer \
                --load-balancer-name $lbname \
                --instance $instanceids | jq .
        }
        
        
        echo "De-Registering"
         deregister () {
        aws elb deregister-instances-from-load-balancer \
            --load-balancer-name $lbname \
            --instance $InstanceID | jq .
        }
        
perform() {

echo "Enter Region"
read region
export AWS_DEFAULT_REGION="$region"
    echo "1. Add Instance"
    echo "2. Remove Instance"
    read input
    
    echo "Enter Load Balancer  Name"
    echo 
    aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[].LoadBalancerName'
    echo
    read lbname


    if [ $input == "1" ]; then

echo "Dispatcher instances inside the selected Load Balancer"
echo
        aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'
echo
	echo "Provide the instance-id Of Instance to Add"
    echo    
        aws ec2 describe-instances |jq -r '.Reservations[].Instances[] | [.InstanceId, .ClientToken]| @json'
        echo
        listinstance=`aws ec2 describe-instances |jq -r '.Reservations[].Instances[].InstanceId'`
      
    echo $listinstance 
    
    while read instanceids
        do
		for i in ${listinstance[@]}
		do
			echo $i
        		if [ $instanceids != $i ]; then
        		echo "Instance id is innorrect.. Try Again.."
                read instanceids
       	 		fi
		done
    	done
    echo "Checking Status of the instance"


echo "Instance ${instanceids} is $(getState)"
       if [ "$(getState)" == "OutOfService" ]; then
            register
            
            waitUntil "InService"
            lburl=`aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].DNSName'`
            curl $lburl &
        sleep 1
        fi
        if [ "$(getState)" == "InService" ]; then
            echo "Instance inside the Load Balancer $lbname"
            exit 1
        fi
set -x
    elif [ $input == "2" ]; then

echo $lbname    
        echo "Instance in selected ELB"
        aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'
        echo "Provide the Instance-Id"
        read InstanceID
   
   
   echo "Instance ${InstanceID} is $(getState)"


        if [ "$(getState)" == "OutOfService" ]; then
            deregister
            
            waitUntil "OutOfService"
            lburl=`aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].DNSName'`
            curl $lburl &
        sleep 1
        fi
        if [ "$(getState)" == "InService" ]; then
            deregister
            
            waitUntil "OutOfService"
            fi
	fi
            
}
set +x
main "$@"
