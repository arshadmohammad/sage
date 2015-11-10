INSTALLATION_BASE_DIR=/home/sage/hadoop
INSTALLATION_CONF_DIR=/home/sage/hadoop/conf
HADOOP_RELEASE=/home/sage/hadoop-2.7.0.tar.gz
NUMBER_OF_NAMENODE=2
NUMBER_OF_DATANODE=3
NUMBER_OF_JOURNALNODE=3
NUMBER_OF_RESOURCEMANAGER=2
NUMBER_OF_NODEMANAGER=3

REPLICATION=3
#Name node ports
NAMENODE_HTTP_ADDRESS_BASE=50070
NAMENODE_IPC_ADDRESS_BASE=9000
NAMENODE_JMX_PORT_BASE=8004
NAMENODE_DEBUG_PORT_BASE=4400

#Data node ports
DATANODE_HTTP_ADDRESS_BASE=50075
DATANODE_ADDRESS_BASE=50010
DATANODE_IPC_ADDRESS_BASE=50020
DATANODE_JMX_PORT_BASE=8010
DATANODE_DEBUG_PORT_BASE=4410

#Resource Manager ports
RESOURCEMANAGER_ADDRESS_BASE=8032
RESOURCEMANAGER_SCHEDULER_ADDRESS_BASE=8030
RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS_BASE=8040
RESOURCEMANAGER_ADMIN_ADDRESS_BASE=8035
RESOURCEMANAGER_WEBAPP_ADDRESS_BASE=8088
RESOURCEMANAGER_JMX_PORT_BASE=8090

#Node Manager ports
NODEMANAGER_ADDRESS_BASE=9032
NODEMANAGER_LOCALIZER_ADDRESS_BASE=9040
NODEMANAGER_WEBAPP_ADDRESS_BASE=9052
NODEMANAGER_JMX_PORT_BASE=8095

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances

install_()
{
    #Prepare installation directory structure
    rm -r $INSTALLATION_BASE_DIR
    mkdir $INSTALLATION_BASE_DIR
    mkdir $DATAS
    mkdir $INSTANCES
    stop_
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

configure_hadoop()
{
    configure_namenode
    configure_datanode
    configure_resourcemanager
    configure_nodemanager
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
    defaultFS="\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:$name_node_rpc_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$defaultFS|" $core_site_xml    
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    tempDirProp="\t<property>\n\t\t<name>hadoop.tmp.dir</name>\n\t\t<value>$tempDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$tempDirProp|" $core_site_xml
    
    
    replication="\t<property>\n\t\t<name>dfs.replication</name>\n\t\t<value>$REPLICATION</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$replication|" $hdfs_site_xml 
    
    nameDir=$node_data_dir/name
    mkdir $nameDir
    nameDirProp="\t<property>\n\t\t<name>dfs.namenode.name.dir</name>\n\t\t<value>$nameDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$nameDirProp|" $hdfs_site_xml 

    editDir=$node_data_dir/edit
    mkdir $editDir
    editDirProp="\t<property>\n\t\t<name>dfs.namenode.edits.dir</name>\n\t\t<value>$editDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$editDirProp|" $hdfs_site_xml

    http_port=$(($NAMENODE_HTTP_ADDRESS_BASE + $i - 1))
    http_address_prop="\t<property>\n\t\t<name>dfs.namenode.http-address</name>\n\t\t<value>0.0.0.0:$http_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$http_address_prop|" $hdfs_site_xml
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    echo "export HADOOP_PID_DIR=$pidDir" >> $hadoop_env
    
    jmx_port=$(($NAMENODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $HADOOP_NAMENODE_OPTS"
    echo "export HADOOP_NAMENODE_OPTS=\"$jmx_prop\"" >> $hadoop_env
    
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
    defaultFS="\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:$NAMENODE_IPC_ADDRESS_BASE</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$defaultFS|" $core_site_xml    
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    tempDirProp="\t<property>\n\t\t<name>hadoop.tmp.dir</name>\n\t\t<value>$tempDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$tempDirProp|" $core_site_xml
    
    
    replication="\t<property>\n\t\t<name>dfs.replication</name>\n\t\t<value>$REPLICATION</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$replication|" $hdfs_site_xml 
    
    dataDir=$node_data_dir/data
    mkdir $dataDir
    dataDirProp="\t<property>\n\t\t<name>dfs.datanode.data.dir</name>\n\t\t<value>$dataDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$dataDirProp|" $hdfs_site_xml

    http_port=$(($DATANODE_HTTP_ADDRESS_BASE + $i - 1))
    http_address_prop="\t<property>\n\t\t<name>dfs.datanode.http.address</name>\n\t\t<value>0.0.0.0:$http_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$http_address_prop|" $hdfs_site_xml

    data_node_port=$(($DATANODE_ADDRESS_BASE + $i - 1))
    data_node_add_prop="\t<property>\n\t\t<name>dfs.datanode.address</name>\n\t\t<value>0.0.0.0:$data_node_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$data_node_add_prop|" $hdfs_site_xml 
    
    data_node_ipc_port=$(($DATANODE_IPC_ADDRESS_BASE + $i - 1))
    data_node_ipc_add_prop="\t<property>\n\t\t<name>dfs.datanode.ipc.address</name>\n\t\t<value>0.0.0.0:$data_node_ipc_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$data_node_ipc_add_prop|" $hdfs_site_xml
    
    
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    echo "HADOOP_PID_DIR=$pidDir" >> $hadoop_env
    
    jmx_port=$(($DATANODE_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $HADOOP_DATANODE_OPTS"
    echo "export HADOOP_DATANODE_OPTS=\"$jmx_prop\"" >> $hadoop_env
        
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
    defaultFS="\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:$NAMENODE_IPC_ADDRESS_BASE</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$defaultFS|" $core_site_xml    
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    tempDirProp="\t<property>\n\t\t<name>hadoop.tmp.dir</name>\n\t\t<value>$tempDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$tempDirProp|" $core_site_xml

    resourcemanager_hostname=="\t<property>\n\t\t<name>yarn.resourcemanager.hostname</name>\n\t\t<value>0.0.0.0</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$resourcemanager_hostname|" $yarn_site_xml
    
    resourcemanager_port=$(($RESOURCEMANAGER_ADDRESS_BASE + $i - 1))
    resourcemanager_port_prop="\t<property>\n\t\t<name>yarn.resourcemanager.address</name>\n\t\t<value>\${yarn.resourcemanager.hostname}:$resourcemanager_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$resourcemanager_port_prop|" $yarn_site_xml
    
    resourcemanager_scheduler_port=$(($RESOURCEMANAGER_SCHEDULER_ADDRESS_BASE + $i - 1))
    resourcemanager_scheduler_port_prop="\t<property>\n\t\t<name>yarn.resourcemanager.scheduler.address</name>\n\t\t<value>\${yarn.resourcemanager.hostname}:$resourcemanager_scheduler_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$resourcemanager_scheduler_port_prop|" $yarn_site_xml
    
    resourcemanager_resource_tracker_port=$(($RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS_BASE + $i - 1))
    resourcemanager_resource_tracker_port_prop="\t<property>\n\t\t<name>yarn.resourcemanager.resource-tracker.address</name>\n\t\t<value>\${yarn.resourcemanager.hostname}:$resourcemanager_resource_tracker_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$resourcemanager_resource_tracker_port_prop|" $yarn_site_xml
    
    resourcemanager_admin_address_port=$(($RESOURCEMANAGER_ADMIN_ADDRESS_BASE + $i - 1))
    resourcemanager_admin_address_port_prop="\t<property>\n\t\t<name>yarn.resourcemanager.admin.address</name>\n\t\t<value>\${yarn.resourcemanager.hostname}:$resourcemanager_admin_address_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$resourcemanager_admin_address_port_prop|" $yarn_site_xml
    
    resourcemanager_webapp_address_port=$(($RESOURCEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))
    resourcemanager_webapp_address_port_prop="\t<property>\n\t\t<name>yarn.resourcemanager.webapp.address</name>\n\t\t<value>\${yarn.resourcemanager.hostname}:$resourcemanager_webapp_address_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$resourcemanager_webapp_address_port_prop|" $yarn_site_xml  
    
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    echo "YARN_PID_DIR=$pidDir" >> $yarn_env
    
    jmx_port=$(($RESOURCEMANAGER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $YARN_OPTS"
    echo "export YARN_OPTS=\"$jmx_prop\"" >> $yarn_env
        
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
    defaultFS="\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:$NAMENODE_IPC_ADDRESS_BASE</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$defaultFS|" $core_site_xml    
    
    tempDir=$node_data_dir/temp
    mkdir $tempDir
    tempDirProp="\t<property>\n\t\t<name>hadoop.tmp.dir</name>\n\t\t<value>$tempDir</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$tempDirProp|" $core_site_xml

    nodemanager_hostname=="\t<property>\n\t\t<name>yarn.nodemanager.hostname</name>\n\t\t<value>0.0.0.0</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$nodemanager_hostname|" $yarn_site_xml
    
    nodemanager_address_port=$(($NODEMANAGER_ADDRESS_BASE + $i - 1))
    nodemanager_address_prop="\t<property>\n\t\t<name>yarn.nodemanager.address</name>\n\t\t<value>\${yarn.nodemanager.hostname}:$nodemanager_address_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$nodemanager_address_prop|" $yarn_site_xml
    
    nodemanager_localizer_address_port=$(($NODEMANAGER_LOCALIZER_ADDRESS_BASE + $i - 1))
    nodemanager_localizer_address_port_prop="\t<property>\n\t\t<name>yarn.nodemanager.localizer.address</name>\n\t\t<value>\${yarn.nodemanager.hostname}:$nodemanager_localizer_address_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$nodemanager_localizer_address_port_prop|" $yarn_site_xml
    
    nodemanager_webapp_address_port=$(($NODEMANAGER_WEBAPP_ADDRESS_BASE + $i - 1))
    nodemanager_webapp_address_prop="\t<property>\n\t\t<name>yarn.nodemanager.webapp.address</name>\n\t\t<value>\${yarn.nodemanager.hostname}:$nodemanager_webapp_address_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$nodemanager_webapp_address_prop|" $yarn_site_xml   
    
    
    #Env configuration
    pidDir=$node_data_dir/pid
    mkdir $pidDir
    echo "YARN_PID_DIR=$pidDir" >> $yarn_env
    
    jmx_port=$(($NODEMANAGER_JMX_PORT_BASE + $i - 1))
    jmx_prop="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$jmx_port -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false $YARN_OPTS"
    echo "export YARN_OPTS=\"$jmx_prop\"" >> $yarn_env
        
done
}

println()
{
    echo $1
    echo ""
}
printports_()
{
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
    do
        server_id=$i
        peer_port=$(($PEER_COM_PORT_BASE + $i - 1))
        leader_elec_port=$(($LEADER_ELEC_PORT_BASE + $i - 1))
        client_port=$(($CLIENT_PORT_BASE + $i - 1))
        secure_client_port=$(($CLIENT_SECURE_PORT_BASE + $i - 1))
        admin_port=$(($ADMIN_SERVER_PORT_BASE + $i - 1))
        jmx_port=$(($JMX_PORT_BASE + $i - 1))
        echo server.$server_id=localhost:$peer_port:$leader_elec_port:participant;
        echo "clientPort="$client_port
        echo "secureClientPort="$secure_client_port
        echo "admin.serverPort="$admin_port
        echo "jmx_port="$jmx_port
        println
    done
}
start_()
{
start_name_node
start_data_node

start_resourcemanager
start_nodemanager

}
start_name_node()
{
for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
do
   node_instance_dir=$INSTANCES/nameNode$i
   $node_instance_dir/bin/hdfs namenode -format
   $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs start namenode
done   
}

start_data_node()
{
for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
   node_instance_dir=$INSTANCES/dataNode$i
   $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs start datanode
done   
}
start_resourcemanager()
{
for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
do
   node_instance_dir=$INSTANCES/resourceManager$i
   $node_instance_dir/sbin/yarn-daemon.sh --config $node_instance_dir/etc/hadoop start resourcemanager
done   
}

start_nodemanager()
{
for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
do
   node_instance_dir=$INSTANCES/nodeManager$i
   $node_instance_dir/sbin/yarn-daemon.sh --config $node_instance_dir/etc/hadoop start nodemanager
done   
}


stop_()
{
stop_data_node
stop_name_node
stop_nodemanager
stop_resourcemanager

}

stop_name_node()
{
for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
do
   node_instance_dir=$INSTANCES/nameNode$i   
   $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs stop namenode
done 
}
stop_data_node()
{
for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
   node_instance_dir=$INSTANCES/dataNode$i 
   $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop --script hdfs stop datanode
done 
}
stop_resourcemanager()
{
for (( i=1; i<=$NUMBER_OF_RESOURCEMANAGER; i++ ))
do
   node_instance_dir=$INSTANCES/resourceManager$i
   $node_instance_dir/sbin/yarn-daemon.sh --config $node_instance_dir/etc/hadoop stop resourcemanager
done   
}

stop_nodemanager()
{
for (( i=1; i<=$NUMBER_OF_NODEMANAGER; i++ ))
do
   node_instance_dir=$INSTANCES/nodeManager$i
   $node_instance_dir/sbin/hadoop-daemon.sh --config $node_instance_dir/etc/hadoop stop nodemanager
done   
}

restart_()
{
    for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
    do
        $INSTANCES/zookeeper$i/bin/zkServer.sh restart
    done
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





