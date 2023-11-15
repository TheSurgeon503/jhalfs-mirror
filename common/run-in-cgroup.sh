#!/bin/bash

if [ -z "$CPUSPEC" ] || [ "$#" -lt 1 ]; then
	echo "usage: CPUSPEC=... $0 command"
	exit 1
fi

set +e

if type systemd-run >/dev/null 2>&1 ; then
	sudo systemd-run -G --pty -d --uid=$(whoami) -p AllowedCPUs="$CPUSPEC" "$@"
else
	sudo mkdir /sys/fs/cgroup/jhalfs
	sudo sh -c "echo +cpuset > /sys/fs/cgroup/cgroup.subtree_control"
	sudo sh -c "echo \"$CPUSPEC\" > /sys/fs/cgroup/jhalfs/cpuset.cpus"
	(sudo sh -c "echo $BASHPID > /sys/fs/cgroup/jhalfs/cgroup.procs" &&
		exec "$@")
	sudo rmdir /sys/fs/cgroup/jhalfs
fi
