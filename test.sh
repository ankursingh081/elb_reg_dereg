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
waitUntil ()
{ 
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
                --instance $instanceids | jq '.InstanceStates[0].State' -r
        }
       getstatee () {
		aws elb describe-instance-health --load-balancer-name $lbname --instance $instanceids
		
	} 
#       echo "$(getstatee)"
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
echo $USER
echo "Enter Region"
read region
export AWS_DEFAULT_REGION="$region"
echo "$AWS_DEFAULT_REGION"
    echo "1. Add Instance"
    echo "2. Remove Instance"
    read input
   echo 
    echo "Enter Load Balancer  Name"
    echo "$AWS_DEFAULT_REGION" 
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
#aws ec2 describe-instances |jq -r '.Reservations[].Instances[].InstanceId' > "${listinstance}"
listinstance=`aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceId'`
#    echo "$listinstance"
#list=`aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId]'`
#echo "$list"
while read -r instanceids;
do        
#echo `aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceId'` | grep -F "$instanceids"
echo "$listinstance" | grep -Fxe "$instanceids"

echo "$?"
if [ "$?" == "0" ]; then
break
else
echo "Instance not available... Try Again "
fi
done
echo "Registering Instance $instanceids" 
register
sleep 1
#echo "$(register)"
echo "Checking Status of the instance"
#echo "Instance ${instanceids} is $(getstatee)"
       if [ "$(getState)" == "OutOfService" ]; then
            register
            
#            waitUntil "InService"
#            lburl=`aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].DNSName'`
#            curl $lburl &
aws elb describe-instance-health --load-balancer-name $lbname | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'
exit
        sleep 1
        
       elif [ "$(getState)" == "InService" ]; then
            echo "Instance inside the Load Balancer $lbname"
aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'
echo "Instance status inside ELB" 
aws elb describe-instance-health --load-balancer-name $lbname | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'

            exit 1
        fi
    elif [ $input == "2" ]; then

echo $lbname    
        echo "Instance in selected ELB"
        aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'
        echo "Provide the Instance-Id"
        read InstanceID
   
   
   echo "Instance ${InstanceID} is $(getState)"
echo "Removing..."

        if [ "$(getState)" == "OutOfService" ]; then
            deregister
            
#            waitUntil "OutOfService"
#            lburl=`aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].DNSName'`
#            curl $lburl &
        sleep 1
        elif [ "$(getState)" == "InService" ]; then
            deregister
            sleep 1
#            waitUntil "OutOfService"
            fi
echo "Instance status inside ELB " 
aws elb describe-instance-health --load-balancer-name $lbname | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'
	else
exit
fi
            


}
main "$@"
