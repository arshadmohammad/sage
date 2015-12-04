basedir=`dirname $0`
if [ "${basedir}" = "." ]
then
    basedir=`pwd`
elif [ "${basedir}" = ".." ]
then
    basedir=`(cd .. ;pwd)`
fi
#Modify this if want take custome location as base directory
BASE_DIR=$basedir

INSTALLATION_BASE_DIR=$BASE_DIR/hadoop
RESOURCE_DIR=$BASE_DIR/resources
HADOOP_RELEASE=$BASE_DIR/hadoop-3.0.0-SNAPSHOT.tar.gz
NUMBER_OF_NAMENODE=2
NUMBER_OF_DATANODE=3
NUMBER_OF_JOURNALNODE=3
NUMBER_OF_RESOURCEMANAGER=2
NUMBER_OF_NODEMANAGER=3

REPLICATION=3
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

#Resource Manager ports
RESOURCEMANAGER_ADDRESS_BASE=8032
RESOURCEMANAGER_SCHEDULER_ADDRESS_BASE=8030
RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS_BASE=8040
RESOURCEMANAGER_ADMIN_ADDRESS_BASE=8035
RESOURCEMANAGER_WEBAPP_ADDRESS_BASE=8088
RESOURCEMANAGER_JMX_PORT_BASE=5520
RESOURCEMANAGER_DEBUG_PORT_BASE=4430

#Node Manager ports
NODEMANAGER_ADDRESS_BASE=9032
NODEMANAGER_LOCALIZER_ADDRESS_BASE=9040
NODEMANAGER_WEBAPP_ADDRESS_BASE=9052
NODEMANAGER_JMX_PORT_BASE=5530
NODEMANAGER_DEBUG_PORT_BASE=5540

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances

install_()
{
  #Prepare installation directory structure
  
  if [ -d $INSTALLATION_BASE_DIR ]; then
	stop_
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
  extractModule "resourceManager" $NUMBER_OF_RESOURCEMANAGER
  extractModule "nodeManager" $NUMBER_OF_NODEMANAGER    
}
configure_hadoop()
{
  configure_namenode
  configure_datanode
  configure_resourcemanager
  configure_nodemanager
}
start_()
{
  start_name_node
  start_data_node
  start_resourcemanager
  start_nodemanager
}
stop_()
{
  stop_data_node
  stop_name_node
  stop_nodemanager
  stop_resourcemanager
}

extractModule()
{
  module=$1
  count=$2
  println "Extracting $module"
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
# file, key, value
addXMLProperty()
{
  property_xml="\t<property>\n\t\t<name>$2</name>\n\t\t<value>$3</value>\n\t</property>\n</configuration>"
  sed -i "s|</configuration>|$property_xml|" $1
}
# file, key, value
addProperty()
{
  echo "export $2=$3" >> $1  
}
configure_namenode()
{
println "Configure name node"
for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
do
    node_instance_dir=$INSTANCES/nameNode$i
    node_data_dir=$DATAS/nameNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
    name_node_rpc_port=$(($NAMENODE_IPC_ADDRESS_BASE + $i - 1))
    
    addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://localhost:$name_node_rpc_port" 
	addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-bind-host" "0.0.0.0"
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir" 
     
    addXMLProperty $hdfs_site_xml "dfs.replication" "$REPLICATION"
    
    nameDir=$node_data_dir/name
    mkdir $nameDir
    addXMLProperty $hdfs_site_xml "dfs.namenode.name.dir" "$nameDir"    

    editDir=$node_data_dir/edit
    mkdir $editDir
    addXMLProperty $hdfs_site_xml "dfs.namenode.edits.dir" "$editDir"

    http_port=$(($NAMENODE_HTTP_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.namenode.http-address" "0.0.0.0:$http_port"
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hadoop_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($NAMENODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $HADOOP_NAMENODE_OPTS"
    addProperty $hadoop_env "HADOOP_NAMENODE_OPTS" "\"$jmx_prop\""
	
	debug_port=$(($NAMENODE_DEBUG_PORT_BASE + $i - 1))
    debug_prop="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port $HADOOP_NAMENODE_OPTS"
	addProperty $hadoop_env "HADOOP_NAMENODE_OPTS" "\"$debug_prop\""
done
}

configure_datanode()
{
println "Configure data node"
for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
    node_instance_dir=$INSTANCES/dataNode$i
    node_data_dir=$DATAS/dataNodeData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    hdfs_site_xml=$node_instance_dir/etc/hadoop/hdfs-site.xml
    hadoop_env=$node_instance_dir/etc/hadoop/hadoop-env.sh
    
    addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://localhost:$NAMENODE_IPC_ADDRESS_BASE"  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"    
    
    addXMLProperty $hdfs_site_xml "dfs.replication" "$REPLICATION"
    
    dataDir=$node_data_dir/data
    mkdir $dataDir
    addXMLProperty $hdfs_site_xml "dfs.datanode.data.dir" "$dataDir"

    http_port=$(($DATANODE_HTTP_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.http.address" "0.0.0.0:$http_port"

    data_node_port=$(($DATANODE_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.address" "0.0.0.0:$data_node_port"    
    
    data_node_ipc_port=$(($DATANODE_IPC_ADDRESS_BASE + $i - 1))
    addXMLProperty $hdfs_site_xml "dfs.datanode.ipc.address" "0.0.0.0:$data_node_ipc_port"
    
    
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hadoop_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($DATANODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $HADOOP_DATANODE_OPTS"
    addProperty $hadoop_env "HADOOP_DATANODE_OPTS" "\"$jmx_prop\""
	
	debug_port=$(($DATANODE_DEBUG_PORT_BASE + $i - 1))
    debug_prop="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port $HADOOP_DATANODE_OPTS"
	addProperty $hadoop_env "HADOOP_DATANODE_OPTS" "\"$debug_prop\""
done
}
configure_resourcemanager()
{
println "Configure resource manager"
for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
do
    node_instance_dir=$INSTANCES/resourceManager$i
    node_data_dir=$DATAS/resourceManagerData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    yarn_site_xml=$node_instance_dir/etc/hadoop/yarn-site.xml    
    yarn_env=$node_instance_dir/etc/hadoop/yarn-env.sh
    
    addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://localhost:$NAMENODE_IPC_ADDRESS_BASE"  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"
    
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.hostname" "0.0.0.0"
    
    resourcemanager_port=$(($RESOURCEMANAGER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_port"
    
    resourcemanager_scheduler_port=$(($RESOURCEMANAGER_SCHEDULER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.scheduler.address" "localhost:$resourcemanager_scheduler_port"
    
    resourcemanager_resource_tracker_port=$(($RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.resource-tracker.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_resource_tracker_port"
    
    resourcemanager_admin_address_port=$(($RESOURCEMANAGER_ADMIN_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.admin.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_admin_address_port"
    
    resourcemanager_webapp_address_port=$(($RESOURCEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.webapp.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_webapp_address_port"
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $yarn_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($RESOURCEMANAGER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $HADOOP_OPTS"
    addProperty $yarn_env "HADOOP_OPTS" "\"$jmx_prop\""
	
	debug_port=$(($RESOURCEMANAGER_DEBUG_PORT_BASE + $i - 1))
    debug_prop="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port $HADOOP_OPTS"
	addProperty $yarn_env "HADOOP_OPTS" "\"$debug_prop\""
done
}
configure_nodemanager()
{
println "Configure node manager"
for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
do
    node_instance_dir=$INSTANCES/nodeManager$i
    node_data_dir=$DATAS/nodeManagerData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    yarn_site_xml=$node_instance_dir/etc/hadoop/yarn-site.xml    
    yarn_env=$node_instance_dir/etc/hadoop/yarn-env.sh
    
    addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://localhost:$NAMENODE_IPC_ADDRESS_BASE"  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"
    
    addXMLProperty $yarn_site_xml "yarn.nodemanager.hostname" "0.0.0.0"
    
    nodemanager_address_port=$(($NODEMANAGER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.nodemanager.address" "\${yarn.nodemanager.hostname}:$nodemanager_address_port"
    
    nodemanager_localizer_address_port=$(($NODEMANAGER_LOCALIZER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.nodemanager.localizer.address" "\${yarn.nodemanager.hostname}:$nodemanager_localizer_address_port"
    
    nodemanager_webapp_address_port=$(($NODEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.nodemanager.webapp.address" "\${yarn.nodemanager.hostname}:$nodemanager_webapp_address_port"    
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $yarn_env "HADOOP_PID_DIR" "$pidDir"
    
    jmx_port=$(($NODEMANAGER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $HADOOP_OPTS"
    addProperty $yarn_env "HADOOP_OPTS" "\"$jmx_prop\""
	
	debug_port=$(($NODEMANAGER_DEBUG_PORT_BASE + $i - 1))
    debug_prop="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port $HADOOP_OPTS"
	addProperty $yarn_env "HADOOP_OPTS" "\"$debug_prop\""
done
}

println()
{
    echo $1
    echo ""
}
printports_()
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

start_name_node()
{
  for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
  do
     node_instance_dir=$INSTANCES/nameNode$i
     node_data_dir=$DATAS/nameNodeData$i
     #Formate name node only when directory current does not exist
     if [ ! -d $node_data_dir/name/current ]; then
      $node_instance_dir/bin/hdfs namenode -format
     fi     
     $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon start namenode
  done   
}
start_data_node()
{
  for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
  do
     node_instance_dir=$INSTANCES/dataNode$i
     $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon start datanode
  done   
}
start_resourcemanager()
{
  for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
  do
     node_instance_dir=$INSTANCES/resourceManager$i
     $node_instance_dir/bin/yarn --config $node_instance_dir/etc/hadoop --daemon start resourcemanager
  done   
}
start_nodemanager()
{
  for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
  do
     node_instance_dir=$INSTANCES/nodeManager$i
     $node_instance_dir/bin/yarn --config $node_instance_dir/etc/hadoop --daemon start nodemanager
  done   
}

stop_name_node()
{
  for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
  do
     node_instance_dir=$INSTANCES/nameNode$i   
     $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon stop namenode
  done 
}
stop_data_node()
{
  for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
  do
     node_instance_dir=$INSTANCES/dataNode$i 
     $node_instance_dir/bin/hdfs --config $node_instance_dir/etc/hadoop --daemon stop datanode
  done 
}
stop_resourcemanager()
{
  for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
  do
     node_instance_dir=$INSTANCES/resourceManager$i
     $node_instance_dir/bin/yarn --config $node_instance_dir/etc/hadoop --daemon stop resourcemanager
  done   
}
stop_nodemanager()
{
  for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
  do
     node_instance_dir=$INSTANCES/nodeManager$i
     $node_instance_dir/bin/yarn --config $node_instance_dir/etc/hadoop --daemon stop nodemanager
  done   
}
restart_()
{
  stop_
  start_    
}
status_()
{
  jps
}
case $1 in
  install)
      install_
      ;;
  reinstall)
      stop_
      install_
      start_
      sleep 2
      status_
      ;;
  start)
      start_
      ;;
  stop)
      stop_
      ;;
  restart)
      restart_
      ;;
  status)
      status_
      ;;
  printports)
      printports_
      ;;
  *)
  echo "Usage: $0 {install|start|stop|restart|status|printports}" >&2
esac