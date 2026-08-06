# ==================================================================================
# SolidGroundUX - Storage
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.8
#   Build       : 2621814
#   Checksum    : 001dcbb288702bf7c375f75cea60d69ecbf64b43e6be9c56d8967f0af3fb2d39
#   Source      : 26-storage-v4.sh
#   Type        : module
#   Group       : SolidGround Console
#   Purpose     : Configure and inspect local storage volumes
#
# Description:
#   Provides reusable local-storage provisioning for server roles. Detects unused
#   disks, creates a filesystem, configures persistent mounting, and reports the
#   resulting storage state independently from services such as Samba.
#
# Attribution:
#   Developers    : Mark Fieten
#   Company       : Testadura Consultancy
#   Client        : -
#   Copyright     : © 2025 - 2026 Testadura Consultancy
#   License       : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard
        # . Purpose
        #   Ensure the file is sourced as a library and only initialized once.
        #
        # . Behavior
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution if the file is executed instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Skips initialization if the library was already loaded.
        #
        # Inputs:
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals):
        #   SGND_<MODULE>_LOADED
        #
        # . Returns
        #   0 if already loaded or successfully initialized.
        #   Exits with code 2 if executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard
    _sgnd_lib_guard() {
        local lib_base
        local guard

        lib_base="$(basename "${BASH_SOURCE[0]}" .sh)"
        lib_base="${lib_base//-/_}"
        guard="SGND_${lib_base^^}_LOADED"

        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            printf 'This is a library; source it, do not execute it: %s\n' "${BASH_SOURCE[0]}" >&2
            exit 2
        }

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    sgnd_module_init_metadata "${BASH_SOURCE[0]}"

# - Module metadata -------------------------------------------------------------
    SGND_STORAGE_MODULE_ID="storage"
    SGND_STORAGE_MODULE_NAME="Storage"
    SGND_STORAGE_MODULE_VERSION="1.0.0"
    SGND_STORAGE_MODULE_DESC="Configure and inspect local storage volumes"

    SGND_MODULE_ID="${SGND_STORAGE_MODULE_ID}"
    SGND_MODULE_NAME="${SGND_STORAGE_MODULE_NAME}"
    SGND_MODULE_VERSION="${SGND_STORAGE_MODULE_VERSION}"
    SGND_MODULE_DESC="${SGND_STORAGE_MODULE_DESC}"

    SGND_STORAGE_DEFAULT_MOUNTPOINT="/srv/storage"

# - Internal helpers -------------------------------------------------------------
    # fn$ _storage_validate_device
        # . Purpose
        #   Validate that a selected path is an unused whole block device.
        #
        # . Behavior
        #   - Requires an existing block device of type disk.
        #   - Rejects disks that currently contain mounted filesystems.
        #
        # Inputs:
        #   $1 - Block-device path.
        #
        # . Returns
        #   0 when the device is an unused disk, otherwise 1.
        #
        # . Usage
        #   _storage_validate_device "/dev/sdb"
    _storage_validate_device() {
        local device="${1:-}"
        local device_type=""
        local mountpoint=""

        [[ -b "$device" ]] || return 1
        device_type="$(lsblk -dn -o TYPE "$device" 2>/dev/null || true)"
        [[ "$device_type" == "disk" ]] || return 1

        while IFS= read -r mountpoint; do
            [[ -z "$mountpoint" ]] || return 1
        done < <(lsblk -nr -o MOUNTPOINTS "$device" 2>/dev/null)

        return 0
    }

    # fn$ _storage_validate_mountpoint
        # . Purpose
        #   Validate an absolute mount-point path.
        #
        # Inputs:
        #   $1 - Proposed mount point.
        #
        # . Returns
        #   0 for a safe absolute path, otherwise 1.
        #
        # . Usage
        #   _storage_validate_mountpoint "/srv/storage"
    _storage_validate_mountpoint() {
        local mountpoint="${1:-}"

        [[ "$mountpoint" == /* ]] || return 1
        [[ "$mountpoint" != "/" ]] || return 1
        [[ "$mountpoint" != *$'\n'* ]] || return 1
        [[ "$mountpoint" != *[[:space:]]* ]] || return 1
    }

    # fn$ _storage_list_unused_disks
        # . Purpose
        #   List whole disks that do not currently contain mounted filesystems.
        #
        # Outputs (stdout):
        #   One device path per line.
        #
        # . Returns
        #   0 after scanning available disks.
        #
        # . Usage
        #   _storage_list_unused_disks
    _storage_list_unused_disks() {
        local disk_name=""
        local device=""

        while IFS= read -r disk_name; do
            [[ -n "$disk_name" ]] || continue
            device="/dev/$disk_name"
            _storage_validate_device "$device" && printf '%s\n' "$device"
        done < <(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2 == "disk" { print $1 }')
    }

    # fn$ _storage_partition_path
        # . Purpose
        #   Return the first partition belonging to a disk after partitioning.
        #
        # Inputs:
        #   $1 - Whole-disk device path.
        #
        # Outputs (stdout):
        #   Partition device path.
        #
        # . Returns
        #   0 when a partition is found, otherwise 1.
        #
        # . Usage
        #   _storage_partition_path "/dev/sdb"
    _storage_partition_path() {
        local device="$1"
        local partition=""
        local attempt=0

        while (( attempt < 10 )); do
            partition="$(lsblk -nrpo NAME,TYPE "$device" 2>/dev/null | awk '$2 == "part" { print $1; exit }')"
            if [[ -n "$partition" ]]; then
                printf '%s\n' "$partition"
                return 0
            fi
            sleep 1
            attempt=$((attempt + 1))
        done

        return 1
    }

# - Public module actions --------------------------------------------------------
    # fn$ storage_configure
        # . Purpose
        #   Provision an unused local disk as persistent SolidGroundUX storage.
        #
        # . Behavior
        #   - Detects and displays unused whole disks.
        #   - Asks for the target disk, filesystem, and mount point.
        #   - Requires explicit confirmation before destructive changes.
        #   - Creates one GPT partition and formats it as ext4 or XFS.
        #   - Adds the filesystem UUID to /etc/fstab and mounts it.
        #   - Creates a shares directory for file-service consumers.
        #   - Honors console dry-run mode.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # Outputs (files):
        #   /etc/fstab
        #   <mount point>/shares
        #
        # . Returns
        #   0 when storage is configured or the action is cancelled.
        #   Non-zero when validation, partitioning, formatting, or mounting fails.
        #
        # . Usage
        #   storage_configure
    storage_configure() {
        local devices=()
        local device=""
        local filesystem="EXT4"
        local mountpoint="$SGND_STORAGE_DEFAULT_MOUNTPOINT"
        local decision="NO"
        local partition=""
        local uuid=""
        local fstab_backup=""

        mapfile -t devices < <(_storage_list_unused_disks)

        if (( ${#devices[@]} == 0 )); then
            saywarning "No unused whole disks were detected."
            return 1
        fi

        sgnd_print
        sgnd_print_sectionheader "Available storage devices"
        lsblk -d -o NAME,SIZE,TYPE,FSTYPE,MODEL "${devices[@]}" 2>/dev/null || true
        sgnd_print

        device="${devices[0]}"
        ask \
            --label "Storage device" \
            --var device \
            --default "$device" \
            --validate _storage_validate_device \
            --labelwidth 28 || return $?

        ask_decision \
            --label "Filesystem" \
            --choices "EXT4|E,XFS|X" \
            --default "EXT4" \
            --var filesystem || return $?

        ask \
            --label "Mount point" \
            --var mountpoint \
            --default "$mountpoint" \
            --validate _storage_validate_mountpoint \
            --labelwidth 28 || return $?

        sgnd_print
        sgnd_print_sectionheader "Configure storage"
        sgnd_print_labeledvalue --label "Device" --value "$device" --labelwidth 20
        sgnd_print_labeledvalue --label "Filesystem" --value "$filesystem" --labelwidth 20
        sgnd_print_labeledvalue --label "Mount point" --value "$mountpoint" --labelwidth 20
        sgnd_print
        saywarning "All existing data on $device will be destroyed."

        ask_decision \
            --label "Configure this disk?" \
            --choices "YES|Y,NO|N" \
            --default "NO" \
            --var decision || return $?

        [[ "$decision" == "YES" ]] || {
            sayinfo "Storage configuration cancelled."
            return 0
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would partition $device, format it as ${filesystem,,}, and mount it at $mountpoint."
            return 0
        fi

        sayinfo "Installing storage-management packages."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            e2fsprogs \
            parted \
            xfsprogs || return 1

        sayinfo "Creating a GPT partition table on $device."
        sudo wipefs --all "$device" || return 1
        sudo parted --script "$device" mklabel gpt || return 1
        sudo parted --script "$device" mkpart primary 0% 100% || return 1
        sudo partprobe "$device" || true
        sudo udevadm settle || true

        partition="$(_storage_partition_path "$device")" || {
            sayfail "The new partition on $device could not be detected."
            return 1
        }

        sayinfo "Formatting $partition as ${filesystem,,}."
        case "$filesystem" in
            EXT4)
                sudo mkfs.ext4 -F -L SGND_STORAGE "$partition" || return 1
                ;;
            XFS)
                sudo mkfs.xfs -f -L SGND_STORAGE "$partition" || return 1
                ;;
            *)
                sayfail "Unsupported filesystem: $filesystem"
                return 1
                ;;
        esac

        uuid="$(sudo blkid -s UUID -o value "$partition" 2>/dev/null || true)"
        [[ -n "$uuid" ]] || {
            sayfail "The filesystem UUID could not be determined."
            return 1
        }

        sudo install -d -m 0755 "$mountpoint" || return 1

        if mountpoint -q "$mountpoint"; then
            sayfail "$mountpoint is already mounted."
            return 1
        fi

        fstab_backup="/etc/fstab.pre-storage.$(date +%Y%m%d%H%M%S)"
        sudo cp -a /etc/fstab "$fstab_backup" || return 1

        printf '%s\n' \
            '' \
            '# SolidGroundUX managed storage' \
            "UUID=$uuid $mountpoint ${filesystem,,} defaults,nofail 0 2" | \
            sudo tee -a /etc/fstab >/dev/null || return 1

        sudo systemctl daemon-reload || return 1

        if ! sudo mount "$mountpoint"; then
            sayfail "Storage could not be mounted; restoring the previous /etc/fstab."
            sudo cp -a "$fstab_backup" /etc/fstab
            return 1
        fi

        sudo install -d -m 0770 "$mountpoint/shares" || return 1

        sayok "Storage configured successfully at $mountpoint."
    }

    # fn$ storage_mount
        # . Purpose
        #   Mount the configured SolidGroundUX storage filesystem.
        #
        # . Behavior
        #   - Verifies that the default mount point has an /etc/fstab entry.
        #   - Creates the mount-point directory when needed.
        #   - Mounts the configured filesystem unless it is already mounted.
        #   - Honors console dry-run mode.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when storage is mounted or already mounted, otherwise non-zero.
        #
        # . Usage
        #   storage_mount
    storage_mount() {
        local mountpoint="$SGND_STORAGE_DEFAULT_MOUNTPOINT"

        if mountpoint -q "$mountpoint"; then
            sayinfo "Storage is already mounted at $mountpoint."
            return 0
        fi

        if ! awk -v target="$mountpoint" '
            $0 !~ /^[[:space:]]*#/ && NF >= 2 && $2 == target { found = 1 }
            END { exit(found ? 0 : 1) }
        ' /etc/fstab; then
            sayfail "No persistent storage entry exists for $mountpoint."
            return 1
        fi

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would mount storage at $mountpoint."
            return 0
        fi

        sudo install -d -m 0755 "$mountpoint" || return 1
        sudo mount "$mountpoint" || return 1
        sayok "Storage mounted at $mountpoint."
    }

    # fn$ storage_unmount
        # . Purpose
        #   Unmount the configured SolidGroundUX storage filesystem.
        #
        # . Behavior
        #   - Leaves the persistent /etc/fstab entry unchanged.
        #   - Reports when the storage is already unmounted.
        #   - Honors console dry-run mode.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when storage is unmounted or already unmounted, otherwise non-zero.
        #
        # . Usage
        #   storage_unmount
    storage_unmount() {
        local mountpoint="$SGND_STORAGE_DEFAULT_MOUNTPOINT"

        if ! mountpoint -q "$mountpoint"; then
            sayinfo "Storage is already unmounted at $mountpoint."
            return 0
        fi

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would unmount storage at $mountpoint."
            return 0
        fi

        sudo umount "$mountpoint" || {
            sayfail "Storage could not be unmounted. It may still be in use."
            return 1
        }

        sayok "Storage unmounted from $mountpoint."
    }

    # fn$ storage_expand
        # . Purpose
        #   Expand the configured storage partition and filesystem to use a larger disk.
        #
        # . Behavior
        #   - Resolves the configured storage source from the active mount or /etc/fstab.
        #   - Requires a normal disk partition created by the Storage module.
        #   - Expands the partition to fill the resized virtual or physical disk.
        #   - Grows ext4 with resize2fs or XFS with xfs_growfs.
        #   - Mounts XFS storage first when required.
        #   - Honors console dry-run mode.
        #
        # Inputs (globals):
        #   FLAG_DRYRUN
        #
        # . Returns
        #   0 when the partition and filesystem are expanded, otherwise non-zero.
        #
        # . Usage
        #   storage_expand
    storage_expand() {
        local mountpoint="$SGND_STORAGE_DEFAULT_MOUNTPOINT"
        local source=""
        local source_spec=""
        local filesystem=""
        local parent_name=""
        local parent_device=""
        local partition_number=""

        if mountpoint -q "$mountpoint"; then
            source="$(findmnt -n -o SOURCE --mountpoint "$mountpoint" 2>/dev/null || true)"
            filesystem="$(findmnt -n -o FSTYPE --mountpoint "$mountpoint" 2>/dev/null || true)"
        else
            source_spec="$(awk -v target="$mountpoint" '
                $0 !~ /^[[:space:]]*#/ && NF >= 3 && $2 == target { print $1; exit }
            ' /etc/fstab)"
            filesystem="$(awk -v target="$mountpoint" '
                $0 !~ /^[[:space:]]*#/ && NF >= 3 && $2 == target { print $3; exit }
            ' /etc/fstab)"

            case "$source_spec" in
                UUID=*) source="$(blkid -U "${source_spec#UUID=}" 2>/dev/null || true)" ;;
                *) source="$source_spec" ;;
            esac
        fi

        source="$(readlink -f "$source" 2>/dev/null || true)"
        [[ -b "$source" ]] || {
            sayfail "The configured storage block device could not be resolved."
            return 1
        }

        [[ "$(lsblk -dn -o TYPE "$source" 2>/dev/null || true)" == "part" ]] || {
            sayfail "Storage expansion currently requires a normal disk partition."
            return 1
        }

        parent_name="$(lsblk -dn -o PKNAME "$source" 2>/dev/null || true)"
        partition_number="$(lsblk -dn -o PARTN "$source" 2>/dev/null || true)"
        [[ -n "$parent_name" && -n "$partition_number" ]] || {
            sayfail "The parent disk or partition number could not be determined."
            return 1
        }
        parent_device="/dev/$parent_name"

        sgnd_print
        sgnd_print_sectionheader "Expand storage"
        sgnd_print_labeledvalue --label "Disk" --value "$parent_device" --labelwidth 20
        sgnd_print_labeledvalue --label "Partition" --value "$source" --labelwidth 20
        sgnd_print_labeledvalue --label "Filesystem" --value "$filesystem" --labelwidth 20
        sgnd_print_labeledvalue --label "Mount point" --value "$mountpoint" --labelwidth 20

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "Dry run: Would expand $source and its $filesystem filesystem."
            return 0
        fi

        sayinfo "Installing storage expansion tools."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            cloud-guest-utils \
            e2fsprogs \
            xfsprogs || return 1

        sayinfo "Expanding partition $partition_number on $parent_device."
        sudo growpart "$parent_device" "$partition_number" || return 1
        sudo partprobe "$parent_device" || true
        sudo udevadm settle || true

        case "${filesystem,,}" in
            ext4)
                sudo resize2fs "$source" || return 1
                ;;
            xfs)
                mountpoint -q "$mountpoint" || storage_mount || return 1
                sudo xfs_growfs "$mountpoint" || return 1
                ;;
            *)
                sayfail "Unsupported filesystem for expansion: $filesystem"
                return 1
                ;;
        esac

        sayok "Storage expansion completed successfully."
    }

    # fn$ storage_status
        # . Purpose
        #   Display local block devices and the configured SolidGroundUX storage state.
        #
        # . Behavior
        #   - Displays a concise block-device overview.
        #   - Reports filesystem, source, capacity, availability, and persistence for
        #     the default storage mount point.
        #
        # Outputs (console):
        #   Local disk and storage-mount status.
        #
        # . Returns
        #   0 after displaying available status information.
        #
        # . Usage
        #   storage_status
    storage_status() {
        local mountpoint="$SGND_STORAGE_DEFAULT_MOUNTPOINT"
        local share_root="$mountpoint/shares"
        local source="Not configured"
        local filesystem="-"
        local filesystem_label="-"
        local filesystem_uuid="-"
        local size="-"
        local available="-"
        local mounted="No"
        local persistent="No"
        local root_exists="No"
        local root_writable="No"
        local share_root_exists="No"
        local mount_matches="No"
        local fstab_valid="Not checked"

        [[ -d "$mountpoint" ]] && root_exists="Yes"
        [[ -d "$share_root" ]] && share_root_exists="Yes"

        if mountpoint -q "$mountpoint"; then
            mounted="Yes"
            source="$(findmnt -n -o SOURCE --mountpoint "$mountpoint" 2>/dev/null || true)"
            filesystem="$(findmnt -n -o FSTYPE --mountpoint "$mountpoint" 2>/dev/null || true)"
            size="$(df -h --output=size "$mountpoint" 2>/dev/null | awk 'NR == 2 { print $1 }')"
            available="$(df -h --output=avail "$mountpoint" 2>/dev/null | awk 'NR == 2 { print $1 }')"

            if [[ -n "$source" ]]; then
                filesystem_label="$(blkid -s LABEL -o value "$source" 2>/dev/null || true)"
                filesystem_uuid="$(blkid -s UUID -o value "$source" 2>/dev/null || true)"
                [[ -n "$filesystem_label" ]] || filesystem_label="-"
                [[ -n "$filesystem_uuid" ]] || filesystem_uuid="-"
            fi

            [[ -w "$mountpoint" ]] && root_writable="Yes"

            if [[ "$(findmnt -n -o TARGET --source "$source" 2>/dev/null || true)" == "$mountpoint" ]]; then
                mount_matches="Yes"
            fi
        fi

        if awk -v target="$mountpoint" '
            $0 !~ /^[[:space:]]*#/ && NF >= 2 && $2 == target { found = 1 }
            END { exit(found ? 0 : 1) }
        ' /etc/fstab; then
            persistent="Yes"
        fi

        if findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1; then
            fstab_valid="Yes"
        else
            fstab_valid="No"
        fi

        sgnd_print
        sgnd_print_sectionheader "Storage devices"
        lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS,MODEL

        sgnd_print
        sgnd_print_sectionheader "SolidGroundUX storage"
        sgnd_print_labeledvalue --label "Mount point" --value "$mountpoint" --labelwidth 24
        sgnd_print_labeledvalue --label "Source" --value "$source" --labelwidth 24
        sgnd_print_labeledvalue --label "Filesystem" --value "$filesystem" --labelwidth 24
        sgnd_print_labeledvalue --label "Label" --value "$filesystem_label" --labelwidth 24
        sgnd_print_labeledvalue --label "UUID" --value "$filesystem_uuid" --labelwidth 24
        sgnd_print_labeledvalue --label "Mounted" --value "$mounted" --labelwidth 24
        sgnd_print_labeledvalue --label "Persistent" --value "$persistent" --labelwidth 24
        sgnd_print_labeledvalue --label "fstab valid" --value "$fstab_valid" --labelwidth 24
        sgnd_print_labeledvalue --label "Mount source matches" --value "$mount_matches" --labelwidth 24
        sgnd_print_labeledvalue --label "Storage root exists" --value "$root_exists" --labelwidth 24
        sgnd_print_labeledvalue --label "Storage root writable" --value "$root_writable" --labelwidth 24
        sgnd_print_labeledvalue --label "Shares root exists" --value "$share_root_exists" --labelwidth 24
        sgnd_print_labeledvalue --label "Capacity" --value "$size" --labelwidth 24
        sgnd_print_labeledvalue --label "Available" --value "$available" --labelwidth 24
    }

# - Console registration ---------------------------------------------------------
    sgnd_console_register_group \
        "$SGND_STORAGE_MODULE_ID" \
        "$SGND_STORAGE_MODULE_NAME" \
        "$SGND_STORAGE_MODULE_DESC" \
        0 \
        1 \
        240

    sgnd_console_register_item \
        "storage-configure" \
        "$SGND_STORAGE_MODULE_ID" \
        "Configure storage" \
        "storage_configure" \
        "Provision an unused disk as persistent local storage" \
        0 \
        5 \
        1

    sgnd_console_register_item \
        "storage-mount" \
        "$SGND_STORAGE_MODULE_ID" \
        "Mount storage" \
        "storage_mount" \
        "Mount the configured local storage filesystem" \
        0 \
        10 \
        1

    sgnd_console_register_item \
        "storage-unmount" \
        "$SGND_STORAGE_MODULE_ID" \
        "Unmount storage" \
        "storage_unmount" \
        "Unmount storage while keeping its persistent configuration" \
        0 \
        15 \
        1

    sgnd_console_register_item \
        "storage-expand" \
        "$SGND_STORAGE_MODULE_ID" \
        "Expand storage" \
        "storage_expand" \
        "Expand the partition and filesystem after enlarging its disk" \
        0 \
        20 \
        1

    sgnd_console_register_item \
        "storage-status" \
        "$SGND_STORAGE_MODULE_ID" \
        "Show storage status" \
        "storage_status" \
        "Show local disks and configured storage status" \
        0 \
        25 \
        1
