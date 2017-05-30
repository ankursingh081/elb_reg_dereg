#!/bin/bash
 
set -e

SELF="$(basename $0)"
TMP_CLOUDWATCH_JSON="/tmp/${SELF}.json";
START="$(date --date '-5 minutes')"; 
END="$(date)";

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



perform() {
    echo "1. Add Instance"
    echo "2. Remove Instance"
    read $input
    
    echo "Enter Load Balancer  Name"
    aws elb describe-load-balancer
    read $lbname


    if [ $input==1 ]; then
        echo "Provide the instance id Of Instance to Add"
        read $instanceids
    
        getState () {
            aws elb describe-instance-health \
                --load-balancer-name $lbname \
                --instance $instanceids | jq '.InstanceStates[0].State' -r
        }

        register () {
            aws elb register-instances-with-load-balancer \
                --load-balancer-name $lbname \
                --instance $instanceids | jq .
        }
    
        if [ "$(getState)" == "OutOfService" ]; then
            register >> /dev/null
        fi

        waitUntil "InService"

        lburl = aws elb describe-load-balancers --load-balancer-name $lbname | jq -r `.LoadBalancerDescriptions[].DNSName`
    
        curl $lburl &
        sleep 1
    fi
    
    if [ $input==2 ]; then
    
        echo "Instance in selected ELB"
        aws elb describe-load-balancers --load-balancer-name $lbname | jq -r `.LoadBalancerDescriptions[].Instances[].Instanceid`
        echo "Provide the Instance-Id"
        read $InstanceID
        
        deregister () {
        aws elb deregister-instances-from-load-balancer \
            --load-balancer-name $lbname \
            --instance $InstanceID | jq .
        }

    deregister >> /dev/null

    waitUntil "OutOfService"
	fi
}
