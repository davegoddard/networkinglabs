while true
do
    date >> cpustats-$(hostname)..log
    top -b -n 1 -c 1 | grep Cpu | head -1  >> cpustats-$(hostname)..log
    sleep 1
done