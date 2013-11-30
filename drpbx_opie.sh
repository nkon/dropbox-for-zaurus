#!/bin/sh

OPIE_SH=/opt/QtPalmtop/bin/opie-sh
QCOP=/opt/QtPalmtop/bin/qcop
D4Z=/home/zaurus/drpbx/d4z.rb
D4Z_DIR=/home/zaurus/drpbx

show_dialog(){
	$OPIE_SH -m -g t "Dropbox" -M "Dropbox client for zaurus" -0 "Down" -1 "Up" -2 "Sync"
}

down(){
	$D4Z -d | $OPIE_SH -g -t "Dropbox" -f
}
up(){
	$D4Z -u | $OPIE_SH -g -t "Dropbox" -f
}
sync(){
	$D4Z -s | $OPIE_SH -g -t "Dropbox" -f


### main

cd $D4Z_DIR
show_dialog

case $? in
	0)
		$QCOP QPE/Network 'connectRequest()'
		down
		$QCOP QPE/Network 'disconnectRequest()'
	;;
	1)
		$QCOP QPE/Network 'connectRequest()'
		up
		$QCOP QPE/Network 'disconnectRequest()'
	;;
	2)
		$QCOP QPE/Network 'connectRequest()'
		sync
		$QCOP QPE/Network 'disconnectRequest()'
	;;
esac


