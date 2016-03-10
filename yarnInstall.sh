source commonScript.sh
#Modify this if want take custome location as base directory
BASE_DIR=`getBaseDir`

INSTALLATION_BASE_DIR=$BASE_DIR/yarn
RESOURCE_DIR=$BASE_DIR/resources
HADOOP_RELEASE=$BASE_DIR/hadoop-2.7.2.tar.gz
NUMBER_OF_RESOURCEMANAGER=1
NUMBER_OF_NODEMANAGER=3

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances
THIS_MACHINE_IP=192.168.1.3
# is the release from hadoop branch-2
HADOOP2=true

install_yarn()
{
  #Prepare installation directory structure
  
  if [ -d $INSTALLATION_BASE_DIR ]; then
	stop_yarn
	rm -r $INSTALLATION_BASE_DIR
  fi
  mkdir $INSTALLATION_BASE_DIR
  mkdir $DATAS
  mkdir $INSTANCES    
  extract_yarn
  configure_yarn
}
extract_yarn()
{
  extractModule "resourceManager" $NUMBER_OF_RESOURCEMANAGER
  extractModule "nodeManager" $NUMBER_OF_NODEMANAGER    
}
configure_yarn()
{
  configure_resourcemanager
  configure_nodemanager
}
start_yarn()
{
  start_stop_resourcemanager start
  start_stop_nodemanager start
}
stop_yarn()
{
  start_stop_resourcemanager stop
  start_stop_nodemanager stop
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

configure_resourcemanager()
{
echo "Configure resource manager"
for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
do
    node_instance_dir=$INSTANCES/resourceManager$i
    node_data_dir=$DATAS/resourceManagerData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    yarn_site_xml=$node_instance_dir/etc/hadoop/yarn-site.xml    
    yarn_env=$node_instance_dir/etc/hadoop/yarn-env.sh
    
    addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://$THIS_MACHINE_IP:$NAMENODE_IPC_ADDRESS_BASE"  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $core_site_xml "hadoop.tmp.dir" "$tempDir"
    
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.hostname" "0.0.0.0"
    
    resourcemanager_port=$(($RESOURCEMANAGER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_port"
    
    resourcemanager_scheduler_port=$(($RESOURCEMANAGER_SCHEDULER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.scheduler.address" "$THIS_MACHINE_IP:$resourcemanager_scheduler_port"
    
    resourcemanager_resource_tracker_port=$(($RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.resource-tracker.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_resource_tracker_port"
    
    resourcemanager_admin_address_port=$(($RESOURCEMANAGER_ADMIN_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.admin.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_admin_address_port"
    
    resourcemanager_webapp_address_port=$(($RESOURCEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))
    addXMLProperty $yarn_site_xml "yarn.resourcemanager.webapp.address" "\${yarn.resourcemanager.hostname}:$resourcemanager_webapp_address_port"
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $yarn_env $VAR_PREFIX"_PID_DIR" "$pidDir"
    
    jmx_port=$(($RESOURCEMANAGER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    addProperty $yarn_env "YARN_RESOURCEMANAGER_OPTS" "\"$jmx_prop\""
	
    debug_port=$(($RESOURCEMANAGER_DEBUG_PORT_BASE + $i - 1))
    debug_prop="\$YARN_RESOURCEMANAGER_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port"
    addProperty $yarn_env "YARN_RESOURCEMANAGER_OPTS" "\"$debug_prop\""
done
}
configure_nodemanager()
{
echo "Configure node manager"
for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
do
    node_instance_dir=$INSTANCES/nodeManager$i
    node_data_dir=$DATAS/nodeManagerData$i
    core_site_xml=$node_instance_dir/etc/hadoop/core-site.xml
    yarn_site_xml=$node_instance_dir/etc/hadoop/yarn-site.xml    
    yarn_env=$node_instance_dir/etc/hadoop/yarn-env.sh
    
    addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://$THIS_MACHINE_IP:$NAMENODE_IPC_ADDRESS_BASE"  
    
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
    
    VAR_PREFIX="HADOOP"
    if [ $HADOOP2 = 'true' ]; then
	    VAR_PREFIX="YARN"
	  fi
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $yarn_env $VAR_PREFIX"_PID_DIR" "$pidDir"
    
    jmx_port=$(($NODEMANAGER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    addProperty $yarn_env "YARN_NODEMANAGER_OPTS" "\"$jmx_prop\""
	
    debug_port=$(($NODEMANAGER_DEBUG_PORT_BASE + $i - 1))
    debug_prop="\$YARN_NODEMANAGER_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port"
    addProperty $yarn_env "YARN_NODEMANAGER_OPTS" "\"$debug_prop\""
done
}

printports_yarn()
{
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

start_stop_resourcemanager()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
  do
     node_instance_dir=$INSTANCES/resourceManager$i
     if [ $HADOOP2 = 'true' ]; then
        $node_instance_dir/sbin/yarn-daemon.sh --config $node_instance_dir/etc/hadoop $action resourcemanager
     else
        $node_instance_dir/bin/yarn --config $node_instance_dir/etc/hadoop --daemon $action resourcemanager
     fi
  done   
}
start_stop_nodemanager()
{
  action=$1
  for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
  do
     node_instance_dir=$INSTANCES/nodeManager$i
     if [ $HADOOP2 = 'true' ]; then
        $node_instance_dir/sbin/yarn-daemon.sh --config $node_instance_dir/etc/hadoop $action nodemanager
     else
        $node_instance_dir/bin/yarn --config $node_instance_dir/etc/hadoop --daemon $action nodemanager
     fi 
  done   
}
restart_yarn()
{
  stop_yarn
  start_yarn    
}
status_yarn()
{
  jps
}
case $1 in
  install)
      install_yarn
      ;;
  reinstall)
      install_yarn
      start_yarn
      sleep 2
      status_yarn
      ;;
  start)
      start_yarn
      ;;
  stop)
      stop_yarn
      ;;
  restart)
      restart_yarn
      ;;
  status)
      status_yarn
      ;;
  printports)
      printports_yarn
      ;;
  *)
  echo "Usage: $0 {install|start|stop|restart|status|printports}" >&2
esac