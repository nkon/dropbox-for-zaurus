#!/bin/sh

OPIE_SH=/opt/QtPalmtop/bin/opie-sh
QCOP=/opt/QtPalmtop/bin/qcop
D4Z=/opt/QtPalmtop/bin/d4z.rb
D4Z_DIR=/home/zaurus/drpbx

show_dialog(){
	$OPIE_SH -m -g -t "Dropbox" -M "Dropbox client for zaurus" -0 "Down" -1 "Up" -2 "Sync"
}

### main

cd $D4Z_DIR
show_dialog

case $? in
	0)
		$QCOP QPE/Network 'connectRequest()'
		sleep 15
		$D4Z -d
		$QCOP QPE/Network 'disconnectRequest()'
	;;
	1)
		$QCOP QPE/Network 'connectRequest()'
		sleep 15
		$D4Z -u
		$QCOP QPE/Network 'disconnectRequest()'
	;;
	2)
		$QCOP QPE/Network 'connectRequest()'
		sleep 15
		$D4Z -s
		$QCOP QPE/Network 'disconnectRequest()'
	;;
esac


