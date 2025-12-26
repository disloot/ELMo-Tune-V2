#!/bin/bash
ACTION=$1
CGROUP_PATH=$2
VALUE=$3
USERNAME=$(whoami)

case $ACTION in
    "create")
        sudo mkdir -p "$CGROUP_PATH"
        ;;
    "chown")
        OWNER=$(stat -c %U "$CGROUP_PATH")
        if [ "$OWNER" == "$USERNAME" ]; then
            exit 0
        elif [ "$OWNER" != "root" ]; then
            echo "Owned by $OWNER, not root or $USERNAME"
            exit 1
        else
            sudo chown "$USERNAME:$USERNAME" "$CGROUP_PATH"
        fi
        ;;
    "write")
        sudo sh -c "echo '$VALUE' > '$CGROUP_PATH'"
        ;;
    *)
        exit 1
        ;;
esac