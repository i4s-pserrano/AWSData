#!/bin/sh

#Nombre de VPC

CurPath=`pwd`
TmpDir="$CurPath/.Data"
VPCNames="$TmpDir/VPCNames.txt"
VPCNamesId="$TmpDir/VPCNamesId.txt"
VPCMachinesStatus="$TmpDir/VPCMachineStatus.txt"
SGroups="$TmpDir/SGroups.txt"
VPCSG="$TmpDir/VPC-SG.txt"
IAMUsers="$TmpDir/Users.txt"
tmpError="$TmpDir/Errors.txt"


debug=0

if [ -f "$tmpError" ]
then
	rm "$tmpError"
	touch "$tmpError"
fi

echo ""
echo "Working on:"
echo "--> VPC Names"
if [ ! -d "$TmpDir" ]; then
  mkdir "$TmpDir"
fi
aws ec2 describe-vpcs --query 'Vpcs[*].[Tags[?Key==`Name`].Value[]]' > "$VPCNames"

## get more info about VPC
echo "--> VPC Names, Vpcid"
if [ -f "$VPCNamesId" ]
then
   rm "$VPCNamesId"
fi
IFS=","
while read VPCName
do
	VpcId=`aws ec2 describe-vpcs --filter Name="tag-value",Values=$VPCName  --query 'Vpcs[*].[VpcId]'`
	echo "$VPCName,$VpcId" >> $VPCNamesId
	if [ "$debug" -eq 1 ]
	then
		echo "DEBUG - VPCName - VpcId"
		echo "$VPCName,$VpcId"
	fi
done<$VPCNames

#for each VPC -GetListOfMachines
echo "--> VPC MachineList with name"
IFS=","
rm -rf "$TmpDir/VPC-*" >/dev/null 2>/dev/null
echo "--> VPC MachineList without name"
while read VPCName VpcId
do
	VPCMachinelist="$TmpDir/VPC-`echo $VPCName`-Instances.txt"
	if [ -f "$VPCMachinelist" ]
	then
   		rm "$VPCMachinelist"
	fi
	InstanceInfo=`aws ec2 describe-instances --filter Name="vpc-id",Values="$VpcId" --query 'Reservations[*].[Instances[*].[InstanceId,ImageId,PublicIpAddress,PrivateIpAddress,KeyName,InstanceType,State.Name,Attachment.DeleteOnTermination,Monitoring.State,SubnetId,Architecture]]' |  sed 's/\t/,/g'`
	echo "$InstanceInfo" >> $VPCMachinelist
	if [ "$debug" -eq 1 ]
	then
		echo "DEBUG - MachineList"
		echo "$InstanceInfo"
	fi
done<$VPCNamesId
#GetMachineName from Each machine
IFS=","
while read VPCName VpcId
do
	VPCMachinelist="$TmpDir/VPC-`echo $VPCName`-Instances.txt"
	VPCMachineNamelist="$TmpDir/VPC-`echo $VPCName`-InstancesData.txt"
	if [ -f "$VPCMachineNamelist" ]
	then
   		rm "$VPCMachineNamelist"
   		echo "Name,InstanceId,ImageId,PublicIpAddress,PrivateIpAddress,KeyName,InstanceType,State.Name,Attachment.DeleteOnTermination,Monitoring.State,SubnetId,Architecture" > "$VPCMachineNamelist"
	fi
	while read InstanceId ImageId PublicIpAddress PrivateIpAddress KeyName InstanceType StateName AttachmentDeleteOnTermination MonitoringState SubnetId Architecture
	do  
		InstanceName=`aws ec2 describe-instances --instance-ids $InstanceId --query 'Reservations[*].[Instances[*].[Tags[?Key==\`Name\`].Value[]]]'`
		echo "$InstanceName,$InstanceId,$ImageId,$PublicIpAddress,$PrivateIpAddress,$KeyName,$InstanceType,$StateName,$AttachmentDeleteOnTermination,$MonitoringState,$SubnetId,$Architecture" >> $VPCMachineNamelist
		if [ "$debug" -eq 1 ]
		then
			echo "DEBUG - MachineListData"
			echo "$InstanceName,$InstanceId,$ImageId,$PublicIpAddress,$PrivateIpAddress,$KeyName,$InstanceType,$StateName,$AttachmentDeleteOnTermination,$MonitoringState,$SubnetId,$Architecture"
		fi
	done<$VPCMachinelist
	#order file
	cat $VPCMachineNamelist | sort -t"," -k8 > $VPCMachineNamelist".tmp"
	cat $VPCMachineNamelist".tmp" > $VPCMachineNamelist
	if [ -f "$VPCMachinelist" ]
	then
		rm "$VPCMachinelist"
		rm -rf $VPCMachineNamelist".tmp"
	fi
done<$VPCNamesId

#Instances Running, stopped other by VPC
echo "--> VPC Instances running/stopped/others"
if [ -f "$VPCMachinesStatus" ]
then
	rm "$VPCMachinesStatus"
	echo "VPC \t STARTED \t STOPPED \t OTHER\n" >> "$VPCMachinesStatus"
fi
while read VPCName
do
	VPCMachineNamelist="$TmpDir/VPC-`echo $VPCName`-InstancesData.txt"
	running=`cat "$VPCMachineNamelist" | grep "running" | wc -l`
	stopped=`cat "$VPCMachineNamelist" | grep "stopped" | wc -l`
	other=`cat "$VPCMachineNamelist" | grep -v 'running|stopped' | wc -l`
	printf "$VPCName \t $running \t $stopped \t $other\n" >> "$VPCMachinesStatus"
done<$VPCNames

#SGroups on each VPC
echo "--> VPC SecurityGroups"
if [ -f "$VPCSG" ]
then
	rm "$VPCSG"
	echo "#VPCName,VpcId,GroupName,GroupId,Description" > "$VPCSG"
fi
IFS=","
while read VPCName VpcId
do  
    SGroups="$TmpDir/VPC-`echo $VPCName`-SG.txt"
    if [ -f "$SGroups" ]
	then
		rm "$SGroups"
	fi
	SGList=`aws ec2 describe-security-groups --filter Name="vpc-id",Values=$VpcId --query 'SecurityGroups[*].[GroupName,GroupId,Description]'`
	echo $SGList | sed 's/\t/,/g' | sort -t"," -k1 > $SGroups
	while read GroupName GroupId Description
	do
		echo "$VPCName,$VpcId,$GroupName,$GroupId,$Description" | sort -t"," -k2,4 >> "$VPCSG"
	done<$SGroups
done<$VPCNamesId


#Machines covered by SG
echo "--> VPC Machines covered by SGroup"
SGMachines="$TmpDir/SG-MachineList.txt"
SGWithoutMachines="$TmpDir/SG-WithoutMachineList.txt"
SGWithoutMachinesCSV="$TmpDir/SG-WithoutMachineList.csv"
if [ -f "$SGMachines" ]
then
	rm "$SGMachines"
	touch "$SGMachines"
fi
if [ -f "$SGWithoutMachines" ]
then
	rm "$SGWithoutMachines"
	touch "$SGWithoutMachines"
fi
if [ -f "$SGWithoutMachinesCSV" ]
then
	rm "$SGWithoutMachinesCSV"
	touch "$SGWithoutMachinesCSV"
	echo "#VPCName,VpcId,SGroupName,SGroupId,SDescription" >> $SGWithoutMachinesCSV
fi
IFS=","
while read VPCName VpcId
do  
    SGroups="$TmpDir/VPC-`echo $VPCName`-SG.txt"
	while read GroupName GroupId Description
	do 
		MList=`aws ec2 describe-instances --filter Name="instance.group-id",Values="$GroupId" --query 'Reservations[*].[Instances[*].[InstanceId]]'`
		number=`echo -n "$MList" | tr -d " " | wc -l`
		if [ $number -gt 0 ] 
		then

			echo "[$number]-->[GroupName:$GroupName]-->[GroupId:$GroupId]-->[$Description]'" >> $SGMachines
			echo "$MList" >> $SGMachines
		else
			#echo "[$number]-->[GroupName:$GroupName]-->[GroupId:$GroupId]-->[$Description]'" >> $SGWithoutMachines
			Linea=`cat "$VPCSG" | grep "$GroupId"`
			lnumber=`echo $Linea | wc -l`
			if [ $lnumber -eq 1 ]
			then
			echo "$Linea" | while read lVPCName lVpcId lGroupName lGroupId lDescription
						do
							echo "[$number]-->[VPCName:$lVPCName]-->[VpcId:$lVpcId]-->[GroupName:$GroupName]-->[GroupId:$GroupId]-->[$Description]'" >> $SGWithoutMachines
							echo "$lVPCName,$lVpcId,$GroupName,$GroupId,$Description" >> $SGWithoutMachinesCSV
						done
			else
				echo "Error al buscar SGroup --> este SGroup esta en mas de una VPC [GroupName:$lGroupName][GroupId:$lGroupId]" >> "$tmpError"
			fi
		fi
	done<$SGroups
done<$VPCNamesId

#Get list of users
if [ -f "$IAMUsers" ]
then
	rm "$IAMUsers"
	touch "$IAMUsers"
fi
lUsers=`aws iam list-users --query 'Users[*].[UserName,Arn]'`

echo
echo "Status"
cat $VPCMachinesStatus
echo ""
echo "DONE"
