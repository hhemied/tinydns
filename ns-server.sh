#!/bin/bash

# Server version: Red Hat Enterprise Linux 7 and CentOS 7
# Using default firewalld

currentTimestamp=`date +%y-%m-%d-%H:%M:%S`

prefix=""

rpm -q bind bind-chroot
if [ $? -ne 0 ]; then
  echo "You didn't install the bind bind-chroot package, please install it before running this script"
  echo "The command is 'yum install bind bind-chroot -y'"
  exit 1
fi

configFile=$prefix/etc/named.conf
configFileBackup=$configFile.backup.${currentTimestamp}
if [ -f $configFile ]; then
    echo backup $configFile $configFileBackup
    cp $configFile $configFileBackup
fi
echo "Write the configure to bind configuration file $configFile"
cat > $configFile <<EOF
options {

        listen-on port 53 { any; };
        listen-on-v6 port 53 { any; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        allow-query     { any; };
        allow-query-cache { any; };
        recursion yes;
        allow-transfer  { none; };
        forwarders {
		       1.1.1.1;
	      };
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};




zone "." IN {
        type hint;
        file "named.ca";
};

zone "lab.local" IN {
        type master;
        file "named.example0.com";
};

EOF
chown root:named $configFile

configFile=$prefix/var/named/named.ca
if [ ! -s $configFile ]; then
cat > $configFile <<EOF
EOF
chown root:named $configFile
fi


configFile=$prefix/var/named/named.example0.com
configFileBackup=$configFile.backup.${currentTimestamp}
if [ -f $configFile ]; then
    echo backup $configFile $configFileBackup
    cp $configFile $configFileBackup
fi
echo "Write RR to $configFile"
cat > $configFile <<EOF
\$TTL    600
@   IN SOA  dns.lab.local. root.mail.lab.local. (
                     2019020800   ; serial
                     1800  ; refresh
                     1800  ; retry
                     604800  ; expire
                     86400 )    ; minimum

@ IN NS dns.lab.local.

dns.lab.local.        IN  A   10.0.0.10
ctl.lab.local.        IN  A   10.0.0.11
servera.lab.local.    IN  A   10.0.0.12
serverb.lab.local.    IN  A   10.0.0.13

EOF
chown root:named $configFile


echo "Start named service, and set it to run on startup"
systemctl status named-chroot
if [ $? == 0 ]; then
  systemctl restart named-chroot
else
  systemctl start named-chroot
fi
# Check the result of starting/restarting service
if [ $? -ne 0 ]; then
 echo "Can't start named service, make sure you have the right permission and SELinux setting"
 exit 1
fi
systemctl enable named-chroot




systemctl status firewalld
if [ $? == 0 ]; then
  firewall-cmd --permanent --add-port=53/udp
  firewall-cmd --permanent --add-port=53/tcp
  firewall-cmd --reload
fi