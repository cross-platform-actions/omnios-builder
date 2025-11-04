#!/bin/sh

set -exu

install_extra_packages() {
  pkg install bash curl rsync
}

configure_boot_flags() {
  echo 'autoboot_delay="-1"' >> /boot/loader.conf.local
  echo 'beastie_disable="YES"' >> /boot/loader.conf.local
}

remove_secondary_user_password() {
  passwd -d runner
}

set_hostname() {
  echo 'runnervmg1sw1.local' > /etc/nodename
}

install_extra_packages
configure_boot_flags
remove_secondary_user_password
set_hostname
