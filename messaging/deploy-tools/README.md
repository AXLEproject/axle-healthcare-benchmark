## PREPARE ##

Steps to perform locally

* clone axle-healthcare-benchmark
* setup AWS credentials in ~/.aws/axle.pem
* make axle password available in `axle-healthcare-benchmark/cda-generator/axle-generator-password.txt` (do not commit)
* `cp ~/.ssh/config ~/.ssh/config.bak`

## START GROUP ##

    cd axle-healthcare-benchmark/messaging/deploy-tools
    ./start-group.sh mtest 2>&1 > log.txt &

## WATCH PROGRESS ##

Initially:
    tail -f log.txt

Once other processes have started:
    tail -f *.log

## TERMINATE GROUP ##

During the scripts, the local ssh.config and known hosts will be extended with new host information. Both need to be cleaned before starting a group with the same groupname, which will happen a lot during testing.

    ./terminate-group.sh mtest ; grep -v amazonaws ~/.ssh/known_hosts > /tmp/ff ; mv /tmp/ff ~/.ssh/known_hosts ; cp ~/.ssh/config.bak ~/.ssh/config


## LOG IN ##

To avoid having to lookup IP numbers of the freshly installed machines, use the following script, called shax (ssh axle):

* usage: `shax <groupname> <instancename>`
* example: `shax mtest loader-1`

    #!/bin/bash
    IP=`euca-describe-instances --filter instance-state-name=running --filter tag:groupname=$1 --filter tag:instancename=$2 | tr '\n' ' ' | awk '{print $7}'`
    TYPE=`expr match "$2" '\(^[a-zA-Z]*\)'`
    if [ "x$TYPE" = "xbroker" ]
    then
        ssh -L 15672:127.0.0.1:15672 -o StrictHostKeyChecking=no -i ~/.aws/axle.pem ec2-user@$IP
    else
        ssh -o StrictHostKeyChecking=no -i ~/.aws/axle.pem ec2-user@$IP
    fi
