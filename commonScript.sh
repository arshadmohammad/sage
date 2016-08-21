source installConf.sh
getBaseDir()
{
	basedir=`dirname $0`
	if [ "${basedir}" = "." ]
	then
		basedir=`pwd`
	elif [ "${basedir}" = ".." ]
	then
		basedir=`(cd .. ;pwd)`
	fi
	echo $basedir
}

# file, key, value
addProperty()
{
  echo "export $2=$3" >> $1  
}
# source properties, target properties
addAllProperty()
{
	from=$1
	to=$2
	cat $from | while read line
	do
		if [[ $line == "#"* ]]; then
		  echo "line $line is commented"
		  continue
		fi
		line2=$( echo $line | sed "s|\${INSTALLATON_HOME}|$BASE_DIR|")
		echo $line2 >> $to
	done
}

# file, key, value
addXMLProperty()
{
  xml_file=$1
  key=$2
  value=$3
  property_xml="\t<property>\n\t\t<name>$key</name>\n\t\t<value>$value</value>\n\t</property>\n</configuration>"
  sed -i "s|</configuration>|$property_xml|" $xml_file
}

addAllXMLProperty()
{
  xmlFile=$1
  propertyFile=$2
  cat $propertyFile | while read line
  do
    if [[ $line == "#"* ]]; then
	  echo "line $line is commented"
	  continue
	fi
	line2=$( echo $line | sed "s|\${INSTALLATON_HOME}|$BASE_DIR|" )
    key=$(echo $line2| cut -d "=" -f1)
    value=$(echo $line2| cut -d "=" -f2 | tr -d '\r' | tr -d '\n')
    addXMLProperty  $xmlFile $key $value
  done
}
createSiteFile()
{
site_xml=$1
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $site_xml
echo "<configuration>" >> $site_xml
echo "</configuration>" >> $site_xml
}