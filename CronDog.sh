#! /bin/ksh
#
# A watchdog program to limit the elapsed time of the worker shell script
# to avoid hanging processes that can pile up if worker runs under cron
#


export PATH=/usr/bin:/usr/sbin:/bin


#
# default time limit is 60 seconds
#
timelimit=${1:-60}

B
worker="${0%/*}/check-worker.ksh"
worker_name=${worker##*/}
worker_name=${worker_name%.*}
if [ ! -f $worker ]; then
    echo "Error. \"$worker\" cannot be found"
    exit 1
fi
if [ ! -x $worker ]; then
    echo "Error. \"$worker\" is not executable"
    exit 2
fi


watchdog()
{
    sleep 1; # wait for the worker to start
    while [ $timelimit -gt 0 ]
    do
        # pgrep is available since 5.8, else use ps -ef | grep -v grep | grep $worker_name
        jobid=`pgrep $worker_name`
        if [ $? -eq 1 ]; then
            break
        else
            sleep 1
        fi
        ((timelimit-=1))
    done
    if [ $timelimit -eq 0 ]; then
        # kill worker + child processes
        ptree $jobid | awk '$1=='$jobid'{start=1}start==1{print $1}' | while read pid
            do
                kill -TERM "$pid" > /dev/null 2>&1
            done
    fi
}


#
# start the watchdog before the worker
#
watchdog &


tmpfile="/tmp/.$work_name.$$"
$worker > $tmpfile 2>&1 &
worker_id=$!
wait $worker_id > /dev/null 2>&1
rc=$?


if [ $rc -ne 0 ]; then
    # replace this line to do whatever you want, send email, sms, logger....
    #
    # echo .... | mailx someone@somewhere.com

    details=`cat $tmpfile 2>/dev/null`
    echo "Exit status=$rc. There is a problem with the server '`hostname`' - $details"
fi


rm -f $tmpfile
