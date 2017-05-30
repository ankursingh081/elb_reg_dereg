#!/bin/bash
 
set -e

SELF="$(basename $0)"
TMP_CLOUDWATCH_JSON="/tmp/${SELF}.json";
START="$(date --date '-5 minutes')"; 
END="$(date)";

usage() {
    cat <<USAGE
Usage: $SELF [ --show | --put-metrics ]
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
        cloudWatchPut;
        ;;
    --show )
        loadData;
        ;;
    *)
        usage;
        ;;
esac
}

genAgregatedMetricData() {
    NAME="$1"
    METRIC="$2"
    cat \
    | jq -r '.AvailabilityZones[]' \
    | while read AZ; do 
        echo >&2 "   $NAME ($AZ) $METRIC ..."
        aws cloudwatch get-metric-statistics \
            --namespace AWS/ELB \
            --metric-name "$METRIC" \
            --dimensions '[{"Name":"LoadBalancerName","Value":"'$NAME'"},{"Name":"AvailabilityZone","Value":"'$AZ'"}]' \
            --start-time "$START" \
            --end-time "$END" \
            --period 60 \
            --statistics Maximum \
        | jq -r --arg AZ "$AZ" '[.Datapoints[] | .Maximum] | (max|@json)'
    done \
    | jq -s -r \
        --arg NAME "$NAME" \
        --arg METRIC "$METRIC" \
        ' add | {
            Value:.,
            MetricName:$METRIC,
            Unit:"Count",
            Dimensions:[{Name:"LoadBalancerName",Value:$NAME}]
        }'
}

loadData() {
    echo >&2 "loading data..."
    aws elb describe-load-balancers \
     | jq -r ' 
        .LoadBalancerDescriptions[] 
        | {LoadBalancerName, AvailabilityZones} 
        | (.|@json) ' \
     | while read json; do
        NAME=$(echo "$json" | jq -r .LoadBalancerName); 
        echo "$json" | genAgregatedMetricData "$NAME" "HealthyHostCount"
        echo "$json" | genAgregatedMetricData "$NAME" "UnHealthyHostCount"
    done \
    | jq -s '.' \
    | tee $TMP_CLOUDWATCH_JSON
}

cloudWatchPut() {
    aws cloudwatch put-metric-data \
        --namespace TDA/ELB \
        --metric-data file://$TMP_CLOUDWATCH_JSON
}

main "$@"
