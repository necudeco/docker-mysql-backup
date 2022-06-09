#!/bin/bash

if [[ $1 = "" ]]; then
	echo "You need include database container name and S3 Bucket"
	echo "bash backup.sh CONTAINERNAME BUCKETNAME"
	exit 0
fi


S3BUCKET="$2"
CONTAINER="$1"
fecha=` date +%Y%m%d`


IGNORE_DB=("Database" "information_schema" "mysql" "performance_schema" "sys")

echo "Backuping $(date)" >> /tmp/cron

cd

databases=$(docker exec -i $CONTAINER  mysql -e 'show databases;'  )

mkdir -p backup/$fecha

fechaold=`date -d "15 day ago" +%Y%m%d`

rm backup/$fechaold -R

echo ""

for db in $databases; do
	echo -n "DATABASE $db "

	CONTINUE=false

	for ignore in "${IGNORE_DB[@]}"; do
		if [ "$ignore" = "$db" ]; then

		CONTINUE=true
		break;

		fi
	done

	if [ "$CONTINUE" = true ] ; then
		echo "IGNORING ";
		continue;
	fi

	if [ -f backup/$db.ignore ]; then
		continue;
	fi 

	echo "BACKUPING"

	if [ -f backup/$db.clear ]; then
		mysql $db < backup/$db.clear
	fi
	
	docker exec -i $CONTAINER mysqldump --routines $db > backup/$fecha/$db.sql
	tar -czf backup/$fecha/$db.tar.gz -C backup/$fecha $db.sql
	rm backup/$fecha/$db.sql
done

cd backup/

echo ""
echo "Uploading"

/usr/bin/aws s3 cp --recursive ${fecha}/ s3://${S3BUCKET}/${fecha}/
