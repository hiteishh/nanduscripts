#!/bin/bash

# List of remote instances (replace with actual IPs or hostnames)
instance_1="10.60.30.219"  #prometheus
instance_2="10.60.31.139"  #elk stack
instance_3="10.60.32.217"  #rmq
instance_4="10.60.28.152"  #hazelcast
instance_5="10.60.24.207"  #mongo-ops-manager svc

# Services for each instance
services_1=("prometheus.service")
services_2=("elasticsearch.service" "kibana.service")
services_3=("rabbitmq-server.service")
services_4=("hazelcast.service")
services_5=("mongod.service")

# Common services for all instances
common_services=("amazon-cloudwatch-agent" "node_exporter.service")

# Function to check service status on a remote instance
check_service_status() {
    local instance=$1
    local service=$2
    ssh -o BatchMode=yes -o ConnectTimeout=5 $instance "sudo systemctl is-active $service" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$instance: $service is running"
    else
        echo "$instance: $service is inactive or not found"
    fi
}

# Function to check all services for a given instance
check_all_services() {
    local instance=$1
    local services=("${!2}")
    echo "Checking services on $instance..."
    for service in "${services[@]}"; do
        check_service_status $instance $service
    done
    for service in "${common_services[@]}"; do
        check_service_status $instance $service
    done
    echo ""
}

# Check services for each instance
check_all_services $instance_1 services_1[@]
check_all_services $instance_2 services_2[@]
check_all_services $instance_3 services_3[@]
check_all_services $instance_4 services_4[@]
check_all_services $instance_5 services_5[@]
