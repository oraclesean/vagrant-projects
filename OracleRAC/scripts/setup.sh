#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2020 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      setup.sh - 
#
#    DESCRIPTION
#      Creates an Oracle RAC (Real Application Cluster) Vagrant virtual machine.
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    sscott      07/15/21 - Add support for multi-node RAC
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20210715 - $Revision: 2.0.2.2 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
. /vagrant/scripts/functions.sh

# ---------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------
run_user_scripts() {
  # run user-defined post-setup scripts
  info "Running user-defined post-setup scripts" 1
  for f in /vagrant/userscripts/*
    do
      case "${f,,}" in
        *.sh)
          info  "Running $f"
          . "$f"
          info "Done running $f"
          ;;
        *.sql)
          info "Running $f"
          su -l oracle -c "echo 'exit' | sqlplus -s / as sysdba @\"$f\""
          info "Done running $f"
          ;;
        /vagrant/userscripts/put_custom_scripts_here.txt)
          :
          ;;
        *)
          info "Ignoring $f"
          ;;
      esac
    done
}

make_07_setup_user_equ() {
  expectfile="/vagrant/scripts/07_setup_user_equ.expect"

cat > $expectfile << EOF
#!/usr/bin/expect -f
set timeout 20
set username [lindex \$argv 0]
set password [lindex \$argv 1]
set nodes    [lindex \$argv 2]
set path     [lindex \$argv 3]

spawn \$path -user \$username -hosts \$nodes -noPromptPassphrase -advanced

expect "Do you want to continue and let the script make the above mentioned changes (yes/no)?" { send "yes\\n" }
EOF

   for i in $(seq 1 $1)
    do cat >> $expectfile << EOF
expect  "password:" { send "\$password\\n" }
expect  "password:" { send "\$password\\n" }
EOF
  done

cat >> $expectfile << EOF
expect { default {} }
EOF
}

make_09_gi_installation() {
cat > /vagrant/scripts/09_gi_installation.sh <<EOF
. /vagrant/config/setup.env
${GI_HOME}/gridSetup.sh -ignorePrereq -waitforcompletion -silent \\
    -responseFile ${GI_HOME}/install/response/gridsetup.rsp \\
    INVENTORY_LOCATION=${ORA_INVENTORY} \\
    SELECTED_LANGUAGES=${ORA_LANGUAGES} \\
EOF

if [ "${ORESTART}" == "true" ]
then
cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.option=HA_CONFIG \\
EOF
else
cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.option=CRS_CONFIG \\
EOF
fi

cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    ORACLE_BASE=${GRID_BASE} \\
    oracle.install.asm.OSDBA=asmdba \\
    oracle.install.asm.OSOPER=asmoper \\
    oracle.install.asm.OSASM=asmadmin \\
EOF
if [ "${ORESTART}" == "false" ]
then
cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.crs.config.scanType=LOCAL_SCAN \\
    oracle.install.crs.config.gpnp.scanName=${SCAN_NAME} \\
    oracle.install.crs.config.gpnp.scanPort=${SCAN_PORT} \\
EOF
fi

cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.crs.config.ClusterConfiguration=STANDALONE \\
    oracle.install.crs.config.configureAsExtendedCluster=false \\
    oracle.install.crs.config.clusterName=${CLUSTER_NAME} \\
    oracle_install_crs_ConfigureMgmtDB=${NOMGMTDB} \\
EOF

if [ "${ORESTART}" == "false" ]
then
  cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.crs.config.clusterNodes=$(cluster_nodelist "${VM_COUNT}" "${VM_NAME}" "${DOMAIN_NAME}" "${VIP_NETNAME}") \\
    oracle.install.crs.config.networkInterfaceList=${NET_DEVICE1}:$(echo "${PUBLIC_SUBNET}" | cut -d. -f1-3).0:1,${NET_DEVICE2}:$(echo "${PRIVATE_SUBNET}" | cut -d. -f1-3).0:5 \\
EOF
fi

cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.crs.config.gpnp.configureGNS=false \\
    oracle.install.crs.config.autoConfigureClusterNodeVIP=false \\
    oracle.install.asm.configureGIMRDataDG=false \\
    oracle.install.crs.config.useIPMI=false \\
    oracle.install.asm.storageOption=ASM \\
    oracle.install.asmOnNAS.configureGIMRDataDG=false \\
    oracle.install.asm.SYSASMPassword=${SYS_PASSWORD} \\
    oracle.install.asm.diskGroup.name=DATA \\
    oracle.install.asm.diskGroup.redundancy=EXTERNAL \\
    oracle.install.asm.diskGroup.AUSize=4 \\
EOF

if [ "${ASM_LIB_TYPE}" == "ASMFD" ]
then
DISKS=`ls -dm /dev/ORCL_DISK*_p1`
DISKSFG=`echo $DISKS| tr ', ' ',,'`
DISKSFG=${DISKSFG}","
DISKS=`echo $DISKS|tr -d ' '`
cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DISKSFG} \\
    oracle.install.asm.diskGroup.disks=${DISKS} \\
    oracle.install.asm.diskGroup.diskDiscoveryString=/dev/ORCL_* \\
    oracle.install.asm.configureAFD=true \\
EOF
else
DISKS=`ls -dm /dev/oracleasm/disks/ORCL_DISK*_P1`
DISKSFG=`echo $DISKS| tr ', ' ',,'`
DISKSFG=${DISKSFG}","
DISKS=`echo $DISKS|tr -d ' '`
cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DISKSFG} \\
    oracle.install.asm.diskGroup.disks=${DISKS} \\
    oracle.install.asm.diskGroup.diskDiscoveryString=/dev/oracleasm/disks/ORCL_* \\
EOF
fi

cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.asm.gimrDG.AUSize=1 \\
    oracle.install.asm.monitorPassword=${SYS_PASSWORD} \\
    oracle.install.crs.configureRHPS=false \\
    oracle.install.crs.config.ignoreDownNodes=false \\
    oracle.install.config.managementOption=NONE \\
    oracle.install.config.omsPort=0 \\
    oracle.install.crs.rootconfig.executeRootScript=false
EOF
}

make_11_gi_config() {
cat > /vagrant/scripts/11_gi_config.sh <<EOF
. /vagrant/config/setup.env
${GI_HOME}/gridSetup.sh -silent -executeConfigTools \\
    -responseFile ${GI_HOME}/install/response/gridsetup.rsp \\
    INVENTORY_LOCATION=${ORA_INVENTORY} \\
    SELECTED_LANGUAGES=${ORA_LANGUAGES} \\
EOF

if [ "${ORESTART}" == "true" ]
then
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.option=HA_CONFIG \\
EOF
else
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.option=CRS_CONFIG \\
EOF
fi

cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    ORACLE_BASE=${GRID_BASE} \\
    oracle.install.asm.OSDBA=asmdba \\
    oracle.install.asm.OSOPER=asmoper \\
    oracle.install.asm.OSASM=asmadmin \\
EOF

if [ "${ORESTART}" == "false" ]
then
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.crs.config.scanType=LOCAL_SCAN \\
    oracle.install.crs.config.gpnp.scanName=${SCAN_NAME} \\
    oracle.install.crs.config.gpnp.scanPort=${SCAN_PORT} \\
    oracle.install.crs.config.clusterName=${CLUSTER_NAME} \\
EOF
fi

cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.crs.config.ClusterConfiguration=STANDALONE \\
    oracle.install.crs.config.configureAsExtendedCluster=false \\
EOF

if [ "${NOMGMTDB}" == "true" ]
then
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle_install_crs_ConfigureMgmtDB=false \\
EOF
else
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle_install_crs_ConfigureMgmtDB=true \\
EOF
fi

if [ "${ORESTART}" == "false" ]
then
  cat >> /vagrant/scripts/09_gi_installation.sh <<EOF
    oracle.install.crs.config.clusterNodes=$(cluster_nodelist "${VM_COUNT}" "${VM_NAME}" "${DOMAIN_NAME}" "${VIP_NETNAME}") \\
    oracle.install.crs.config.networkInterfaceList=${NET_DEVICE1}:$(echo "${PUBLIC_SUBNET}" | cut -d. -f1-3).0:1,${NET_DEVICE2}:$(echo "${PRIVATE_SUBNET}" | cut -d. -f1-3).0:5 \\
EOF
fi

cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.crs.config.gpnp.configureGNS=false \\
    oracle.install.crs.config.autoConfigureClusterNodeVIP=false \\
    oracle.install.asm.configureGIMRDataDG=false \\
    oracle.install.crs.config.useIPMI=false \\
    oracle.install.asm.storageOption=ASM \\
    oracle.install.asmOnNAS.configureGIMRDataDG=false \\
    oracle.install.asm.SYSASMPassword=${SYS_PASSWORD} \\
    oracle.install.asm.diskGroup.name=DATA \\
    oracle.install.asm.diskGroup.redundancy=EXTERNAL \\
    oracle.install.asm.diskGroup.AUSize=4 \\
EOF

if [ "${ASM_LIB_TYPE}" == "ASMFD" ]
then
DISKS=`ls -dm /dev/ORCL_DISK*_p1`
DISKSFG=`echo $DISKS| tr ', ' ',,'`
DISKSFG=${DISKSFG}","
DISKS=`echo $DISKS|tr -d ' '`
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DISKSFG} \\
    oracle.install.asm.diskGroup.disks=${DISKS} \\
    oracle.install.asm.diskGroup.diskDiscoveryString=/dev/ORCL_* \\
    oracle.install.asm.configureAFD=true \\
EOF
else
DISKS=`ls -dm /dev/oracleasm/disks/ORCL_DISK*_P1`
DISKSFG=`echo $DISKS| tr ', ' ',,'`
DISKSFG=${DISKSFG}","
DISKS=`echo $DISKS|tr -d ' '`
cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DISKSFG} \\
    oracle.install.asm.diskGroup.disks=${DISKS} \\
    oracle.install.asm.diskGroup.diskDiscoveryString=/dev/oracleasm/disks/ORCL_* \\
EOF
fi

cat >> /vagrant/scripts/11_gi_config.sh <<EOF
    oracle.install.asm.gimrDG.AUSize=1 \\
    oracle.install.asm.monitorPassword=${SYS_PASSWORD} \\
    oracle.install.crs.configureRHPS=false \\
    oracle.install.crs.config.ignoreDownNodes=false \\
    oracle.install.config.managementOption=NONE \\
    oracle.install.config.omsPort=0 \\
    oracle.install.crs.rootconfig.executeRootScript=false
EOF
}

make_13_RDBMS_software_installation() {
cat > /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
. /vagrant/config/setup.env
EOF

DB_MAJOR=$(echo "${DB_SOFTWARE_VER}" | cut -c1-2)
if [ "${DB_MAJOR}" == "12" ]
then
  cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
${DB_HOME}/database/runInstaller -ignorePrereq -waitforcompletion -silent \\
        -responseFile ${DB_HOME}/database/response/db_install.rsp \\
EOF
else
  cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
${DB_HOME}/runInstaller -ignorePrereq -waitforcompletion -silent \\
        -responseFile ${DB_HOME}/install/response/db_install.rsp \\
EOF
fi

cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
        oracle.install.option=INSTALL_DB_SWONLY \\
        ORACLE_HOSTNAME=${ORACLE_HOSTNAME} \\
        UNIX_GROUP_NAME=oinstall \\
        INVENTORY_LOCATION=${ORA_INVENTORY} \\
        SELECTED_LANGUAGES=${ORA_LANGUAGES} \\
        ORACLE_HOME=${DB_HOME} \\
        ORACLE_BASE=${DB_BASE} \\
        oracle.install.db.InstallEdition=EE \\
        oracle.install.db.OSDBA_GROUP=dba \\
        oracle.install.db.OSBACKUPDBA_GROUP=dba \\
        oracle.install.db.OSDGDBA_GROUP=dba \\
        oracle.install.db.OSKMDBA_GROUP=dba \\
        oracle.install.db.OSRACDBA_GROUP=dba \\
EOF

if [ "${ORESTART}" == "false" ]
then
  cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
        oracle.install.db.CLUSTER_NODES="$(nodelist "${VM_COUNT}" "${VM_NAME}")" \\
EOF
fi

if [ "${DB_TYPE}" == "RACONE" ]
then
  cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
        oracle.install.db.isRACOneInstall=true \\
EOF
else
  cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
        oracle.install.db.isRACOneInstall=false \\
EOF
fi

cat >> /vagrant/scripts/13_RDBMS_software_installation.sh <<EOF
        oracle.install.db.rac.serverpoolCardinality=0 \\
        oracle.install.db.config.starterdb.type=GENERAL_PURPOSE \\
        oracle.install.db.ConfigureAsContainerDB=true \\
        SECURITY_UPDATES_VIA_MYORACLESUPPORT=false \\
        DECLINE_SECURITY_UPDATES=true
EOF
}

make_14_create_database() {
cat > /vagrant/scripts/14_create_database.sh <<EOF
. /vagrant/config/setup.env
${DB_HOME}/bin/dbca -silent -createDatabase \\
  -templateName General_Purpose.dbc \\
  -initParams db_recovery_file_dest_size=2G \\
  -responseFile NO_VALUE \\
  -gdbname ${DB_NAME} \\
  -characterSet AL32UTF8 \\
  -sysPassword ${SYS_PASSWORD} \\
  -systemPassword ${SYS_PASSWORD} \\
EOF

if [ "${CDB}" == "true" ]
then
cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -createAsContainerDatabase true \\
  -numberOfPDBs 1 \\
  -pdbName ${PDB_NAME} \\
  -pdbAdminPassword ${PDB_PASSWORD} \\
EOF
fi

cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -databaseType MULTIPURPOSE \\
  -automaticMemoryManagement false \\
  -totalMemory 2048 \\
  -redoLogFileSize 50 \\
  -emConfiguration NONE \\
  -ignorePreReqs \\
EOF

if [ "${DB_TYPE}" == "RAC" ]
then
    cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -databaseConfigType RAC \\
EOF
elif [ "${DB_TYPE}" == "RACONE" ]
then
    cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -databaseConfigType RACONE \\
  -RACOneNodeServiceName ${DB_NAME}_srv \\
EOF
elif [ "${DB_TYPE}" == "SINGLE" ]
then
    cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -databaseConfigType SINGLE \\
EOF
fi

if [ "${DB_TYPE}" == "RAC" ] || [ "${DB_TYPE}" == "RACONE" ]
then
  nodes="$(nodelist "${VM_COUNT}" "${VM_NAME}")"
  if [ "${ORESTART}" == "false" ]
  then
    cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -nodelist ${nodes} \\
EOF
  else
      cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -nodelist $(hostname -s) \\
EOF
  fi
fi

cat >> /vagrant/scripts/14_create_database.sh <<EOF
  -storageType ASM \\
  -diskGroupName +DATA \\
  -recoveryGroupName +RECO \\
  -asmsnmpPassword ${SYS_PASSWORD}
EOF
}

# ---------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------
if [[ `get_node_id` -eq ${VM_COUNT} || (`get_node_id` -eq 1 && "${ORESTART}" == "true") ]]
then
  # build the setup.env
  info "Make the setup.env" 1
  GI_MAJOR=$(echo "${GI_SOFTWARE_VER}" | cut -c1-2)
  GI_MAINTENANCE=$(echo "${GI_SOFTWARE_VER}" | cut -c3)
  GI_APP=$(echo "${GI_SOFTWARE_VER}" | cut -c4)
  GI_COMP=$(echo "${GI_SOFTWARE_VER}" | cut -c5)
  GI_VERSION=${GI_MAJOR}"."${GI_MAINTENANCE}"."${GI_APP}"."${GI_COMP}
  GI_HOME="/u01/app/"$GI_VERSION"/grid"

  DB_MAJOR=$(echo "${DB_SOFTWARE_VER}" | cut -c1-2)
  DB_MAINTENANCE=$(echo "${DB_SOFTWARE_VER}" | cut -c3)
  DB_APP=$(echo "${DB_SOFTWARE_VER}" | cut -c4)
  DB_COMP=$(echo "${DB_SOFTWARE_VER}" | cut -c5)
  DB_VERSION=${DB_MAJOR}"."${DB_MAINTENANCE}"."${DB_APP}"."${DB_COMP}
  DB_HOME="/u01/app/oracle/product/"$DB_VERSION"/dbhome_1"

  NET_DEVICE1=`ip a | grep "3: " | awk '{print $2}'`
  NET_DEVICE1=${NET_DEVICE1:0:-1}
  NET_DEVICE2=`ip a | grep "4: " | awk '{print $2}'`
  NET_DEVICE2=${NET_DEVICE2:0:-1}

cat <<EOL > /vagrant/config/setup.env
#----------------------------------------------------------
# Env Variables
#----------------------------------------------------------
export PREFIX_NAME=$PREFIX_NAME
#----------------------------------------------------------
#----------------------------------------------------------
export GI_SOFTWARE=$GI_SOFTWARE
export DB_SOFTWARE=$DB_SOFTWARE
#----------------------------------------------------------
#----------------------------------------------------------
export GI_VERSION=$GI_VERSION
export DB_VERSION=$DB_VERSION
#----------------------------------------------------------
#----------------------------------------------------------
export SYS_PASSWORD=$SYS_PASSWORD
export PDB_PASSWORD=$PDB_PASSWORD
#----------------------------------------------------------
#----------------------------------------------------------
export P1_RATIO=$P1_RATIO
export ASM_LIB_TYPE=$ASM_LIB_TYPE
export NOMGMTDB=$NOMGMTDB
export ORESTART=$ORESTART
#----------------------------------------------------------
#----------------------------------------------------------
export PUBLIC_SUBNET=$PUBLIC_SUBNET
export PRIVATE_SUBNET=$PRIVATE_SUBNET
export VIP_SUBNET=$VIP_SUBNET
export VM_COUNT=$VM_COUNT
export VM_NAME=$VM_NAME
export PRIVATE_NETNAME=$PRIVATE_NETNAME
export VIP_NETNAME=$VIP_NETNAME
#
export SCAN_IP1=$SCAN_IP1
export SCAN_IP2=$SCAN_IP2
export SCAN_IP3=$SCAN_IP3
#----------------------------------------------------------
#----------------------------------------------------------
export DOMAIN_NAME=${DOMAIN}
#----------------------------------------------------------
#----------------------------------------------------------
export CLUSTER_NAME=${PREFIX_NAME}-c

export ORA_LANGUAGES=$ORA_LANGUAGES

export SCAN_NAME=${PREFIX_NAME}-scan
export FQ_SCAN_NAME=\${SCAN_NAME}.\${DOMAIN_NAME}
export SCAN_PORT=1521

export ORA_INVENTORY=/u01/app/oraInventory
export GRID_BASE=/u01/app/grid
export DB_BASE=/u01/app/oracle

export GI_HOME=${GI_HOME}
export DB_HOME=${DB_HOME}

export DB_NAME=$DB_NAME
export PDB_NAME=$PDB_NAME
export DB_TYPE=$DB_TYPE
#----------------------------------------------------------
#----------------------------------------------------------
export NET_DEVICE1=${NET_DEVICE1}
export NET_DEVICE2=${NET_DEVICE2}
#----------------------------------------------------------
#----------------------------------------------------------
EOL
fi

# Setup the env
info "Setup the environment variables" 1
. /vagrant/config/setup.env

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
info "Checking parameters" 1
if [ "$P1_RATIO" -eq "$P1_RATIO" ] 2>/dev/null
then
  echo "Partition ratio is set to $P1_RATIO" >/dev/null
else
  error "Partition ratio option must be an integer, exiting..."
fi

if [ $P1_RATIO -lt 10 ] && [ $P1_RATIO -gt 80 ] 
then
  error "Partition ratio should be a value between 10 and 80, exiting..."
fi 

if [ "${ASM_LIB_TYPE}" != "ASMLIB" ] && [ "${ASM_LIB_TYPE}" != "ASMFD" ]
then
  error "Parameter 'asm_lib_type' must be 'ASMLIB' or 'ASMFD', exiting..."
fi

if [ "${ORESTART}" != "true" ] && [ "${ORESTART}" != "false" ]
then
  error "Parameter 'orestart' must be 'true' or 'false', exiting..."
fi

if [ "${NOMGMTDB}" != "true" ] && [ "${NOMGMTDB}" != "false" ]
then
  error "Parameter 'nomgmtdb' must be 'true' or 'false', exiting..."
fi

if [ "${DB_TYPE}" != "SI" ] && [ "${DB_TYPE}" != "RACONE" ] && [ "${DB_TYPE}" != "RAC" ]
then
  error "Parameter 'db_type' must be 'SI' or 'RACONE' or 'RAC', exiting..."
fi

if [[ "${ORESTART}" == "true" && ("${DB_TYPE}" == "RACONE" || "${DB_TYPE}" == "RAC" ) ]]
then
  error "Oracle Restart supports 'SI' only, exiting..."
fi

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------

info "Fix locale warnings" 1
echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

# set system time zone
info "Set system time zone" 1
sudo timedatectl set-timezone $SYSTEM_TIMEZONE

#--------------------------------------------------------------------
#--------------------------------------------------------------------
# Setting-up /u01 disk
sh /vagrant/scripts/01_setup_u01.sh $BOX_DISK_NUM $PROVIDER

# Install OS Pachages
sh /vagrant/scripts/02_install_os_packages.sh

# Setup /etc/hosts & /etc/resolv.conf
sh /vagrant/scripts/03_setup_hosts.sh

# Setup chrony
sh /vagrant/scripts/04_setup_chrony.sh

# Setup shared disks
BOX_DISK_NUM=$((BOX_DISK_NUM + 1))
sh /vagrant/scripts/05_setup_shared_disks.sh $BOX_DISK_NUM $PROVIDER

# Setup users
sh /vagrant/scripts/06_setup_users.sh

# Setup users password
info "Set root, oracle and grid password" 1
echo ${ROOT_PASSWORD}   | passwd --stdin root
echo ${GRID_PASSWORD}   | passwd --stdin grid
echo ${ORACLE_PASSWORD} | passwd --stdin oracle

# Actions on node1 only
if [ `get_node_id` -eq 1 ] && [ "${ORESTART}" == "false" ]
then
  # unzip grid software
  info "Unzip grid software" 1
  cd ${GI_HOME}
  unzip -oq /vagrant/ORCL_software/${GI_SOFTWARE}
  chown -R grid:oinstall ${GI_HOME}

  # setup ssh equivalence (node1 only)
  info "Setup user equivalence" 1
  make_07_setup_user_equ ${VM_COUNT}
  node_list="$(nodelist $VM_COUNT $VM_NAME | sed s'/,/ /g')"
  expect /vagrant/scripts/07_setup_user_equ.expect grid   "${GRID_PASSWORD}"   "${node_list}" "${GI_HOME}/oui/prov/resources/scripts/sshUserSetup.sh"
  expect /vagrant/scripts/07_setup_user_equ.expect oracle "${ORACLE_PASSWORD}" "${node_list}" "${GI_HOME}/oui/prov/resources/scripts/sshUserSetup.sh"

  # Install cvuqdisk package
  info "Install cvuqdisk package" 1
  yum install -y ${GI_HOME}/cv/rpm/cvuqdisk*.rpm
elif [ "${ORESTART}" == "true" ]
then
  # unzip grid software 
  info "Unzip grid software" 1
  cd ${GI_HOME}
  unzip -oq /vagrant/ORCL_software/${GI_SOFTWARE}
  chown -R grid:oinstall ${GI_HOME}
  
  # Install cvuqdisk package
  info "Install cvuqdisk package" 1
  yum install -y ${GI_HOME}/cv/rpm/cvuqdisk*.rpm
fi

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
if [ "${ASM_LIB_TYPE}" == "ASMFD" ]
then
  # Setting-up asmfd disks label
  info "ASMFD disks label setup" 1
  sh /vagrant/scripts/08_asmfd_label_disk.sh $BOX_DISK_NUM $PROVIDER
else
  # Setting-up asmfd disks label
  info "ASMLib disks label setup" 1
  sh /vagrant/scripts/08_asmlib_label_disk.sh $BOX_DISK_NUM $PROVIDER
fi
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------

if [ `get_node_id` -eq 1 ] && [ "${ORESTART}" == "false" ]
then
  info "Make GI install command - RAC" 1
  make_09_gi_installation ;

  info "Grid Infrastructure installation as 'RAC'" 0
  info "- ASM library   : ${ASM_LIB_TYPE}"
  info "- without MGMTDB: ${NOMGMTDB}" 2
  su - grid -c 'sh /vagrant/scripts/09_gi_installation.sh'

  #-------------------------------------------------------
  info "Set root user equivalence" 1
  make_07_setup_user_equ ${VM_COUNT}
  node_list="$(nodelist $VM_COUNT $VM_NAME | sed s'/,/ /g')"
  expect /vagrant/scripts/07_setup_user_equ.expect root "${ROOT_PASSWORD}" "${node_list}" "${GI_HOME}/oui/prov/resources/scripts/sshUserSetup.sh"

  info "Grid Infrastructure setup" 1
  sh /vagrant/scripts/10_gi_setup.sh
  #-------------------------------------------------------
  info "Make GI config command" 1
  make_11_gi_config ;

  info "Grid Infrastructure configuration as 'RAC'" 0
  info "- ASM library   : ${ASM_LIB_TYPE}"
  info "- without MGMTDB: ${NOMGMTDB}" 2
  su - grid -c 'sh /vagrant/scripts/11_gi_config.sh'
  #-------------------------------------------------------

  if [ "${ASM_LIB_TYPE}" == "ASMFD" ]
  then
    # Make RECO DG using ASMFD
    info "Make RECO DG using ASMFD" 1
    su - grid -c 'sh /vagrant/scripts/12_Make_ASMFD_RECODG.sh'
  else
    # Make RECO DG using ASMLib
    info "Make RECO DG using ASMLib" 1
    su - grid -c 'sh /vagrant/scripts/12_Make_ASMLib_RECODG.sh'
  fi

  # unzip rdbms software 
  info "Unzip RDBMS software" 1
  cd ${DB_HOME}
  unzip -oq /vagrant/ORCL_software/${DB_SOFTWARE}
  chown -R oracle:oinstall ${DB_HOME}

  # Make 13_RDBMS_software_installation.sh
  info "Make RDBMS software install command" 1
  make_13_RDBMS_software_installation;

  # install rdbms software 
  info "RDBMS software installation" 1
  su - oracle -c 'sh /vagrant/scripts/13_RDBMS_software_installation.sh'
  sh ${DB_HOME}/root.sh
   for i in $(seq 2 $VM_COUNT)
    do ssh root@${VM_NAME}${i} sh ${DB_HOME}/root.sh 
  done

  if [ "${DB_MAJOR}" == "12" ]
  then
    rm -fr ${DB_HOME}/database
  fi

  # Make 14_create_database.sh
  info "Make create database command" 1
  make_14_create_database;

  # create database 
  info "Create database" 1
  su - oracle -c 'sh /vagrant/scripts/14_create_database.sh'

  # Check database 
  info "Check database" 1
  su - oracle -c 'sh /vagrant/scripts/15_Check_database.sh'

elif [ "${ORESTART}" == "true" ]
then
  info "Making GI install command - Restart" 1
  make_09_gi_installation ;

  info "Grid Infrastructure installation as 'ORestart'" 0
  info "- ASM library   : ${ASM_LIB_TYPE}"
  info "- without MGMTDB: ${NOMGMTDB}" 2
  su - grid -c 'sh /vagrant/scripts/09_gi_installation.sh'

  info "Grid Infrastructure setup" 1
  sh /vagrant/scripts/10_gi_setup.sh

  info "Make GI config command" 1
  make_11_gi_config ;

  info "Grid Infrastructure configuration as 'ORestart'" 0
  info "- ASM library   : ${ASM_LIB_TYPE}"
  info "- without MGMTDB: ${NOMGMTDB}" 2
  touch /etc/oratab
  chown grid:oinstall /etc/oratab
  su - grid -c 'sh /vagrant/scripts/11_gi_config.sh'

  #-------------------------------------------------------
  if [ "${ASM_LIB_TYPE}" == "ASMFD" ]
  then
    # Make RECO DG using ASMFD
    info "Make RECO DG using ASMFD" 1
    su - grid -c 'sh /vagrant/scripts/12_Make_ASMFD_RECODG.sh'
  else
    # Make RECO DG using ASMLib
    info "Make RECO DG using ASMLib" 1
    su - grid -c 'sh /vagrant/scripts/12_Make_ASMLib_RECODG.sh'
  fi

  # unzip rdbms software 
  info "Unzip RDBMS software" 1
  cd ${DB_HOME}
  unzip -oq /vagrant/ORCL_software/${DB_SOFTWARE}
  chown -R oracle:oinstall ${DB_HOME}

  # Make 13_RDBMS_software_installation.sh
  info "Make RDBMS software installation command" 1
  make_13_RDBMS_software_installation;

  # install rdbms software 
  info "RDBMS software installation" 1
  su - oracle -c 'sh /vagrant/scripts/13_RDBMS_software_installation.sh'
  sh ${DB_HOME}/root.sh

  if [ "${DB_MAJOR}" == "12" ]
  then
    rm -fr ${DB_HOME}/database
  fi

  # Make 14_create_database.sh
  info "Make create database command" 1
  make_14_create_database;

  # create database 
  info "Create database" 1
  su - oracle -c 'sh /vagrant/scripts/14_create_database.sh'

  # Check database 
  info "Check database" 1
  su - oracle -c 'sh /vagrant/scripts/15_Check_database.sh'
fi

# run user-defined post-setup scripts
run_user_scripts;

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------

