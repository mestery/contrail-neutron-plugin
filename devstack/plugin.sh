#!/bin/bash
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# Save trace settings
MY_XTRACE=$(set +o | grep xtrace)
set +o xtrace

CONTRAIL_INSTALLER=contrail-installer
CONTRAIL_INSTALLER_REPO=${CONTRAIL_INSTALL_REPO:https://github.com/Juniper/contrail-installer.git}
CONTRAIL_BRANCH=${CONTRAIL_BRANCH:master}
CONTRAIL_CONF_DIR=/etc/contrail

function is_contrail_service_enabled {
    contrail_service=$1
    is_service_enabled contrail && return 0
    is_service_enabled $contrail_service && return 0
    return 1
}

function install_contrail {
    local _pwd=$(pwd)
    echo "Installing OpenContrail and dependent packages"

    cd $DEST
    # Clone OpenContrail installer
    if [ ! -d "$CONTRAIL_INSTALLER" ]; then
        git clone $CONTRAIL_INSTALLER_REPO
        cd $CONTRAIL_INSTALLER
        git checkout $CONTRAIL_BRANCH
    else
        cd $CONTRAIL_INSTALLER
    fi

    # Copy the sample OpenContrail localrc file over
    cp samples/localrc-all localrc

    # Required packages
    install_package ebtables

    cd $_pwd
}

function start_contrail {
    echo "Starting OpenContrail"

    local _pwd=$(pwd)
    cd $DEST/$CONTRAIL_INSTALLER

    # Note: Contrail starts it's own screen service
    ./contrail.sh build
    ./contrail.sh install
    ./contrail.sh configure
    ./contrail.sh start
}

function stop_contrail {
    echo "Stopping OpenContrail"

    cd $DEST/$CONTRAIL_INSTALLER

    ./contrail.sh stop
}

function configure_contrail {
    :
}

function configure_contrail_plugin {
    Q_PLUGIN_CONF_PATH=${Q_PLUGIN_CONF_PATH:-etc/neutron/plugins/opencontrail}
    Q_PLUGIN_CONF_FILENAME=${Q_PLUGIN_CONF_FILENAME:-ContrailPlugin.ini}
    Q_DB_NAME=neutron
    Q_PLUGIN_CLASS=${Q_PLUGIN_CLASS:-neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_v3.NeutronPluginContrailCoreV3}

    local NEUTRON_CONF_PLUGIN_DIR=$NEUTRON_DIR/$Q_PLUGIN_CONF_PATH
    mkdir -p $NEUTRON_CONF_PLUGIN_DIR
    local NEUTRON_PLUGIN_CONF=$NEUTRON_CONF_PLUGIN_DIR/$Q_PLUGIN_CONF_FILENAME
    touch $NEUTRON_PLUGIN_CONF

    local MULTI_TENANCY=${MULTI_TENANCY:-False}
    local APISERVER_PORT=${APISERVER_PORT:-8082}
    local APISERVER_IP=${APISERVER_IP:-localhost}

    iniset $NEUTRON_PLUGIN_CONF CONTRAIL multi_tenancy $MULTI_TENANCY
    iniset $NEUTRON_PLUGIN_CONF CONTRAIL api_server_port $APISERVER_PORT
    iniset $NEUTRON_PLUGIN_CONF CONTRAIL api_server_ip $APISERVER_IP

    iniset $NEUTRON_CONF quotas quota_driver neutron.quota.ConfDriver
    local PY_PLUGIN_PATH=$(python -c "import neutron_plugin_contrail; print neutron_plugin_contrail.__path__[0]")
    iniset $NEUTRON_CONF DEFAULT api_extensions_path extensions:$PY_PLUGIN_PATH/extensions

    iniset $NOVA_CONF DEFAULT network_api_class nova_contrail_vif.contrailvif.ContrailNetworkAPI
}

# main loop
if is_contrail_service_enabled contrail; then
    if [[ "$1" == "stack" && "$2" == "install" ]]; then
        if [[ "$OFFLINE" != "True" ]]; then
            install_contrail
        fi
        configure_contrail
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        configure_contrail_plugin

        if is_service_enabled nova; then
            create_nova_conf_neutron
        fi

        start_contrail
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_contrail
    fi
fi

# Restore xtrace
$MY_XTRACE
