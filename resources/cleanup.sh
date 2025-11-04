#!/bin/sh

set -exu

cleanup() {
  pkg clean
}

minimize_disk() {
   pfexec mdb -kwe 'zfs_initialize_value/z0'
   zpool initialize rpool
}

cleanup
minimize_disk
