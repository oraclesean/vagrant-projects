#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2020 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      05_setup_shared_disks.sh 
#
#    DESCRIPTION
#      Setting-up shared disks partions & udev rules
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

info "Setting-up shared disks partions" 1
BOX_DISK_NUM=$1
PROVIDER=$2

if [ "${PROVIDER}" == "libvirt" ]; then
  DEVICE="vd"
elif [ "${PROVIDER}" == "virtualbox" ]; then
  DEVICE="sd"
else
  echo "Not supported provider: ${PROVIDER}"
  exit 1
fi

if [[ `get_node_id` == ${VM_COUNT} || (`get_node_id` == 1 && "${ORESTART}" == "true") ]]
then
  LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
  SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
  for (( i=1; i<=$SDISKSNUM; i++ ))
  do
    parted /dev/${DEVICE}${LETTER} --script -- mklabel gpt mkpart primary 4096s ${P1_RATIO}%
    parted /dev/${DEVICE}${LETTER} --script -- mkpart primary ${P1_RATIO}% 100%
    LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
  done
fi

info "Setting-up shared disks udev rules" 1
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  echo "KERNEL==\"/dev/${DEVICE}${LETTER}\",  SUBSYSTEM==\"block\", SYMLINK+=\"ORCL_DISK${i}\"    OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
  echo "KERNEL==\"/dev/${DEVICE}${LETTER}1\", SUBSYSTEM==\"block\", SYMLINK+=\"ORCL_DISK${i}_p1\" OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
  echo "KERNEL==\"/dev/${DEVICE}${LETTER}2\", SUBSYSTEM==\"block\", SYMLINK+=\"ORCL_DISK${i}_p2\" OWNER:=\"grid\", GROUP:=\"asmadmin\", MODE:=\"660\"" >> /etc/udev/rules.d/70-persistent-disk.rules
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done

info "Shared partprobe" 1
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  /sbin/partprobe /dev/${DEVICE}${LETTER}1
  /sbin/partprobe /dev/${DEVICE}${LETTER}2
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done
sleep 10
/sbin/udevadm control --reload-rules
sleep 10
LETTER=`tr 0123456789 abcdefghij <<< $BOX_DISK_NUM`
SDISKSNUM=$(ls -l /dev/${DEVICE}[${LETTER}-z]|wc -l)
for (( i=1; i<=$SDISKSNUM; i++ ))
do
  /sbin/partprobe /dev/${DEVICE}${LETTER}1
  /sbin/partprobe /dev/${DEVICE}${LETTER}2
  LETTER=$(echo "$LETTER" | tr "0-9a-z" "1-9a-z_")
done
sleep 10
/sbin/udevadm control --reload-rules

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------

