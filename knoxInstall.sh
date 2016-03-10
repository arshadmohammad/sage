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

INSTALLATION_BASE_DIR=$BASE_DIR/knox
RESOURCE_DIR=$BASE_DIR/resources
KNOX_RELEASE=$BASE_DIR/knox-0.7.0-SNAPSHOT.tar.gz

DATAS=$INSTALLATION_BASE_DIR/datas
INSTANCES=$INSTALLATION_BASE_DIR/instances
NUMBER_OF_KNOX=1
#gateway can not be started with root. it must be some other user
KNOX_USER=knox

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
  extract_knox
  configure_knox
}
extract_knox()
{
  extractModule "knox" $NUMBER_OF_KNOX
}
configure_knox()
{  
  for (( i=1; i<=$NUMBER_OF_KNOX; i++ ))
  do
     node_instance_dir=$INSTANCES/knox$i
	 # Make knox user the owner
	 echo "changing ownership to $KNOX_USER user"
	 chown -R $KNOX_USER $node_instance_dir
	 chmod -R u+rwx $node_instance_dir
	 	
  done
}
start_()
{
  createMaster
  start_LDAP
  start_knox  
}
stop_()
{
  stop_LDAP
  stop_knox
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
    tar -mxf $KNOX_RELEASE -C $node_instance_dir --strip-components 1 
    
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

printports_()
{
  echo "print ports"
}

createMaster()
{
  for (( i=1; i<=NUMBER_OF_KNOX; i++ ))
  do
     node_instance_dir=$INSTANCES/knox$i  
	 if [ ! -f "$node_instance_dir/data/security/master" ]; then
	    su - knox -c "$node_instance_dir/bin/knoxcli.sh create-master"
	 fi
  done   
}
start_LDAP()
{ 
  
  for (( i=1; i<=NUMBER_OF_KNOX; i++ ))
  do
    
     node_instance_dir=$INSTANCES/knox$i
     $node_instance_dir/bin/ldap.sh start
  done 
  
}
start_knox()
{
  for (( i=1; i<=$NUMBER_OF_KNOX; i++ ))
  do
     node_instance_dir=$INSTANCES/knox$i
	 # knox must not be started with root user
     su - knox -c "$node_instance_dir/bin/gateway.sh start"
  done
}

stop_LDAP()
{
  for (( i=1; i<=NUMBER_OF_KNOX; i++ ))
  do
     node_instance_dir=$INSTANCES/knox$i  
     $node_instance_dir/bin/ldap.sh stop
  done 
}
stop_knox()
{
  for (( i=1; i<=$NUMBER_OF_KNOX; i++ ))
  do
     node_instance_dir=$INSTANCES/knox$i
     $node_instance_dir/bin/gateway.sh stop
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