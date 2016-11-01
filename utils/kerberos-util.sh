KRB_PRINCIPAL_FILE=princnames.txt
KEY_TAB_FILE=hadoop.keytab
list()
{
#Print all the principals
awk '{ print $1, $2 }' $KRB_PRINCIPAL_FILE
}

delete()
{
#Delete principals
awk '{ print "delprinc -force",$1 }' $KRB_PRINCIPAL_FILE | kadmin.local > /dev/null
}

create()
{
#Create principals
awk '{ print "addprinc +needchange -pw", $2, $1 }' $KRB_PRINCIPAL_FILE | kadmin.local> /dev/null
}

createKeyTab()
{
#Create key tab file
if [ -f "$KEY_TAB_FILE" ]; then
  rm $KEY_TAB_FILE
fi
awk '{ print "ktadd -k '$KEY_TAB_FILE' -q", $1}' $KRB_PRINCIPAL_FILE | kadmin.local > /dev/null
}

list
delete
create
createKeyTab