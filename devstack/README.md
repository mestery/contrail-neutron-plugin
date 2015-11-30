======================
 Enabling in Devstack
======================

1. Download devstack and contrail-neutron-plugin::

     git clone http://git.openstack.org/openstack-dev/devstack.git
     git clone https://github.com/Juniper/contrail-neutron-plugin.git

2. Add contrail-neutron-plugin to devstack.  The minimal set of critical
   local.conf additions are the following::

     cd devstack
     cat << EOF >> local.conf
     > enable_plugin contrail-neutron-plugin https://github.com/Juniper/contrail-neutron-plugin.git
     > enable_service contrail
     > EOF

You can also use the provided example local.conf, or look at its contents to add
to your own::

     cd devstack
     cp ../contrail-neutron-plugin/devstack/local.conf.sample local.conf

3. run devstack::

     ./stack.sh
