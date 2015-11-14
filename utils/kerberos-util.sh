#Print all the principals
awk '{ print $1, $2 }' princnames.txt

#Delete principals
awk '{ print "delprinc -force",$1 }' princnames.txt | kadmin.local > /dev/null

#Create principals
awk '{ print "addprinc +needchange -pw", $2, $1 }' princnames.txt | kadmin.local> /dev/null

#Create key tab file
KEY_TAB_FILE=hadoop.keytab
if [ -f "$KEY_TAB_FILE" ]; then
  rm $KEY_TAB_FILE
fi
awk '{ print "ktadd -k '$KEY_TAB_FILE' -q", $1}' princnames.txt | kadmin.local > /dev/null
