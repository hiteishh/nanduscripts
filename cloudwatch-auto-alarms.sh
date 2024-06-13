#!/bin/bash

# Configurable parameters

INSTANCE_IDS=("i-0ab46622c5b842cfb" "i-0485e3d7de5a0f6b7" "i-06f3d0f5baa249c51" "i-0bb01a161d07155a4" "i-019e1f82fb9d38085" "i-0d1ec469357ac4e65" "i-05da14d57923591b4" "i-0c7052923098d588d" "i-05ecb807996545728" "i-0a343a2b3d365e4d7" "i-051543536aced523f" "i-0527aecf842ffdb9e")


# Add more instance IDs as needed
CPU_UTILIZATION_THRESHOLD_PERCENT=80
STATUS_CHECK_THRESHOLD=0.99
ROOT_VOLUME_THRESHOLD_PERCENT=80
DATA_VOLUME_PATH="/data"  # Adjust if necessary
DATA_VOLUME_THRESHOLD_PERCENT=80
ROOT_VOLUME_DEVICE="nvme0n1p1"  # Adjust if necessary
DATA_VOLUME_DEVICE="nvme1n1"
ROOT_VOLUME_FSTYPE="xfs"  # Adjust if necessary
ALARM_NAME_PREFIX="Dev"
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:769294742237:aws_infra_dev"

# Loop through each instance ID
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do

# Get instance name for the instance
  INSTANCE_NAME=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' --output text)


  # Get ImageId for the instance
  IMAGE_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[*].Instances[*].ImageId' --output text)
  # GET instance type
  INSTANCE_TYPE=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[*].Instances[*].InstanceType' --output text)
  # Create CPU utilization alarm
  aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_NAME_PREFIX}-CPU-alert-${INSTANCE_NAME}" \
    --alarm-description "Alarm for CPU Utilization > ${CPU_UTILIZATION_THRESHOLD_PERCENT}% on instance ${INSTANCE_NAME} (ImageId: ${IMAGE_ID})" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold ${CPU_UTILIZATION_THRESHOLD_PERCENT} \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --evaluation-periods 2 \
    --alarm-actions ${SNS_TOPIC_ARN}

  # Create status check failed alarm
  aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_NAME_PREFIX}-Status-Check-Failed-${INSTANCE_NAME}" \
    --alarm-description "Alarm for Status Check Failed on instance ${INSTANCE_NAME} (ImageId: ${IMAGE_ID})" \
    --metric-name StatusCheckFailed \
    --namespace AWS/EC2 \
    --statistic Maximum \
    --period 300 \
    --threshold ${STATUS_CHECK_THRESHOLD} \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --evaluation-periods 2 \
    --alarm-actions ${SNS_TOPIC_ARN}

  # Create alarm for root volume
  aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_NAME_PREFIX}-Root-Volume-${INSTANCE_NAME}" \
    --alarm-description "Alarm for Root Volume Utilization on instance ${INSTANCE_NAME} (ImageId: ${IMAGE_ID})" \
    --metric-name disk_used_percent \
    --namespace CWAgent \
    --statistic Average \
    --period 300 \
    --threshold ${ROOT_VOLUME_THRESHOLD_PERCENT} \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" "Name=path,Value='/'" "Name=ImageId,Value=${IMAGE_ID}" "Name=device,Value=${ROOT_VOLUME_DEVICE}" "Name=fstype,Value=${ROOT_VOLUME_FSTYPE}" "Name=InstanceType,Value=${INSTANCE_TYPE}" \
    --evaluation-periods 2 \
    --alarm-actions ${SNS_TOPIC_ARN}

  # Create alarm for data volume (if applicable)

DATA_VOLUME_ATTACHED=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=${INSTANCE_ID} --query "Volumes[*].{ID:VolumeId}" --output text)

  if [ -n "${DATA_VOLUME_ATTACHED}" != "None" ] && [ -n "${DATA_VOLUME_ATTACHED}" ];
  then
    echo "data volume attached for ${INSTANCE_NAME}"
    aws cloudwatch put-metric-alarm \
      --alarm-name "${ALARM_NAME_PREFIX}-Data-Volume-${INSTANCE_NAME}" \
      --alarm-description "Alarm for Data Volume Utilization on instance ${INSTANCE_NAME} (ImageId: ${IMAGE_ID})" \
      --metric-name disk_used_percent \
      --namespace CWAgent \
      --statistic Average \
      --period 300 \
      --threshold ${DATA_VOLUME_THRESHOLD_PERCENT} \
      --comparison-operator GreaterThanOrEqualToThreshold \
      --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" "Name=path,Value=${DATA_VOLUME_PATH}" "Name=ImageId,Value=${IMAGE_ID}" "Name=InstanceType,Value=${INSTANCE_TYPE}" "Name=device,Value=${DATA_VOLUME_DEVICE}" "Name=fstype,Value=${ROOT_VOLUME_FSTYPE}" \
      --evaluation-periods 2 \
      --alarm-actions ${SNS_TOPIC_ARN}
 else
   echo "Data volume not attached for ${INSTANCE_NAME}"
 fi
done
