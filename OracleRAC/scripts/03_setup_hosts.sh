#!/bin/bash
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2020 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      03_setup_hosts.sh
#
#    DESCRIPTION
#      Setup for '/etc/hosts'
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
. /vagrant/config/setup.env
. /vagrant/scripts/functions.sh

info "Setup /etc/hosts" 1
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

add_ips "$VM_COUNT" "$VM_NAME" "$DOMAIN_NAME" "Public entries"  "$PUBLIC_SUBNET"
add_ips "$VM_COUNT" "$VM_NAME" "$DOMAIN_NAME" "Private entries" "$PRIVATE_SUBNET" "$PRIVATE_NETNAME" 
add_ips "$VM_COUNT" "$VM_NAME" "$DOMAIN_NAME" "VIP entries"     "$VIP_SUBNET"     "$VIP_NETNAME"

info "Setup SCAN on /etc/hosts" 1
cat >> /etc/hosts <<EOF
# SCAN
${SCAN_IP1}    ${FQ_SCAN_NAME}    ${SCAN_NAME}
${SCAN_IP2}    ${FQ_SCAN_NAME}    ${SCAN_NAME}
${SCAN_IP3}    ${FQ_SCAN_NAME}    ${SCAN_NAME}
EOF

info "Setup /etc/resolv.conf" 1
cat > /etc/resolv.conf <<EOF
search ${DOMAIN_NAME}
EOF

#----------------------------------------------------------
# EndOfFile
#----------------------------------------------------------
