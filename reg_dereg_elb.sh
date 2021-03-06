#!/bin/bash
 
set -e
unset AWS_DEFAULT_PROFILE
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
    --perform )
        perform;
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
        register () {
            aws elb register-instances-with-load-balancer \
                --load-balancer-name $lbname \
                --instance $instanceids | jq .
        }
         deregister () {
        aws elb deregister-instances-from-load-balancer \
            --load-balancer-name $lbname \
            --instance $instanceids | jq .
        }
        
perform() {
echo "Enter your profile"
read profile
if ! grep -q "^\[$profile\]$" ${HOME}/.aws/config ; then
echo "Invalid Profile. Try Again"
exit
fi
export AWS_DEFAULT_PROFILE="$profile"

echo "Enter Region"
read region
#declare -a list_region=`aws ec2 describe-regions| jq -r '.Regions[].RegionName'`
#echo "$list_region" | grep -Fxe "$region"

export AWS_DEFAULT_REGION="$region"
echo "$AWS_DEFAULT_REGION"
#echo "Enter your profile"
#read profile
#if ! grep -q "^\[$profile\]$" ${HOME}/.aws/config ; then
#echo "Invalid Profile. Try Again"
#exit
#fi
export AWS_DEFAULT_PROFILE="$profile"
export AWS_CONFIG_FILE=${HOME}/.aws/config
echo "$AWS_CONFIG_FILE"
echo "$AWS_DEFAULT_PROFILE"
    echo "1. Add Instance"
    echo "2. Remove Instance"
    read input
    echo "Enter Load Balancer Name"
    aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[].LoadBalancerName'
    echo
    read lbname

    if [ $input == "1" ]; then

echo "Dispatcher instances inside the selected Load Balancer"
echo
disp_list=`aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'`
if [ "$disp_list" == " " ]; then
echo "Load Balancer is Empty"
else
aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'
fi
echo
	echo "Provide the instance-id Of Instance to Add"
    echo    
        aws ec2 describe-instances |jq -r '.Reservations[].Instances[] | [.InstanceId, .ClientToken]| @json'
        echo
declare -a listinstance=`aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceId'`
while read -r instanceids;
do        
#echo "$listinstance" | grep -Fxe "$instanceids"
set -x
if ! grep -c -w "$instanceids" <<< "$listinstance"; then
#if [ "$?" == "0" ]; then
echo "Instance does not Exist. Try Again..."
break
#else
#echo "Instance not available... Try Again "
fi
done
set +x
echo "Registering Instance $instanceids" 
register >>/dev/null
sleep 1
echo "Checking Status of the instance"
echo
#echo "Instance ${instanceids} is $(getstatee)"
       if [ "$(getState)" == "OutOfService" ]; then
#waitUntil "InService"
aws elb describe-instance-health --load-balancer-name $lbname | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'
       elif [ "$(getState)" == "InService" ]; then
            echo "Instance inside the Load Balancer $lbname"
echo "Instance status inside ELB" 
aws elb describe-instance-health --load-balancer-name $lbname | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'

            exit 1
        fi
    elif [ $input == "2" ]; then
        echo "Instance in selected ELB"
        aws elb describe-load-balancers --load-balancer-name $lbname | jq -r '.LoadBalancerDescriptions[].Instances[].InstanceId'
        echo "Provide the Instance-Id"
        read instanceids
   
   
   echo "Instance ${instanceids} is $(getState)"
echo "Removing"

        if [ "$(getState)" == "OutOfService" ]; then
            deregister >>/dev/null
      elif [ "$(getState)" == "InService" ]; then
            deregister >> /dev/null
            fi
echo "Instance status inside ELB " 
aws elb describe-instance-health --load-balancer-name $lbname | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'
	else
exit
fi
}
main "$@"
