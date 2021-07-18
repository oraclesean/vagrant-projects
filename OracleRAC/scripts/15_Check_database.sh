#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2020 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      15_Check_database.sh
#
#    DESCRIPTION
#      Check database
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20200330 - $Revision: 2.0.2.1 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
. /vagrant/config/setup.env
. /vagrant/scripts/functions.sh

export ORACLE_HOME=${DB_HOME}

info "Config database" 1
${DB_HOME}/bin/srvctl config database -d ${DB_NAME}

if [ $? -ne 0 ]
then
  if [ "${ORESTART}" == "true" ]
  then
    error "Oracle Restart on Vagrant is having problems" 1
  else
    error "Oracle RAC on Vagrant is having problems" 1
  fi
  exit
fi

info "Database Status" 1
${DB_HOME}/bin/srvctl status database -d ${DB_NAME}

if [ "${ORESTART}" == "true" ]
then
  success "Oracle Restart on Vagrant has been created successfully!" 1
else
  success "Oracle RAC on Vagrant has been created successfully!" 1
fi

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------


