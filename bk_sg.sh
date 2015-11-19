#!/bin/sh

# Backup Amazon Security group in json format before delete
#

if [ "$#" -eq 0 ]
then
   echo "debe pasar como parametro el id del security-group"
   exit 1
fi

#for each SG export it at json with name
for var in "$@"
do
	GRName=`aws ec2 describe-security-groups --group-ids $var --query 'SecurityGroups[*].[GroupName]'`
	if [ "x$GRName" != "x" ]
	then
		Exported="SG[$GRName]-[$var].json"
		if [ -f "$Exported" ]
		then
   			rm "$Exported"
		fi
		SGroup=`aws ec2 describe-security-groups --group-ids $var --output json`
		echo $SGroup > $Exported
	else
		echo "Err--> no se ha encontrado el security group asociado a $var."
	fi
done