#!/bin/bash

set -e


# Support docker run --init parameter which obsoletes the use of dumb-init,
# but support dumb-init for those that still use it without --init
if [ -x "/dev/init" ]; then
    run="exec"
else
    run="exec /usr/bin/dumb-init --"
fi

# Run dhcpd for specified interface or all interfaces
data_dir="/data"
if [ ! -d "$data_dir" ]; then
    echo "Please ensure '$data_dir' folder is available."
    echo 'If you just want to keep your configuration in "data/", add -v "$(pwd)/data:/data" to the docker run command line.'
    exit 1
fi

dhcpd_conf="$data_dir/dhcpd.conf"
if [ ! -r "$dhcpd_conf" ]; then
    echo "Please ensure '$dhcpd_conf' exists and is readable."
    echo "Run the container with arguments 'man dhcpd.conf' if you need help with creating the configuration."
    exit 1
fi

uid=$(stat -c%u "$data_dir")
gid=$(stat -c%g "$data_dir")
if [ $gid -ne 0 ]; then
    groupmod -g $gid dhcpd
fi
if [ $uid -ne 0 ]; then
    usermod -u $uid dhcpd
fi

[ -e "$data_dir/dhcpd.leases" ] || touch "$data_dir/dhcpd.leases"
chown dhcpd:dhcpd "$data_dir/dhcpd.leases"
if [ -e "$data_dir/dhcpd.leases~" ]; then
    chown dhcpd:dhcpd "$data_dir/dhcpd.leases~"
fi

container_id=$(grep docker /proc/self/cgroup | sort -n | head -n 1 | cut -d: -f3 | cut -d/ -f3)
if perl -e '($id,$name)=@ARGV;$short=substr $id,0,length $name;exit 1 if $name ne $short;exit 0' $container_id $HOSTNAME; then
    echo "You must add the 'docker run' option '--net=host' if you want to provide DHCP service to the host network."
fi

echo "Hello!!!!!"

$run /usr/sbin/dhcpd -4 -f -d --no-pid -cf "$data_dir/dhcpd.conf" -lf "$data_dir/dhcpd.leases" "$@"
