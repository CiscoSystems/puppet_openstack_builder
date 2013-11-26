#
# this script is responsible for performing initial setup
# configurations that are only necessary for our virtual
# box based installations.
#


# setup up Cisco repos and install Puppet 3.2
#
# we include Puppet 3.2 in the Cisco repo to avoid external
# dependencies
#
# rely on install.sh to set up Cisco repo for now
# 

case $::osfamily {
  'Redhat': {
    $puppet_version = latest
    $pkg_list       = ['git', 'curl', 'httpd']
  }
  'Debian': {
    $puppet_version = latest
    $pkg_list       = ['git', 'curl', 'vim', 'cobbler']
    package { 'puppet-common':
      ensure  => $puppet_version,
    }
  }
}

package { 'puppet':
  ensure  => $puppet_version,
}

# dns resolution should be setup correctly
if $::build_server_ip {
  host { 'build-server':
    ip => $::build_server_ip,
    host_aliases => "build-server.${::build_server_domain_name}"
  }
}

if $::apt_proxy_host {

  class { 'apt':
    proxy_host => $::apt_proxy_host,
    proxy_port => $::apt_proxy_port
  }
}

#
# configure data or all machines who
# have run mode set to master or apply
#
if $::puppet_run_mode != 'agent' {

  if $::osfamily == 'Debian' {
    package { 'puppetmaster-common':
      ensure  => $puppet_version,
      before  => Package['puppet'],
      require => Package['puppet-common']
    }
    package { 'puppetmaster-passenger':
      ensure  => $puppet_version,
      require => Package['puppet'],
    }
  }

  # set up our hiera-store!
  file { "${settings::confdir}/hiera.yaml":
    content =>
'
---
:backends:
  - data_mapper
:hierarchy:
  - "hostname/%{hostname}"
  - "client/%{clientcert}"
  - user
  - jenkins
  - user.%{scenario}
  - user.common
  - "vendor/osfamily/cisco_coi_%{osfamily}"
  - "osfamily/%{osfamily}"
  - "enable_ha/%{enable_ha}"
  - "install_tempest/%{install_tempest}"
  - "cinder_backend/%{cinder_backend}"
  - "glance_backend/%{glance_backend}"
  - "rpc_type/%{rpc_type}"
  - "db_type/%{db_type}"
  - "tenant_network_type/%{tenant_network_type}"
  - "network_type/%{network_type}"
  - "network_plugin/%{network_plugin}"
  - "password_management/%{password_management}"
  - "scenario/%{scenario}"
  - grizzly_hack
  - vendor/cisco_coi_common
  - common
:yaml:
   :datadir: /etc/puppet/data/hiera_data
:data_mapper:
   # this should be contained in a module
   :datadir: /etc/puppet/data/data_mappings
'
  }

  # add the correct node terminus
  ini_setting {'puppetmastermodulepath':
    ensure  => present,
    path    => '/etc/puppet/puppet.conf',
    section => 'main',
    setting => 'node_terminus',
    value   => 'scenario',
    require => Package['puppet'],
  }
}

# lay down a file that can be used for subsequent runs to puppet. Often, the
# only thing that you want to do after the initial provisioning of a box is
# to run puppet again. This command lays down a script that can be simply used for
# subsequent runs
file { '/root/run_puppet.sh':
  content =>
  "#!/bin/bash
  puppet apply --modulepath /etc/puppet/modules-0/ --certname ${clientcert} /etc/puppet/manifests/site.pp $*"
}

package { $pkg_list :
  ensure => present,
}
