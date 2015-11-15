INSTALLATION_BASE_DIR=/home/sage/zk
RESOURCE_DIR=/home/sage/resources
ZOOKEEPER_RELEASE=/home/sage/zookeeper-3.6.0-SNAPSHOT.tar.gz
NUMBER_OF_INSTANCES=3
CLIENT_PORT_BASE=2181
CLIENT_SECURE_PORT_BASE=3181
PEER_COM_PORT_BASE=2888
LEADER_ELEC_PORT_BASE=3888
ADMIN_SERVER_PORT_BASE=8088
JMX_PORT_BASE=9088
DEBUG_PORT_BASE=4444
DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances
AUTHENTION=true
SECURE=true


install_()
{
    # Prepare installation directory structure
    rm -r $INSTALLATION_BASE_DIR
    mkdir $INSTALLATION_BASE_DIR



    mkdir $DATAS
    mkdir $INSTANCES


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
      if [ $AUTHENTION ]; then
        cp  $RESOURCE_DIR/common/hadoop.keytab $zoo_instance_dir/conf/
        cp  $RESOURCE_DIR/zookeeper/jaas.conf $zoo_instance_dir/conf/
        cp  $RESOURCE_DIR/common/krb5.conf $zoo_instance_dir/conf/
        sed -i "s|keyTab=.*|keyTab=\"$zoo_instance_dir/conf/hadoop.keytab\"|" $zoo_instance_dir/conf/jaas.conf
      fi      
      if [ $SECURE ]; then
        cp  $RESOURCE_DIR/common/keystore $zoo_instance_dir/conf/
      fi      
    done

    #Modify configuration properties
    println "Modifying configuration properties"
    for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
    do
        zoo_instance_dir=$INSTANCES/zookeeper$i
        cp $zoo_instance_dir/conf/zoo_sample.cfg $zoo_instance_dir/conf/zoo.cfg
        zoo_cfg_file=$zoo_instance_dir/conf/zoo.cfg    
        
        data_dir_location=$DATAS/data$i
        sed -i "s|dataDir=.*|dataDir=$data_dir_location|" $zoo_cfg_file    
        
        client_port=$(($CLIENT_PORT_BASE + $i - 1))
        sed -i "s/clientPort=.*/clientPort=$client_port/" $zoo_cfg_file    
        
        if [ $SECURE ]; then
          secure_client_port=$(($CLIENT_SECURE_PORT_BASE + $i - 1))
          echo "secureClientPort=$secure_client_port" >> $zoo_cfg_file          
          #ssl configurations
          keystore_location=$zoo_instance_dir/conf/keystore
          echo "ssl.keyStore.location=$keystore_location" >> $zoo_cfg_file
          echo "ssl.keyStore.password=mypass" >> $zoo_cfg_file
          echo "ssl.trustStore.location=$keystore_location" >> $zoo_cfg_file
          echo "ssl.trustStore.password=mypass" >> $zoo_cfg_file      
        fi        
        
        admin_port=$(($ADMIN_SERVER_PORT_BASE + $i - 1))
        echo "admin.serverPort=$admin_port" >> $zoo_cfg_file        
        
        dynamic_file_location=$zoo_instance_dir/conf/$dynamic_config_file
        echo "dynamicConfigFile=$dynamic_file_location" >> $zoo_cfg_file        
        
        #static configurations
        if [ $SECURE ]; then
          echo "serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory" >> $zoo_cfg_file
          echo "clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty" >> $zoo_cfg_file
        else
          echo "serverCnxnFactory=org.apache.zookeeper.server.NIOServerCnxnFactory" >> $zoo_cfg_file
          echo "clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNIO" >> $zoo_cfg_file
        fi 
        
        env_file=$zoo_instance_dir/bin/zkEnv.sh
        sed -i "s/ZOO_LOG4J_PROP=.*/ZOO_LOG4J_PROP=\"INFO,ROLLINGFILE\"/" $env_file
        
        if [ $AUTHENTION ]; then
          jaas_location=$zoo_instance_dir/conf/jaas.conf
          krb5_location=$zoo_instance_dir/conf/krb5.conf
          echo "export SERVER_JVMFLAGS=\"\$SERVER_JVMFLAGS -Djava.security.auth.login.config=$jaas_location -Djava.security.krb5.conf=$krb5_location -Dsun.security.krb5.debug=true\"" >> $env_file
          echo "authProvider.sasl=org.apache.zookeeper.server.auth.SASLAuthenticationProvider" >> $zoo_cfg_file
          echo "export CLIENT_JVMFLAGS=\"\$CLIENT_JVMFLAGS -Djava.security.auth.login.config=$jaas_location -Djava.security.krb5.conf=$krb5_location -Dsun.security.krb5.debug=true -Dzookeeper.server.principal=zookeeper/hadoop.com\"" >> $env_file
        fi
        
        jmx_port=$(($JMX_PORT_BASE + $i - 1))
        echo "export JMXPORT=\"$jmx_port\"" >> $env_file  
           
        server_file=$zoo_instance_dir/bin/zkServer.sh
        debug_port=$(($DEBUG_PORT_BASE + $i - 1))
        debug_options="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=$debug_port"
        sed -i "s|nohup \"\$JAVA\" \$ZOO_DATADIR_AUTOCREATE|nohup \"\$JAVA\" \$ZOO_DATADIR_AUTOCREATE $debug_options|" $server_file    
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
#start, stop, restart
runCommand()
{
for (( i=1; i<=$NUMBER_OF_INSTANCES; i++ ))
do
  $INSTANCES/zookeeper$i/bin/zkServer.sh $1
done

}
start_()
{
  println "Starting ZooKeeper servers"
  runCommand "start"
}
stop_()
{
  println "Stopping ZooKeeper servers"
  runCommand "stop"
}
restart_()
{
  runCommand "restart"
}
status_()
{
  runCommand "status"
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





