source commonScript.sh
#Modify this if want take custome location as base directory
BASE_DIR=`getBaseDir`

INSTALLATION_BASE_DIR=$BASE_DIR/hbase
RESOURCE_DIR=$BASE_DIR/resources
HBASE_RELEASE=$BASE_DIR/hbase-2.0.0-SNAPSHOT-bin.tar.gz
NUMBER_OF_HMASTER=2
NUMBER_OF_HREGION_SERVER=3
THIS_MACHINE_IP=192.168.1.3
DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances

install_hbase()
{
  #Prepare installation directory structure
  
  if [ -d $INSTALLATION_BASE_DIR ]; then
	stop_hbase
	rm -r $INSTALLATION_BASE_DIR
  fi
  mkdir $INSTALLATION_BASE_DIR
  mkdir $DATAS
  mkdir $INSTANCES    
  extract_hbase
  configure_hbase
}
extract_hbase()
{
  extractModule "HMaster" $NUMBER_OF_HMASTER
  extractModule "HRegionServer" $NUMBER_OF_HREGION_SERVER
}
configure_hbase()
{
  configure_HMaster
  configure_HRegionServer
}
start_hbase()
{
  start_stop_HMaster "start"
  start_stop_HRegionServer "start"
}
stop_hbase()
{
  start_stop_HMaster "stop"
  start_stop_HRegionServer "stop"
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
    tar -mxf $HBASE_RELEASE -C $node_instance_dir --strip-components 1 
    
    #create data dir
    data="Data"
    node_data_dir=$DATAS/$module$data$i
    if [ -d $node_data_dir ]; then
      rm -r $node_data_dir
    fi 
    mkdir $node_data_dir
  done
}

configure_HMaster()
{
echo "Configure HMaster"
for (( i=1; i<=$NUMBER_OF_HMASTER; i++ ))
do
    node_instance_dir=$INSTANCES/HMaster$i
    node_data_dir=$DATAS/HMasterData$i
    hbase_site_xml=$node_instance_dir/conf/hbase-site.xml
    hbase_env=$node_instance_dir/conf/hbase-env.sh
	addXMLProperty $hbase_site_xml "hbase.rootdir" "hdfs://mycluster/hbase"
	
	## hdfs cofig
	core_site_xml=$node_instance_dir/conf/core-site.xml
	createSiteFile $core_site_xml
	addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://mycluster"
	
	hdfs_site_xml=$node_instance_dir/conf/hdfs-site.xml
	createSiteFile $hdfs_site_xml
	
    addXMLProperty $hdfs_site_xml "dfs.nameservices" "mycluster"
	addXMLProperty $hdfs_site_xml "dfs.ha.namenodes.mycluster" "nn1,nn2"
    name_node_rpc_port1=$(($NAMENODE_IPC_ADDRESS_BASE ))
    name_node_rpc_port2=$(($NAMENODE_IPC_ADDRESS_BASE + 1))    
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn1" "$THIS_MACHINE_IP:$name_node_rpc_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn2" "$THIS_MACHINE_IP:$name_node_rpc_port2"
    addXMLProperty $hdfs_site_xml "dfs.client.failover.proxy.provider.mycluster" "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider"	
	#	
    
	addXMLProperty $hbase_site_xml "hbase.zookeeper.quorum" "$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE)),$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE + 1)),$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE + 2))"  
	addXMLProperty $hbase_site_xml "hbase.cluster.distributed" "true" 
	  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $hbase_site_xml "hbase.tmp.dir" "$tempDir"
	
	master_port=$(($HMASTER_PORT_BASE + $i - 1))
	addXMLProperty $hbase_site_xml "hbase.master.port" "$master_port"
	
	ui_port=$(($HMASTER_INFO_PORT_BASE + $i - 1))
	addXMLProperty $hbase_site_xml "hbase.master.info.port" "$ui_port" 
	
	
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hbase_env "HBASE_PID_DIR" "$pidDir"
    
    jmx_port=$(($HMASTER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false \$HBASE_MASTER_OPTS"
    addProperty $hbase_env "HBASE_MASTER_OPTS" "\"$jmx_prop\""
	
	debug_port=$(($HMASTER_DEBUG_PORT_BASE + $i - 1))
    debug_prop="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port \$HBASE_MASTER_OPTS"
	addProperty $hbase_env "HBASE_MASTER_OPTS" "\"$debug_prop\""
done
}

configure_HRegionServer()
{
echo "Configure HRegionServer"
for (( i=1; i<=$NUMBER_OF_HREGION_SERVER; i++ ))
do
    node_instance_dir=$INSTANCES/HRegionServer$i
    node_data_dir=$DATAS/HRegionServerData$i
    hbase_site_xml=$node_instance_dir/conf/hbase-site.xml
	hbase_env=$node_instance_dir/conf/hbase-env.sh
	addXMLProperty $hbase_site_xml "hbase.rootdir" "hdfs://mycluster/hbase"	
	
	## hdfs cofig
	core_site_xml=$node_instance_dir/conf/core-site.xml
	createSiteFile $core_site_xml
	addXMLProperty $core_site_xml "fs.defaultFS" "hdfs://mycluster"
	
	hdfs_site_xml=$node_instance_dir/conf/hdfs-site.xml
	createSiteFile $hdfs_site_xml
	
    addXMLProperty $hdfs_site_xml "dfs.nameservices" "mycluster"
	addXMLProperty $hdfs_site_xml "dfs.ha.namenodes.mycluster" "nn1,nn2"
    name_node_rpc_port1=$(($NAMENODE_IPC_ADDRESS_BASE ))
    name_node_rpc_port2=$(($NAMENODE_IPC_ADDRESS_BASE + 1))    
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn1" "$THIS_MACHINE_IP:$name_node_rpc_port1"
    addXMLProperty $hdfs_site_xml "dfs.namenode.rpc-address.mycluster.nn2" "$THIS_MACHINE_IP:$name_node_rpc_port2"
    addXMLProperty $hdfs_site_xml "dfs.client.failover.proxy.provider.mycluster" "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider"	
	#
    
     
	addXMLProperty $hbase_site_xml "hbase.zookeeper.quorum" "$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE)),$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE + 1)),$THIS_MACHINE_IP:$(($ZOOKEEPER_CLIENT_PORT_BASE + 2))" 
	addXMLProperty $hbase_site_xml "hbase.cluster.distributed" "true" 
	  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $hbase_site_xml "hbase.tmp.dir" "$tempDir"
	
	regionserver_port=$(($HREGION_SERVER_PORT_BASE + $i - 1))
	addXMLProperty $hbase_site_xml "hbase.regionserver.port" "$regionserver_port"
	
	regionserver_ui_port=$(($HREGION_SERVER_INFO_PORT_BASE + $i - 1))
	addXMLProperty $hbase_site_xml "hbase.regionserver.info.port" "$regionserver_ui_port" 
	
	
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    addProperty $hbase_env "HBASE_PID_DIR" "$pidDir"
    
    jmx_port=$(($HREGION_SERVER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false \$HBASE_REGIONSERVER_OPTS"
    addProperty $hbase_env "HBASE_REGIONSERVER_OPTS" "\"$jmx_prop\""
	
	debug_port=$(($HREGION_SERVER_DEBUG_PORT_BASE + $i - 1))
    debug_prop="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port \$HBASE_REGIONSERVER_OPTS"
	addProperty $hbase_env "HBASE_REGIONSERVER_OPTS" "\"$debug_prop\""
done
}

printports_hbase()
{
for (( i=1; i<=$NUMBER_OF_HMASTER; i++ ))
    do
		master_port=$(($HMASTER_PORT_BASE + $i - 1))
        master_ui_port=$(($HMASTER_INFO_PORT_BASE + $i - 1))
        jmx_port=$(($HMASTER_JMX_PORT_BASE + $i - 1))
        debug_port=$(($HMASTER_DEBUG_PORT_BASE + $i - 1))
		instanceName="HMaster"$i
        echo "$instanceName=master_port:$master_port,master_ui_port:$master_ui_por,jmx_port:$jmx_port,debug_port:$debug_port"
    done
	
for (( i=1; i<=$NUMBER_OF_HREGION_SERVER; i++ ))
    do
		regionserver_port=$(($HREGION_SERVER_PORT_BASE + $i - 1))
        regionserver_ui_port=$(($HREGION_SERVER_INFO_PORT_BASE + $i - 1))
        jmx_port=$(($HREGION_SERVER_JMX_PORT_BASE + $i - 1))
        debug_port=$(($HREGION_SERVER_DEBUG_PORT_BASE + $i - 1))
		instanceName="HRegionServer"$i
        echo "$instanceName=regionserver_port:$regionserver_port,regionserver_ui_port:$regionserver_ui_port,jmx_port:$jmx_port,debug_port:$debug_port"
    done
}

start_stop_HMaster()
{
  for (( i=1; i<=$NUMBER_OF_HMASTER; i++ ))
  do
     node_instance_dir=$INSTANCES/HMaster$i
	 echo "$1 master"
	 pushd $node_instance_dir/bin
     ./hbase-daemon.sh $1 master
	 popd
  done   
}
start_stop_HRegionServer()
{
  for (( i=1; i<=$NUMBER_OF_HREGION_SERVER; i++ ))
  do
     node_instance_dir=$INSTANCES/HRegionServer$i
	 pushd $node_instance_dir/bin
     ./hbase-daemon.sh $1 regionserver
	 popd
  done   
}
restart_hbase()
{
  stop_hbase
  start_hbase
}
status_hbase()
{
  jps
}
case $1 in
  install)
      install_hbase
      ;;
  reinstall)
      stop_hbase
      install_hbase
      start_hbase
      sleep 2
      status_hbase
      ;;
  start)
      start_hbase
      ;;
  stop)
      stop_hbase
      ;;
  restart)
      restart_hbase
      ;;
  status)
      status_hbase
      ;;
  printports)
      printports_hbase
      ;;
  *)
  echo "Usage: $0 {install|start|stop|restart|status|printports}" >&2
esac