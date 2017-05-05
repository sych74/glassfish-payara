#!/bin/bash

# Configure SSH
echo "root:${PASSWORD}" | chpasswd
sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config
sed -i 's|#StrictModes yes|StrictModes yes|g' /etc/ssh/sshd_config
sed -i 's|#AuthorizedKeysFile	%h/.ssh/authorized_keys|AuthorizedKeysFile	%h/.ssh/authorized_keys|g' /etc/ssh/sshd_config
sed -i 's|PermitRootLogin without-password|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed -i 's|#   IdentityFile ~/.ssh/id_rsa|IdentityFile ~/.ssh/id_rsa|g' /etc/ssh/ssh_config
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
