#!/bin/bash
aws elb describe-instance-health --load-balancer-name ankur-50-test | jq -r '["       ID","        State"], ["     --------","        ------"], (.InstanceStates[]|[.InstanceId, .State]) | @tsv'
