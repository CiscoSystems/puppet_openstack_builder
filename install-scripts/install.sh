#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
#
set -u
set -x
set -e
set -e


# Master node or client (i.e., install puppet master or not)
# defaults to true
export master="${master:-true}"

# Add Cisco repo
cat > /etc/apt/sources.list.d/cisco-openstack-mirror_havana.list<<EOF
# cisco-openstack-mirror_havana
deb http://openstack-repo.cisco.com/openstack/cisco havana-proposed main
deb-src http://openstack-repo.cisco.com/openstack/cisco havana-proposed main
EOF

echo "-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.11 (GNU/Linux)

mQENBE/oXVkBCACcjAcV7lRGskECEHovgZ6a2robpBroQBW+tJds7B+qn/DslOAN
1hm0UuGQsi8pNzHDE29FMO3yOhmkenDd1V/T6tHNXqhHvf55nL6anlzwMmq3syIS
uqVjeMMXbZ4d+Rh0K/rI4TyRbUiI2DDLP+6wYeh1pTPwrleHm5FXBMDbU/OZ5vKZ
67j99GaARYxHp8W/be8KRSoV9wU1WXr4+GA6K7ENe2A8PT+jH79Sr4kF4uKC3VxD
BF5Z0yaLqr+1V2pHU3AfmybOCmoPYviOqpwj3FQ2PhtObLs+hq7zCviDTX2IxHBb
Q3mGsD8wS9uyZcHN77maAzZlL5G794DEr1NLABEBAAG0NU9wZW5TdGFja0BDaXNj
byBBUFQgcmVwbyA8b3BlbnN0YWNrLWJ1aWxkZEBjaXNjby5jb20+iQE4BBMBAgAi
BQJP6F1ZAhsDBgsJCAcDAgYVCAIJCgsEFgIDAQIeAQIXgAAKCRDozGcFPtOxmXcK
B/9WvQrBwxmIMV2M+VMBhQqtipvJeDX2Uv34Ytpsg2jldl0TS8XheGlUNZ5djxDy
u3X0hKwRLeOppV09GVO3wGizNCV1EJjqQbCMkq6VSJjD1B/6Tg+3M/XmNaKHK3Op
zSi+35OQ6xXc38DUOrigaCZUU40nGQeYUMRYzI+d3pPlNd0+nLndrE4rNNFB91dM
BTeoyQMWd6tpTwz5MAi+I11tCIQAPCSG1qR52R3bog/0PlJzilxjkdShl1Cj0RmX
7bHIMD66uC1FKCpbRaiPR8XmTPLv29ZTk1ABBzoynZyFDfliRwQi6TS20TuEj+ZH
xq/T6MM6+rpdBVz62ek6/KBcuQENBE/oXVkBCACgzyyGvvHLx7g/Rpys1WdevYMH
THBS24RMaDHqg7H7xe0fFzmiblWjV8V4Yy+heLLV5nTYBQLS43MFvFbnFvB3ygDI
IdVjLVDXcPfcp+Np2PE8cJuDEE4seGU26UoJ2pPK/IHbnmGWYwXJBbik9YepD61c
NJ5XMzMYI5z9/YNupeJoy8/8uxdxI/B66PL9QN8wKBk5js2OX8TtEjmEZSrZrIuM
rVVXRU/1m732lhIyVVws4StRkpG+D15Dp98yDGjbCRREzZPeKHpvO/Uhn23hVyHe
PIc+bu1mXMQ+N/3UjXtfUg27hmmgBDAjxUeSb1moFpeqLys2AAY+yXiHDv57ABEB
AAGJAR8EGAECAAkFAk/oXVkCGwwACgkQ6MxnBT7TsZng+AgAnFogD90f3ByTVlNp
Sb+HHd/cPqZ83RB9XUxRRnkIQmOozUjw8nq8I8eTT4t0Sa8G9q1fl14tXIJ9szzz
BUIYyda/RYZszL9rHhucSfFIkpnp7ddfE9NDlnZUvavnnyRsWpIZa6hJq8hQEp92
IQBF6R7wOws0A0oUmME25Rzam9qVbywOh9ZQvzYPpFaEmmjpCRDxJLB1DYu8lnC4
h1jP1GXFUIQDbcznrR2MQDy5fNt678HcIqMwVp2CJz/2jrZlbSKfMckdpbiWNns/
xKyLYs5m34d4a0it6wsMem3YCefSYBjyLGSd/kCI/CgOdGN1ZY1HSdLmmjiDkQPQ
UcXHbA==
=v6jg
-----END PGP PUBLIC KEY BLOCK-----" | apt-key add -

# Fix puppet, clobbering any existing puppet version to ensure
# we are using the puppet 3.2 we target
dpkg --purge puppet puppet-common
rm -rf /etc/puppet/puppet.conf /var/lib/puppet
apt-get update
apt-get install -y git apt rubygems puppet

# use the domain name if one exists
if [ "`hostname -d`" != '' ]; then
  domain=`hostname -d`
else
  # otherwise use the domain
  domain='domain.name'
fi
# puppet's fqdn fact explodes if the domain is not setup
if grep 127.0.1.1 /etc/hosts ; then
  sed -i -e "s/127.0.1.1.*/127.0.1.1 $(hostname).$domain $(hostname)/" /etc/hosts
else
  echo "127.0.1.1 $(hostname).$domain $(hostname)" >> /etc/hosts
fi;

# Install puppet_openstack_builder
cd /root/
if ! [ -d puppet_openstack_builder ]; then
  git clone -b coi-development https://github.com/CiscoSystems/puppet_openstack_builder.git /root/puppet_openstack_builder
fi


if ${master}; then
  # All in one defaults to the local host name for pupet master
  export build_server="${build_server:-`hostname`}"
  # We need to know the IP address as well, so either tell me
  # or I will assume it's the address associated with eth0
  export default_interface="${default_interface:-eth0}"
  # So let's grab that address
  export build_server_ip="${build_server_ip:-`ip addr show ${default_interface} | grep 'inet ' | tr '/' ' ' | awk -F' ' '{print $2}'`}"
  # Our default mode also assumes at least one other interface for OpenStack network
  export external_interface="${external_interface:-eth1}"

  # For good puppet hygene, we'll want NTP setup.  Let's borrow one from Cisco
  export ntp_server="${ntp_server:-ntp.esl.cisco.com}"

  # Since this is the master script, we'll run in apply mode
  export puppet_run_mode="apply"

  # scenarios will map to /etc/puppet/data/scenarios/*.yaml
  export scenario="${scenario:-all_in_one}"

  sed -e "s/scenario: .*/scenario: ${scenario}/" -i /root/puppet_openstack_builder/data/config.yaml

  if [ "${scenario}" == "all_in_one" ] ; then
    echo `hostname`: all_in_one >> /root/puppet_openstack_builder/data/role_mappings.yaml
    cat > /root/puppet_openstack_builder/data/hiera_data/user.yaml<<EOF
domain_name: "${domain}"
ntp_servers:
  - ${ntp_server}

# node addresses
build_node_name: ${build_server}
controller_internal_address: "${build_server_ip}"
controller_public_address: "${build_server_ip}"
controller_admin_address: "${build_server_ip}"
swift_internal_address: "${build_server_ip}"
swift_public_address: "${build_server_ip}"
swift_admin_address: "${build_server_ip}"

# physical interface definitions
external_interface: ${external_interface}
public_interface: ${default_interface}
private_interface: ${default_interface}

internal_ip: "%{ipaddress}"
swift_local_net_ip: "%{ipaddress}"
nova::compute::vncserver_proxyclient_address: "0.0.0.0"

quantum::agents::ovs::local_ip: "%{ipaddress}"
neutron::agents::ovs::local_ip: "%{ipaddress}"
EOF
  fi

  cd puppet_openstack_builder
  gem install librarian-puppet-simple --no-ri --no-rdoc
  export git_protocol='https'
  librarian-puppet install --verbose

  cp -R /root/puppet_openstack_builder/modules /etc/puppet/
  cp -R /root/puppet_openstack_builder/data /etc/puppet/
  cp -R /root/puppet_openstack_builder/manifests /etc/puppet/

  export FACTER_build_server=${build_server}

fi

export FACTER_build_server_domain_name=${domain}
export FACTER_build_server_ip=${build_server_ip}
export FACTER_puppet_run_mode="${puppet_run_mode:-agent}"

puppet apply /etc/puppet/manifests/setup.pp --modulepath modules --certname `hostname -f`

if  $master ; then
  puppet apply /etc/puppet/manifests/site.pp --certname ${build_server} --debug
  puppet plugin download --server `hostname -f`; service apache2 restart
fi
