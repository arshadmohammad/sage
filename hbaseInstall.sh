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

INSTALLATION_BASE_DIR=$BASE_DIR/hbase
RESOURCE_DIR=$BASE_DIR/resources
HBASE_RELEASE=$BASE_DIR/hbase-2.0.0-SNAPSHOT-bin.tar.gz
NUMBER_OF_HMASTER=1
NUMBER_OF_HREGION_SERVER=3

#HMaster ports
HMASTER_PORT_BASE=16000
HMASTER_INFO_PORT_BASE=16010
HMASTER_JMX_PORT_BASE=5600
HMASTER_DEBUG_PORT_BASE=4500

#HRegionServer ports
HREGION_SERVER_PORT_BASE=16020
HREGION_SERVER_INFO_PORT_BASE=16030
HREGION_SERVER_JMX_PORT_BASE=5620
HREGION_SERVER_DEBUG_PORT_BASE=4520

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances
HBASE_ROOTDIR="hdfs://localhost:9000/hbase"
HBASE_ZOOKEEPER_QUORUM="localhost:2181,localhost:2182,localhost:2183"

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
start_()
{
  start_HMaster
  start_HRegionServer
}
stop_()
{
  stop_HMaster
  stop_HRegionServer
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
configure_HMaster()
{
println "Configure HMaster"
for (( i=1; i<=$NUMBER_OF_HMASTER; i++ ))
do
    node_instance_dir=$INSTANCES/HMaster$i
    node_data_dir=$DATAS/HMasterData$i
    hbase_site_xml=$node_instance_dir/conf/hbase-site.xml
    hbase_env=$node_instance_dir/conf/hbase-env.sh
    
    addXMLProperty $hbase_site_xml "hbase.rootdir" "$HBASE_ROOTDIR" 
	addXMLProperty $hbase_site_xml "hbase.zookeeper.quorum" "$HBASE_ZOOKEEPER_QUORUM" 
	addXMLProperty $hbase_site_xml "hbase.cluster.distributed" "true" 
	  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $hbase_site_xml "hbase.tmp.dir" "$tempDir"
	
	stagingDir=$node_data_dir/hbase-staging
    mkdir $stagingDir
    addXMLProperty $hbase_site_xml "hbase.fs.tmp.dir" "$stagingDir"
	
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
println "Configure HRegionServer"
for (( i=1; i<=$NUMBER_OF_HREGION_SERVER; i++ ))
do
    node_instance_dir=$INSTANCES/HRegionServer$i
    node_data_dir=$DATAS/HRegionServerData$i
    hbase_site_xml=$node_instance_dir/conf/hbase-site.xml
    hbase_env=$node_instance_dir/conf/hbase-env.sh
    
    addXMLProperty $hbase_site_xml "hbase.rootdir" "$HBASE_ROOTDIR" 
	addXMLProperty $hbase_site_xml "hbase.zookeeper.quorum" "$HBASE_ZOOKEEPER_QUORUM" 
	addXMLProperty $hbase_site_xml "hbase.cluster.distributed" "true" 
	  
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    addXMLProperty $hbase_site_xml "hbase.tmp.dir" "$tempDir"
	
	stagingDir=$node_data_dir/hbase-staging
    mkdir $stagingDir
    addXMLProperty $hbase_site_xml "hbase.fs.tmp.dir" "$stagingDir"
	
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

println()
{
    echo $1
    echo ""
}
printports_()
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

start_HMaster()
{
  for (( i=1; i<=$NUMBER_OF_HMASTER; i++ ))
  do
     node_instance_dir=$INSTANCES/HMaster$i  
     $node_instance_dir/bin/hbase-daemon.sh start master
  done   
}
start_HRegionServer()
{
  for (( i=1; i<=$NUMBER_OF_HREGION_SERVER; i++ ))
  do
     node_instance_dir=$INSTANCES/HRegionServer$i
     $node_instance_dir/bin/hbase-daemon.sh start regionserver
  done   
}

stop_HMaster()
{
  for (( i=1; i<=$NUMBER_OF_HMASTER; i++ ))
  do
     node_instance_dir=$INSTANCES/HMaster$i  
     $node_instance_dir/bin/hbase-daemon.sh stop master
  done
}
stop_HRegionServer()
{
  for (( i=1; i<=$NUMBER_OF_HREGION_SERVER; i++ ))
  do
     node_instance_dir=$INSTANCES/HRegionServer$i
     $node_instance_dir/bin/hbase-daemon.sh stop regionserver
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