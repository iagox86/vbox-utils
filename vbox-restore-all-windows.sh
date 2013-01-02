#!/bin/sh

VBoxManage list vms |  \
  grep 'Windows' |     \
  sed 's/"[^"]*$//' |  \
  sed 's/"//' |        \
  while read i; do
    ./vbox-restore-base.sh "$i";
  done
