INSTALLATION_BASE_DIR=/home/sage/hadoop
INSTALLATION_CONF_DIR=/home/sage/hadoop/conf
ZOOKEEPER_RELEASE=/home/sage/hadoop-2.7.0.tar.gz
NUMBER_OF_NAMENODE=1
NUMBER_OF_DATANODE=3
NUMBER_OF_JOURNALNODE=3
HDFS_CLIENT_PORT_BASE=9000
REPLICATION=3
#ports
NAMENODE_HTTP_ADDRESS_BASE=50070
DATANODE_HTTP_ADDRESS_BASE=50075
DATANODE_ADDRESS_BASE=50010
DATANODE_IPC_ADDRESS_BASE=50020
CLIENT_PORT_BASE=2181
CLIENT_SECURE_PORT_BASE=3181
PEER_COM_PORT_BASE=2888
LEADER_ELEC_PORT_BASE=3888
ADMIN_SERVER_PORT_BASE=8088
JMX_PORT_BASE=9088
DEBUG_PORT_BASE=4444
DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances


install_()
{
    # Prepare installation directory structure
    #rm -r $INSTALLATION_BASE_DIR
    #mkdir $INSTALLATION_BASE_DIR
    #mkdir $DATAS
    #mkdir $INSTANCES
    extract_hadoop
    configure_hadoop
}
configure_hadoop()
{
configure_namenode
configure_datanode
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
    defaultFS="\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:$HDFS_CLIENT_PORT_BASE</value>\n\t</property>\n</configuration>"
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
    data_node_ipc_add_prop="\t<property>\n\t\t<name>dfs.datanode.address</name>\n\t\t<value>0.0.0.0:$data_node_ipc_port</value>\n\t</property>\n</configuration>"
    sed -i "s|</configuration>|$data_node_ipc_add_prop|" $hdfs_site_xml
    
done

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
    defaultFS="\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:$HDFS_CLIENT_PORT_BASE</value>\n\t</property>\n</configuration>"
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
done

}
extract_hadoop()
{
    extract_namenode
    extract_datanode
    #extract_journalnode
}
extract_namenode()
{
#Extract release
println "Extracting name node"
for (( i=1; i<=$NUMBER_OF_NAMENODE; i++ ))
do
    node_instance_dir=$INSTANCES/nameNode$i
    rm -r $node_instance_dir
    mkdir $node_instance_dir
    tar -mxf $ZOOKEEPER_RELEASE -C $node_instance_dir --strip-components 1 
    
    node_data_dir=$DATAS/nameNodeData$i
    rm -r $node_data_dir
    mkdir $node_data_dir
done
}
extract_datanode()
{
#Extract release
println "Extracting data node"
for (( i=1; i<=$NUMBER_OF_DATANODE; i++ ))
do
    node_instance_dir=$INSTANCES/dataNode$i
    rm -r $node_instance_dir
    mkdir $node_instance_dir
    
    tar -mxf $ZOOKEEPER_RELEASE -C $node_instance_dir --strip-components 1 
    
    node_data_dir=$DATAS/dataNodeData$i
    rm -r $node_data_dir
    mkdir $node_data_dir
done
}
extract_journalnode()
{
#Extract release
println "Extracting journal node"
for (( i=1; i<=$NUMBER_OF_JOURNALNODE; i++ ))
do
    node_instance_dir=$INSTANCES/journalNode$i
    mkdir $node_instance_dir
    tar -mxf $ZOOKEEPER_RELEASE -C $node_instance_dir --strip-components 1 
    
    node_data_dir=$DATAS/journalNodeData$i
    mkdir $node_data_dir
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


stop_()
{
    for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
    do
        $INSTANCES/zookeeper$i/bin/zkServer.sh stop
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
    for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
    do
        $INSTANCES/zookeeper$i/bin/zkServer.sh status
    done
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





