#!/bin/bash
set -e

# Compose starts as container root only long enough to register the host identity.
if [[ -n ${LOCAL_UID:-} || -n ${LOCAL_GID:-} ]]; then
    : "${LOCAL_UID:?Set both LOCAL_UID and LOCAL_GID}"
    : "${LOCAL_GID:?Set both LOCAL_UID and LOCAL_GID}"
    for account_id in "$LOCAL_UID" "$LOCAL_GID"; do
        if [[ ! $account_id =~ ^(0|[1-9][0-9]*)$ ]]; then
            printf 'Invalid UID or GID: %s\n' "$account_id" >&2
            exit 1
        fi
    done

    if [[ $(id -u) == 0 ]]; then
        requested_name=${LOCAL_USER:-developer}
        if [[ ! $requested_name =~ ^[a-z_][a-z0-9_-]*$ || ${#requested_name} -gt 32 ]]; then
            printf 'Invalid LOCAL_USER: %s\n' "$requested_name" >&2
            exit 1
        fi

        unique_account_name() {
            local database=$1 candidate=$requested_name counter=0
            while getent "$database" "$candidate" >/dev/null; do
                counter=$((counter + 1))
                candidate="${requested_name:0:16}_${2}_${counter}"
            done
            printf '%s\n' "$candidate"
        }

        group_entry=$(getent group "$LOCAL_GID" || true)
        if [[ -n $group_entry ]]; then
            group_name=${group_entry%%:*}
        else
            group_name=$(unique_account_name group "$LOCAL_GID")
            groupadd --gid "$LOCAL_GID" "$group_name"
        fi

        passwd_entry=$(getent passwd "$LOCAL_UID" || true)
        if [[ -n $passwd_entry ]]; then
            account_name=${passwd_entry%%:*}
            IFS=: read -r _ _ _ account_gid _ account_home _ <<< "$passwd_entry"
            if [[ $account_gid != "$LOCAL_GID" ]]; then
                usermod --gid "$group_name" "$account_name"
            fi
        else
            account_name=$(unique_account_name passwd "$LOCAL_UID")
            account_home="/home/$account_name"
            useradd --create-home --home-dir "$account_home" --shell /bin/bash \
                --uid "$LOCAL_UID" --gid "$group_name" "$account_name"
        fi
        mkdir -p -- "$account_home"
        chown "$LOCAL_UID:$LOCAL_GID" "$account_home"
        export HOME="$account_home" USER="$account_name" LOGNAME="$account_name" SHELL=/bin/bash

        if [[ $LOCAL_UID != 0 ]]; then
            # Drop privileges and restart this script before initializing Lmod.
            # Python is already installed; exec preserves the terminal and PID.
            exec python3 -c '
import os, sys
uid, gid = int(sys.argv[1]), int(sys.argv[2])
os.initgroups(sys.argv[3], gid)
os.setgid(gid)
os.setuid(uid)
os.execv("/bin/bash", ["/bin/bash", sys.argv[4], *sys.argv[5:]])
' "$LOCAL_UID" "$LOCAL_GID" "$account_name" "$0" "$@"
        fi
    elif [[ $(id -u) != "$LOCAL_UID" || $(id -g) != "$LOCAL_GID" ]] \
        || ! getent passwd "$LOCAL_UID" >/dev/null; then
        printf 'Start the entrypoint as container root to configure LOCAL_UID/LOCAL_GID.\n' >&2
        exit 1
    fi
fi

# Initialize Lmod for commands as well as interactive shells.
source /etc/profile.d/lmod.sh

echo "Loading modules for compiling HOFEM with intel 2025.3 and gidpost 2.9"
ml load oneapi/compiler/2025.3
ml load gidpost/2.9 arpack metis
ml load impi
ml load parpack parmetis scotch mumps

exec "$@"
