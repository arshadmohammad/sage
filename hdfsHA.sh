source commonScript.sh
#Modify this if want take custome location as base directory
BASE_DIR=`getBaseDir`

INSTALLATION_BASE_DIR=$BASE_DIR/hadoop
RESOURCE_DIR=$BASE_DIR/resources
HADOOP_RELEASE=$BASE_DIR/hadoop-2.7.2.tar.gz
NUMBER_OF_NAMENODE=2
NUMBER_OF_DATANODE=3
NUMBER_OF_JOURNALNODE=3

#Name node ports
NAMENODE_HTTP_ADDRESS_BASE=50070
NAMENODE_IPC_ADDRESS_BASE=9000
NAMENODE_JMX_PORT_BASE=5500
NAMENODE_DEBUG_PORT_BASE=4400

#Data node ports
DATANODE_HTTP_ADDRESS_BASE=50075
DATANODE_ADDRESS_BASE=50010
DATANODE_IPC_ADDRESS_BASE=50020
DATANODE_JMX_PORT_BASE=5510
DATANODE_DEBUG_PORT_BASE=4410

#Journal node ports
JOURNALNODE_IPC_ADDRESS_BASE=8485
JOURNALNODE_HTTP_ADDRESS_BASE=8480
JOURNALNODE_HTTPS_ADDRESS_BASE=8491
JOURNALNODEJMX_PORT_BASE=5540
JOURNALNODE_DEBUG_PORT_BASE=4450

#Miscellaneous ports
ZKFC_PORT_BASE=8019
ZK_CLIENT_PORT_BASE=2181

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances
THIS_MACHINE_IP=192.168.1.3
# is the release from hadoop branch-2
HADOOP2=true

install.hadoop()
{
  #Prepare installation directory structure
  
  if [ -d $INSTALLATION_BASE_DIR ]; then
	stop.hadoop
	rm -r $INSTALLATION_BASE_DIR
  fi
  mkdir $INSTALLATION_BASE_DIR
  mkdir $DATAS
  mkdir $INSTANCES    
  extract.hadoop
  configure.hadoop
}
extract.hadoop()
{
  extractModule "nameNode" $NUMBER_OF_NAMENODE
  extractModule "dataNode" $NUMBER_OF_DATANODE
  extractModule "journalNode" $NUMBER_OF_JOURNALNODE
}
configure.hadoop()
{
  configure.namenode
  configure.datanode
  configure.journalnode
}
start.hadoop()
{
  start.stop.journalnode start
  start.stop.namenode start
  start.stop.datanode start  
}
stop.hadoop()
{
  start.stop.datanode stop
  start.stop.namenode stop 
  start.stop.journalnode stop
}
extractModule()
{
  module=$1
  count=$2
  echo "Extracting $module"
  for (( i=1; i<=$count; i++ ))
  do
    #create module directory and extract release to this
    node_instance_dir=$INSTANCES/$module$i
    if [ -d $node_instance_dir ]; then
      rm -r $node_instance_dir
    fi    
    mkdir $node_instance_dir
    tar -mxf $HADOOP_RELEASE -C $node_instance_dir --strip-components 1 
    
    #create data dir
    data="Data"
    node_data_dir=$DATAS/$module$data$i
    if [ -d $node_data_dir ]; then
      rm -r $node_data_dir
    fi 
    mkdir $node_data_dir
  done
}
configure.namenode()
{
echo "Configure name node"
for (( i=1; i<=2; i++ ))
do
    node_instance_dir=$INSTANCES/nameNode$i
    node_data_dir=$DATAS/nameNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
    
	## common cofig for all config
    addXMLProperty $hdfs_site_xml "dfs.ha.namenode.id" "nn"$i
    name_node_rpc_port1=$(($NAMENODE_IPC_ADDRESS_BASE ))
    name_node_rpc_port2=$(($NAMENODE_IPC_ADDRESS_BASE + 1))   
    
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn1" "$THIS_MACHINE_IP:$name_node_rpc_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn2" "$THIS_MACHINE_IP:$name_node_rpc_port2"
    
    http_port1=$(($NAMENODE_HTTP_ADDRESS_BASE))
    http_port2=$(($NAMENODE_HTTP_ADDRESS_BASE + 1))
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn1" "0.0.0.0:$http_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn2" "0.0.0.0:$http_port2"
	#
	
    
    addXMLProperty $hdfs_site_xml "dfs.namenode.shared.edits.dir" "qjournal://$THIS_MACHINE_IP:$(($JOURNALNODE_IPC_ADDRESS_BASE));$THIS_MACHINE_IP:$(($JOURNALNODE_IPC_ADDRESS_BASE + 1));$THIS_MACHINE_IP:$(($JOURNALNODE_IPC_ADDRESS_BASE + 2))/mycluster"
    addXMLProperty $hdfs_site_xml "ha.zookeeper.quorum" "$THIS_MACHINE_IP:$(($ZK_CLIENT_PORT_BASE)),$THIS_MACHINE_IP:$(($ZK_CLIENT_PORT_BASE + 1)),$THIS_MACHINE_IP:$(($ZK_CLIENT_PORT_BASE + 2))"
    zkfc_port=$(($ZKFC_PORT_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.ha.zkfc.port" "$zkfc_port"
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir" 
     
    nameDir=$node_data_dir/name
    mkdir $nameDir
    addXMLProperty $hdfs_site_xml "dfs.namenode.name.dir" "$nameDir"    

    editDir=$node_data_dir/edit
    mkdir $editDir
    addXMLProperty $hdfs_site_xml "dfs.namenode.edits.dir" "$editDir"
     
    #Static configuration
    addAllXMLProperty $core_site_xml "core.properties"
    addAllXMLProperty $hdfs_site_xml "hdfs.properties"
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hadoop_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($NAMENODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="$HADOOP_NAMENODE_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    addProperty $hadoop_env "HADOOP_NAMENODE_OPTS" "\"$jmx_prop\""
	
    debug_port=$(($NAMENODE_DEBUG_PORT_BASE + $i - 1))
    debug_prop="\$HADOOP_NAMENODE_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port "
    addProperty $hadoop_env "HADOOP_NAMENODE_OPTS" "\"$debug_prop\""
done
}

configure.datanode()
{
echo "Configure data node"
for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
    node_instance_dir=$INSTANCES/dataNode$i
    node_data_dir=$DATAS/dataNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
	
	## common cofig for all config
    addXMLProperty $hdfs_site_xml "dfs.ha.namenode.id" "nn"$i
    name_node_rpc_port1=$(($NAMENODE_IPC_ADDRESS_BASE ))
    name_node_rpc_port2=$(($NAMENODE_IPC_ADDRESS_BASE + 1))   
    
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn1" "$THIS_MACHINE_IP:$name_node_rpc_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn2" "$THIS_MACHINE_IP:$name_node_rpc_port2"
    
    http_port1=$(($NAMENODE_HTTP_ADDRESS_BASE))
    http_port2=$(($NAMENODE_HTTP_ADDRESS_BASE + 1))
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn1" "0.0.0.0:$http_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn2" "0.0.0.0:$http_port2"
	#
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"    
    
    dataDir=$node_data_dir/data
    mkdir $dataDir
    addXMLProperty $hdfs_site_xml "dfs.datanode.data.dir" "$dataDir"

    http_port=$(($DATANODE_HTTP_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.http.address" "0.0.0.0:$http_port"

    data_node_port=$(($DATANODE_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.address" "0.0.0.0:$data_node_port"    
    
    data_node_ipc_port=$(($DATANODE_IPC_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.ipc.address" "0.0.0.0:$data_node_ipc_port"
    
    #Static configuration
    addAllXMLProperty $core_site_xml "core.properties"
    addAllXMLProperty $hdfs_site_xml "hdfs.properties"
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hadoop_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($DATANODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="$HADOOP_DATANODE_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    addProperty $hadoop_env "HADOOP_DATANODE_OPTS" "\"$jmx_prop\""
	
    debug_port=$(($DATANODE_DEBUG_PORT_BASE + $i - 1))
    debug_prop="$HADOOP_DATANODE_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port"
    addProperty $hadoop_env "HADOOP_DATANODE_OPTS" "\"$debug_prop\""
done
}
configure.journalnode()
{
echo "Configure journal node"
for (( i=1; i<=$NUMBER_OF_JOURNALNODE; i++ ))
do
    node_instance_dir=$INSTANCES/journalNode$i
    node_data_dir=$DATAS/journalNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"    
    
    dataDir=$node_data_dir/data
    mkdir $dataDir
    addXMLProperty $hdfs_site_xml "dfs.journalnode.edits.dir" "$dataDir"
    
    journal_node_ipc_port=$(($JOURNALNODE_IPC_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.journalnode.rpc-address" "0.0.0.0:$journal_node_ipc_port"

    http_port=$(($JOURNALNODE_HTTP_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.journalnode.http-address" "0.0.0.0:$http_port"

    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hadoop_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($JOURNALNODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="$HADOOP_JOURNALNODE_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    addProperty $hadoop_env "HADOOP_JOURNALNODE_OPTS" "\"$jmx_prop\""
	
    debug_port=$(($JOURNALNODE_DEBUG_PORT_BASE + $i - 1))
    debug_prop="\$HADOOP_JOURNALNODE_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port"
    addProperty $hadoop_env "HADOOP_JOURNALNODE_OPTS" "\"$debug_prop\""
done
}

printports.hadoop()
{
for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
do
	ipc_port=$(($NAMENODE_IPC_ADDRESS_BASE + $i - 1))
	web_port=$(($NAMENODE_HTTP_ADDRESS_BASE + $i - 1))
	jmx_port=$(($NAMENODE_JMX_PORT_BASE + $i - 1))
	debug_port=$(($NAMENODE_DEBUG_PORT_BASE + $i - 1))
	instanceName="NameNode"$i		
	echo "$instanceName=ipc_port:$ipc_port,web_port:$web_port,jmx_port:$jmx_port,debug_port:$debug_port"
done

for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
	ipc_port=$(($DATANODE_IPC_ADDRESS_BASE + $i - 1))
	web_port=$(($DATANODE_HTTP_ADDRESS_BASE + $i - 1))
	datanode_port=$(($DATANODE_ADDRESS_BASE + $i - 1))
	jmx_port=$(($DATANODE_JMX_PORT_BASE + $i - 1))
	debug_port=$(($DATANODE_DEBUG_PORT_BASE + $i - 1))
	instanceName="DataNode"$i	
	echo "$instanceName=ipc_port:$ipc_port,web_port:$web_port,datanode_port:$datanode_port,jmx_port:$jmx_port,debug_port:$debug_port"
done
for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
do
	resourcemanager_port=$(($RESOURCEMANAGER_ADDRESS_BASE + $i - 1))
	resourcemanager_scheduler_port=$(($RESOURCEMANAGER_SCHEDULER_ADDRESS_BASE + $i - 1))
	resource_tracker_port=$(($RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS_BASE + $i - 1))
	admin_port=$(($RESOURCEMANAGER_ADMIN_ADDRESS_BASE + $i - 1))
	web_port=$(($RESOURCEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))	
	jmx_port=$(($RESOURCEMANAGER_JMX_PORT_BASE + $i - 1))
	debug_port=$(($RESOURCEMANAGER_DEBUG_PORT_BASE + $i - 1))
	instanceName="ResourceManager"$i	
	echo "$instanceName=resourcemanager_port:$resourcemanager_port,resourcemanager_scheduler_port:$resourcemanager_scheduler_port,resource_tracker_port:$resource_tracker_port,admin_port:$admin_port,web_port:$web_port,jmx_port:$jmx_port,debug_port:$debug_port"
done
for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
do
	nodemanager_port=$(($NODEMANAGER_ADDRESS_BASE + $i - 1))
	locallizer_port=$(($NODEMANAGER_LOCALIZER_ADDRESS_BASE + $i - 1))
	web_port=$(($NODEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))	
	jmx_port=$(($NODEMANAGER_JMX_PORT_BASE + $i - 1))
	debug_port=$(($NODEMANAGER_DEBUG_PORT_BASE + $i - 1))
	instanceName="NodeManager"$i
	echo "$instanceName=nodemanager_port:$nodemanager_port,locallizer_port:$locallizer_port,web_port:$web_port,jmx_port:$jmx_port,debug_port:$debug_port"
done
}

start.stop.namenode()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
  do
     node_instance_dir=$INSTANCES/nameNode$i
     if [ $action = 'start' ] && [ "1" = $i ]; then
        echo "formatting name node now"
        node_data_dir=$DATAS/nameNodeData$i
        #Formate name node only when directory current does not exist
        if [ ! -d $node_data_dir/name/current ]; then
          $node_instance_dir/bin/hdfs namenode -format
          $node_instance_dir/bin/hdfs zkfc -formatZK -nonInteractive
          $node_instance_dir/bin/hdfs namenode -initializeSharedEdits -nonInteractive          
        fi
     fi
     if [ $action = 'start' ] && [ "2" = $i ]; then
        echo "formatting name node now"
        node_data_dir=$DATAS/nameNodeData$i
        #Formate name node only when directory current does not exist
        if [ ! -d $node_data_dir/name/current ]; then
          $node_instance_dir/bin/hdfs namenode -bootstrapStandby -nonInteractive          
        fi
     fi
     if [ $HADOOP2 = 'true' ]; then
        $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs $action zkfc
        $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs $action namenode
     else
        $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon $action zkfc
        $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon $action namenode
     fi
  done 
}
start.stop.datanode()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
  do
     node_instance_dir=$INSTANCES/dataNode$i
     if [ $HADOOP2 = 'true' ]; then
        $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs $action datanode
     else
        $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon $action datanode
     fi
  done 
}
start.stop.journalnode()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_JOURNALNODE; i++ ))
  do
     node_instance_dir=$INSTANCES/journalNode$i
     if [ $HADOOP2 = 'true' ]; then
        $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop $action journalnode
     else
        $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon $action journalnode
     fi
  done   
}
tests.hadoop()
{
  for (( i=1; i<=2; i++ ))
do
    node_instance_dir=$INSTANCES/nameNode$i
    node_data_dir=$DATAS/nameNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
    addAllXMLProperty $core_site_xml "core.properties"
    addAllXMLProperty $hdfs_site_xml "hdfs.properties"
done    
}
restart.hadoop()
{
  stop.hadoop
  start.hadoop    
}
status.hadoop()
{
  jps
}
case $1 in
  install)
      install.hadoop
      ;;
  reinstall)
      install.hadoop
      start.hadoop
      sleep 2
      status.hadoop
      ;;
  start)
      start.hadoop
      ;;
  stop)
      stop.hadoop
      ;;
  restart)
      restart.hadoop
      ;;
  status)
      status.hadoop
      ;;
  printports)
      printports.hadoop
      ;;
  tests)
      tests.hadoop
      ;;
  *)
  echo "Usage: $0 {install|start|stop|restart|status|printports}" >&2
esac