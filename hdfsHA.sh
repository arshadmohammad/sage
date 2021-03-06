source commonScript.sh
#Modify this if want take custome location as base directory
BASE_DIR=`getBaseDir`

INSTALLATION_BASE_DIR=$BASE_DIR/hadoop
RESOURCE_DIR=$BASE_DIR/resources
HADOOP_RELEASE=$BASE_DIR/hadoop-2.7.3.tar.gz
NUMBER_OF_NAMENODE=2
NUMBER_OF_DATANODE=3
NUMBER_OF_JOURNALNODE=3

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances
# is the release from hadoop branch-2
HADOOP2=true

install_hadoop()
{
  #Prepare installation directory structure
  
  if [ -d $INSTALLATION_BASE_DIR ]; then
	stop_hadoop
	rm -r $INSTALLATION_BASE_DIR
  fi
  mkdir $INSTALLATION_BASE_DIR
  mkdir $DATAS
  mkdir $INSTANCES    
  extract_hadoop
  configure_hadoop
}
extract_hadoop()
{
  extractModule "nameNode" $NUMBER_OF_NAMENODE
  extractModule "dataNode" $NUMBER_OF_DATANODE
  extractModule "journalNode" $NUMBER_OF_JOURNALNODE
}
configure_hadoop()
{
  configure_namenode
  configure_datanode
  configure_journalnode
}
start_hadoop()
{
  start_stop_journalnode start
  start_stop_namenode start
  start_stop_datanode start  
}
stop_hadoop()
{
  start_stop_datanode stop
  #prestineNameNode
  start_stop_namenode stop   
  start_stop_journalnode stop
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
	if [ $WINDOWS_BUILD = 'true' ]; then
	  dos2unix $node_instance_dir/bin/*
	  dos2unix $node_instance_dir/sbin/*
	  dos2unix $node_instance_dir/etc/hadoop/*
	  dos2unix $node_instance_dir/libexec/*
	fi
	    
    #create data dir
    data="Data"
    node_data_dir=$DATAS/$module$data$i
    if [ -d $node_data_dir ]; then
      rm -r $node_data_dir
    fi 
    mkdir $node_data_dir
  done
}
prestineNameNode()
{
#create data dir
module="nameNode"
data="Data2"
node_data_dir=$DATAS/$module$data
if [ -d $node_data_dir ]; then
  rm -r $node_data_dir
fi 
mkdir $node_data_dir

tempDir=$node_data_dir/temp
mkdir $tempDir

nameDir=$node_data_dir/name
mkdir $nameDir

editDir=$node_data_dir/edit
mkdir $editDir

pidDir=$node_data_dir/pid
mkdir $pidDir

}
configure_namenode()
{
echo "Configure name node"
for (( i=1; i<=NUMBER_OF_NAMENODE; i++ ))
do
    node_instance_dir=$INSTANCES/nameNode$i
    node_data_dir=$DATAS/nameNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
    
	##common cofig for all config
    addXMLProperty $hdfs_site_xml "dfs.ha.namenode.id" "nn"$i    
    
    http_port1=$(($NAMENODE_HTTP_ADDRESS_BASE))
    http_port2=$(($NAMENODE_HTTP_ADDRESS_BASE + 1))
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn1" "0.0.0.0:$http_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn2" "0.0.0.0:$http_port2"
	
	 https_port1=$(($NAMENODE_HTTPS_ADDRESS_BASE))
    https_port2=$(($NAMENODE_HTTPS_ADDRESS_BASE + 1))
	addXMLProperty $hdfs_site_xml "dfs.namenode.https-address.mycluster.nn1" "0.0.0.0:$https_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.https-address.mycluster.nn2" "0.0.0.0:$https_port2"
		
    
    addXMLProperty $hdfs_site_xml "dfs.namenode.shared.edits.dir" "qjournal://$THIS_MACHINE_IP:$(($JOURNALNODE_IPC_ADDRESS_BASE));$THIS_MACHINE_IP:$(($JOURNALNODE_IPC_ADDRESS_BASE + 1));$THIS_MACHINE_IP:$(($JOURNALNODE_IPC_ADDRESS_BASE + 2))/mycluster"
    addXMLProperty $hdfs_site_xml "ha.zookeeper.quorum" "$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE)),$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE + 1)),$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE + 2))"
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
	cp $INSTALLATION_HOME/resources/hadoop/ssl-server.xml $node_instance_dir/etc/hadoop/
	cp $INSTALLATION_HOME/resources/hadoop/ssl-client.xml $node_instance_dir/etc/hadoop/
    
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

configure_datanode()
{
echo "Configure data node"
for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
    node_instance_dir=$INSTANCES/dataNode$i
    node_data_dir=$DATAS/dataNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh	
        
    http_port1=$(($NAMENODE_HTTP_ADDRESS_BASE))
    http_port2=$(($NAMENODE_HTTP_ADDRESS_BASE + 1))
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn1" "0.0.0.0:$http_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address.mycluster.nn2" "0.0.0.0:$http_port2"
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"    
    
    dataDir=$node_data_dir/data
    mkdir $dataDir
    addXMLProperty $hdfs_site_xml "dfs.datanode.data.dir" "$dataDir"

    http_port=$(($DATANODE_HTTP_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.http.address" "0.0.0.0:$http_port"
	
	https_port=$(($DATANODE_HTTPS_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.https.address" "0.0.0.0:$https_port"

    data_node_port=$(($DATANODE_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.address" "0.0.0.0:$data_node_port"    
    
    data_node_ipc_port=$(($DATANODE_IPC_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.ipc.address" "0.0.0.0:$data_node_ipc_port"
    
    #Static configuration
    addAllXMLProperty $core_site_xml "core.properties"
    addAllXMLProperty $hdfs_site_xml "hdfs.properties"
	cp $INSTALLATION_HOME/resources/hadoop/ssl-server.xml $node_instance_dir/etc/hadoop/
	cp $INSTALLATION_HOME/resources/hadoop/ssl-client.xml $node_instance_dir/etc/hadoop/
    
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
configure_journalnode()
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
	
	https_port=$(($JOURNALNODE_HTTPS_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.journalnode.https-address" "0.0.0.0:$https_port"
	
	    #Static configuration
    addAllXMLProperty $core_site_xml "core.properties"
    addAllXMLProperty $hdfs_site_xml "hdfs.properties"
	cp $INSTALLATION_HOME/resources/hadoop/ssl-server.xml $node_instance_dir/etc/hadoop/
	cp $INSTALLATION_HOME/resources/hadoop/ssl-client.xml $node_instance_dir/etc/hadoop/

    
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

printports_hadoop()
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

start_stop_namenode()
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
		  pushd $node_instance_dir/bin/
		  echo "./hdfs namenode -bootstrapStandby -nonInteractive"
          ./hdfs namenode -bootstrapStandby -nonInteractive
          popd		  
        fi
     fi
     if [ $HADOOP2 = 'true' ]; then
	    pushd $node_instance_dir/sbin
        ./hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs $action zkfc
        ./hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs $action namenode
		popd
     else
	    pushd $node_instance_dir/bin
        ./hdfs --config $node_instance_dir/etc/hadoop --daemon $action zkfc
        ./hdfs --config $node_instance_dir/etc/hadoop --daemon $action namenode
		popd
     fi
  done 
}
start_stop_datanode()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
  do
     node_instance_dir=$INSTANCES/dataNode$i
     if [ $HADOOP2 = 'true' ]; then
	    pushd $node_instance_dir/sbin/
        ./hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs $action datanode
		popd
     else
	    pushd $node_instance_dir/bin/
        ./hdfs --config $node_instance_dir/etc/hadoop --daemon $action datanode
		popd
     fi
  done 
}
start_stop_journalnode()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_JOURNALNODE; i++ ))
  do
     node_instance_dir=$INSTANCES/journalNode$i
     if [ $HADOOP2 = 'true' ]; then
	    pushd $node_instance_dir/sbin/
        ./hadoop-daemon.sh --config $node_instance_dir/etc/hadoop $action journalnode
		popd
     else
	    pushd $node_instance_dir/bin/
        ./hdfs --config $node_instance_dir/etc/hadoop --daemon $action journalnode
		popd
     fi
  done   
}
inithbase()
{
echo "Initializting HBase directory"
node_instance_dir=$INSTANCES/nameNode1
kdestroy
kinit -k -t $INSTALLATION_HOME/resources/common/hadoop.keytab hdfs/volton
klist
cd $node_instance_dir/bin
./hdfs dfs -mkdir /hbase
./hdfs dfs -chown hbase:hadoop /hbase
./hdfs dfs -chmod 755 /hbase
kdestroy
echo "HBase hdfs directory initialized."
}
init()
{
klist
kdestroy
kinit -k -t $INSTALLATION_HOME/resources/common/hadoop.keytab $1
klist
cd $node_instance_dir/bin
}
tests_hadoop()
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
restart_hadoop()
{
  stop_hadoop
  start_hadoop    
}
status_hadoop()
{
  jps
}
case $1 in
  install)
      install_hadoop
      ;;
  reinstall)
      install_hadoop
      start_hadoop
      sleep 2
      status_hadoop
      ;;
  start)
      start_hadoop
      ;;
  stop)
      stop_hadoop
      ;;
  restart)
      restart_hadoop
      ;;
  status)
      status_hadoop
      ;;
  printports)
      printports_hadoop
      ;;
  tests)
      tests_hadoop
      ;;
  inithbase)
      inithbase
      ;;
  init)
      init $2
      ;;
  *)
  echo "Usage: $0 {install|start|stop|restart|status|printports}" >&2
esac