#!/bin/bash
# 20140708 JG
# ebs_snap.sh - Creates & deletes EBS snapshots.

# !!! Requires the 'jq' package from apt !!!

# !!! Requires awscli 1.3.0 or later - ubuntu 14.04/apt will try to install
# 1.2.9.  Use pip instead !!!

# User-adjustable settings

# The source volume snapshots are taken from
VOLUME="vol-xxxxxxxx"
DESCRIPTION="my_desc"
NAME="MyName"
SPSENV="prod"
SPSPRODUCT="myproduct"
SPSUNIT="myunit"
SPSOWNER='myemail'
SPSHOURS="00:00-23:59

echo $HOME

# Non-user adjustable settings
DATE=$(date +%Y%m%d%H%M%S)
EPOCH=$(date +%s)
NEXTWEEK=$(date +%s --date='TZ="UTC" next Week')
export PATH=$PATH:/var/lib/gems/1.8/bin:/usr/local/bin

AWS_DEFAULT_REGION='us-east-1'
AWS_DEFAULT_OUTPUT='json'
IAMROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
CREDENTIALS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAMROLE)
AWS_ACCESS_KEY=$(echo $CREDENTIALS | ruby -e " require 'rubygems'; require 'json'; puts JSON[STDIN.read]['AccessKeyId'];")
AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | ruby -e " require 'rubygems'; require 'json'; puts JSON[STDIN.read]['SecretAccessKey'];")
AWS_SECURITY_TOKEN=$(echo $CREDENTIALS | ruby -e "require 'rubygems'; require 'json'; puts JSON[STDIN.read]['Token'];")

export AWS_DEFAULT_REGION AWS_DEFAULT_OUTPUT IAMROLE CREDENTIALS AWS_ACCESS_KEY AWS_SECRET_ACCESS_KEY AWS_SECURITY_TOKEN

# Create new snapshot
aws ec2 create-snapshot --volume-id $VOLUME --description "$DESCRIPTION"-"$DATE" > ~/bin/snap_out.json
SNAPID=$(jq -r '.SnapshotId' ~/bin/snap_out.json)
aws ec2 create-tags --resources $SNAPID --tags Key=Name,Value="$NAME" Key=sps:env,Value="$SPSENV" Key=sps:product,Value="$SPSPRODUCT" Key=sps:unit,Value="$SPSUNIT" Key=sps:owner,Value="$SPSOWNER" Key=sps:hours_of_operation,Value="$SPSHOURS" Key=expiration,Value=$NEXTWEEK Key=created,Value=$EPOCH
echo "Created snapshot $SNAPID"

# Delete snapshots older than a week
aws ec2 describe-snapshots --filters Name=volume-id,Values=$VOLUME Name=tag-key,Values=expiration --query 'Snapshots[].[SnapshotId, Tags[?Key==`expiration`].Value]' > ~/bin/snaplist.json
TIFS="$IFS"
IFS='+'
SNAPSHOTS=( $(jq -M -c -r '.' ~/bin/snaplist.json | sed -e 's/\]\],/+/g' -e 's/\[\|\]//g' -e 's/\"//g') )

for SNAPSHOT in ${SNAPSHOTS[@]} ; do
	IFS=','
	SSPROPS=( ${SNAPSHOT[@]} )
	DSNAPID=${SSPROPS[0]}
	EXPIRETIME=${SSPROPS[1]}
	if [ "$EXPIRETIME" -lt "$EPOCH" ] ; then
		echo "Deleting snapshot $DSNAPID"
		aws ec2 delete-snapshot --snapshot-id $DSNAPID
	fi
done

