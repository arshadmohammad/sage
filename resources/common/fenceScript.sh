echo `date` "Fence script is called with following arguments" >> fenceLog.log
for i in $*; do 
   echo $i >> fenceLog.log
done
echo "Dummy fencing done" >> fenceLog.log