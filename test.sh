#!/bin/sh

#Nombre de VPC

CurPath=`pwd`
TmpDir="$CurPath/Data"
VPCNames="$TmpDir/VPCNames.txt"
VPCNamesId="$TmpDir/VPCNamesId.txt"
VPCMachinesStatus="$TmpDir/VPCStatus.txt"
VPCSG="$TmpDir/VPC-SG.txt"
IAMUsers="$TmpDir/Users.txt"


SGroups="$TmpDir/VPC-VATS-SG.txt"

#Get list of users
if [ -f "$IAMUsers" ]
then
	rm "$IAMUsers"
	touch "$IAMUsers"
fi
lUsers=`aws iam list-users --query 'Users[*].[UserName,Arn,PasswordLastUsed]' | sed 's/\t/,/g' | sort -t"," -k3`
echo "$lUsers" >>"$IAMUsers"

