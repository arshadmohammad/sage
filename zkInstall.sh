INSTALLATION_BASE_DIR=/home/zk
INSTALLATION_CONF_DIR=/home/sage/zookeeper/conf
ZOOKEEPER_RELEASE=/opt/releases/zookeeper-3.6.0-SNAPSHOT.tar.gz
NUMBER_OF_INSTANCES=3
CLIENT_PORT_BASE=2181
CLIENT_SECURE_PORT_BASE=3181
PEER_COM_PORT_BASE=2888
LEADER_ELEC_PORT_BASE=3888
ADMIN_SERVER_PORT_BASE=8088
JMX_PORT_BASE=9088
DEBUG_PORT_BASE=4444


# Prepare installation directory structure
rm -r $INSTALLATION_BASE_DIR
mkdir $INSTALLATION_BASE_DIR

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances

mkdir $DATAS
mkdir $INSTANCES

println()
{
echo $1
echo ""

}
# Extract release
println "Creating installation folder structure"
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
do
    zoo_instance_dir=$INSTANCES/zookeeper$i
    mkdir $zoo_instance_dir
    tar -mxf $ZOOKEEPER_RELEASE -C $zoo_instance_dir --strip-components 1 
    
    zoo_data_dir=$DATAS/data$i
    mkdir $zoo_data_dir
done

# Create dynamic configuration
dynamic_config_file="dynamic_zoo.cfg.dynamic"
rm -f $dynamic_config_file
println "Creating dynamic configuration"
echo "#Zookeeper dynamic configuration" >> $dynamic_config_file
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
do
    server_id=$i
    peer_port=$(($PEER_COM_PORT_BASE + $i - 1))
    leader_elec_port=$(($LEADER_ELEC_PORT_BASE + $i - 1))
    dynamic_config_part="server.$server_id=localhost:$peer_port:$leader_elec_port:participant"
    echo "$dynamic_config_part" >> $dynamic_config_file
done

# Create server ids
println "Creating server ids"
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
do
    server_id=$i
    sid_file="$DATAS/data$i/myid"
    echo "$server_id" >> $sid_file
done


#Copy resources
println "Copying resources"
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
do
  zoo_instance_dir=$INSTANCES/zookeeper$i  
  cp  $dynamic_config_file $zoo_instance_dir/conf/
  cp  $INSTALLATION_CONF_DIR/keystore $zoo_instance_dir/conf/
done

#Modify configuration croperties
println "Modifying configuration properties"
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
do
    cp $INSTANCES/zookeeper$i/conf/zoo_sample.cfg $INSTANCES/zookeeper$i/conf/zoo.cfg
    zoo_cfg_file=$INSTANCES/zookeeper$i/conf/zoo.cfg    
    
    data_dir_location=$DATAS/data$i
    sed -i "s|dataDir=.*|dataDir=$data_dir_location|" $zoo_cfg_file    
    
    client_port=$(($CLIENT_PORT_BASE + $i - 1))
    sed -i "s/clientPort=.*/clientPort=$client_port/" $zoo_cfg_file    
   
    secure_client_port=$(($CLIENT_SECURE_PORT_BASE + $i - 1))
    echo "secureClientPort=$secure_client_port" >> $zoo_cfg_file
    
    admin_port=$(($ADMIN_SERVER_PORT_BASE + $i - 1))
    echo "admin.serverPort=$admin_port" >> $zoo_cfg_file
    
    
    dynamic_file_location=$INSTANCES/zookeeper$i/conf/$dynamic_config_file
    echo "dynamicConfigFile=$dynamic_file_location" >> $zoo_cfg_file
    
    #ssl configurations
    keystore_location=$INSTANCES/zookeeper$i/conf/keystore
    echo "ssl.keyStore.location=$keystore_location" >> $zoo_cfg_file
    echo "ssl.keyStore.password=mypass" >> $zoo_cfg_file
    echo "ssl.trustStore.location=$keystore_location" >> $zoo_cfg_file
    echo "ssl.trustStore.password=mypass" >> $zoo_cfg_file
    
    
    #static configurations
    echo "serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory" >> $zoo_cfg_file
    echo "clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty" >> $zoo_cfg_file
    echo "client.secure=true" >> $zoo_cfg_file   
    
    env_file=$INSTANCES/zookeeper$i/bin/zkEnv.sh
    sed -i "s/ZOO_LOG4J_PROP=.*/ZOO_LOG4J_PROP=\"INFO,ROLLINGFILE\"/" $env_file
    
    jmx_port=$(($JMX_PORT_BASE + $i - 1))
    echo "export JMXPORT=\"$jmx_port\"" >> $env_file  
       
    
    debug_port=$(($DEBUG_PORT_BASE + $i - 1))
    debug_options="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port"
    echo "export SERVER_JVMFLAGS=\"$debug_options $SERVER_JVMFLAGS\"" >> $env_file 
    
    
    
    
done








