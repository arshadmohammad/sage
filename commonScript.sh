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
		echo $line >> $to
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
    key=$(echo $line| cut -d "=" -f1)
    value=$(echo $line| cut -d "=" -f2 | tr -d '\r' | tr -d '\n')
    addXMLProperty  $xmlFile $key $value
  done
}