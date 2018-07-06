#!/bin/bash

source /opt/crankshaft/crankshaft_default_env.sh
source /opt/crankshaft/crankshaft_system_env.sh
source /boot/crankshaft/crankshaft_env.sh

if [ ! -f /etc/cs_resize_done ]; then
    show_clear_screen
    show_cursor
    echo "${RESET}" > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] Partition and Filesystem not resized - resizing..." > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
    /usr/local/bin/crankshaft resize
    sync
    reboot
fi

# check if / is available
while [ "$(mountpoint -q / && echo mounted || echo fail)" == "fail" ]; do
    show_clear_screen
    show_cursor
    echo "${RESET}" > /dev/tty3
    echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
    echo "[${RED}${BOLD} WARN ${RESET}] Delayed rootfs - waiting..." > /dev/tty3
    echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
    sleep 2
done

sleep 1
SERIAL=$(cat /proc/cpuinfo | grep Serial | cut -d: -f2 | sed 's/ //g')

if [ ! -f /etc/cs_backup_restore_done ]; then
    if [ ! -f /etc/cs_first_start_done ]; then
        show_clear_screen
    fi
    echo "${RESET}" > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] Checking for cs backups to restore..." > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
    for _device in /sys/block/*/device; do
        if echo $(readlink -f "$_device")|egrep -q "usb"; then
            _disk=$(echo "$_device" | cut -f4 -d/)
            DEVICE="/dev/${_disk}1"
            PARTITION="${_disk}1"
            LABEL=$(blkid /dev/${PARTITION} | sed 's/.*LABEL="//' | cut -d'"' -f1)
            FSTYPE=$(blkid /dev/${PARTITION} | sed 's/.*TYPE="//' | cut -d'"' -f1)
            echo "${RESET}" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] Detected Drive: ${PARTITION}" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] Label 1st Part: ${LABEL}" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] PartFilesystem: ${FSTYPE}" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
            if [ $FSTYPE == "fat" ] || [ $FSTYPE == "vfat" ] || [ $FSTYPE == "ext3" ] || [ $FSTYPE == "ext4" ]; then
                umount /tmp/${PARTITION} > /dev/null 2>&1
                mkdir /tmp/${PARTITION} > /dev/null 2>&1
                echo "${RESET}" > /dev/tty3
                # check fs if needed
                if [ $FSTYPE == "fat" ] || [ $FSTYPE == "vfat" ]; then
                    # check state of fs
                    dosfsck -n $DEVICE
                    if [ $? == "1" ]; then
                        # 1 = errors detected - repair...
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] Errors on $DEVICE detected - repairing..." > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        dosfsck -y $DEVICE > /dev/tty3
                        sync
                        sleep 5
                        reboot
                    fi
                fi
                if [ $FSTYPE == "ext3" ] || [ $FSTYPE == "ext4" ]; then
                    CHECK=`tune2fs -l /dev/devicename |awk -F':' '/^Filesystem s/ {print $2}' | sed 's/ //g'`
                    if [ "$CHECK" != "clean" ]; then
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] Errors on $DEVICE detected - repairing..." > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        fsck.$FSTYPE -f -y $DEVICE > /dev/tty3
                        sync
                        sleep 5
                        reboot
                    fi
                fi
                echo "${RESET}" > /dev/tty3
                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                echo "[${CYAN}${BOLD} INFO ${RESET}] Mounting..." > /dev/tty3
                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                mount -t auto ${DEVICE} /tmp/${PARTITION} > /dev/tty3
                if [ $? -eq 0 ]; then
                    echo "${RESET}" > /dev/tty3
                    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                    echo "[${CYAN}${BOLD} INFO ${RESET}] Checking if backup folder is present..." > /dev/tty3
                    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                    if [ -d /tmp/${PARTITION}/cs-backup/${SERIAL} ] || [ -d /tmp/${PARTITION}/cs-backup/boot ]; then
                        sleep 2
                        show_screen
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] Backup found on $DEVICE (${LABEL}) - restoring backup..." > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                        mount -o remount,rw /boot
                        mount -o remount,rw /
                        # restore files
                        cp -r -f /tmp/${PARTITION}/cs-backup/${SERIAL}/boot/. /boot/ > /dev/null 2>&1
                        cp -r -f /tmp/${PARTITION}/cs-backup/${SERIAL}/etc/. /etc/ > /dev/null 2>&1
                        cp -r -f /tmp/${PARTITION}/cs-backup/${SERIAL}/etc/X11/xorg.conf.d/. /etc/ > /dev/null 2>&1
                        # failsafe for coming from pre1
                        cp -r -f /tmp/${PARTITION}/cs-backup/boot/. /boot/ > /dev/null 2>&1
                        cp -r -f /tmp/${PARTITION}/cs-backup/etc/. /etc/ > /dev/null 2>&1
                        cp -r -f /tmp/${PARTITION}/cs-backup/etc/X11/xorg.conf.d/. /etc/ > /dev/null 2>&1
                        chmod 644 /etc/timezone > /dev/null 2>&1
                        # remove possible existing lost boot entries
                        sed -i 's/initramfs initrd.img followkernel//' /boot/config.txt
                        sed -i 's/ramfsfile=initrd.img//' /boot/config.txt
                        sed -i 's/ramfsaddr=-1//' /boot/config.txt
                        # clean empty lines
                        sed -i '/./,/^$/!d' /boot/config.txt

                        # reload settings after restore
                        source /boot/crankshaft/crankshaft_env.sh

                        # check rtc setup
                        RTC_CHECK=$(cat /boot/config.txt | grep "^dtoverlay=i2c-rtc")
                        if [ ! -z $RTC_CHECK ]; then
                            # check rtc services
                            CHECK_RTC_LOAD=$(systemctl -l --state enabled --all list-unit-files | grep hwclock-load | awk {'print $2'})
                            if [ "$CHECK_RTC_LOAD" != "enabled" ]; then
                                systemctl enable hwclock-load.service > /dev/null 2>&1
                            fi

                            CHECK_RTC_SAVE=$(systemctl -l --state enabled --all list-unit-files | grep hwclock-save | awk {'print $2'})
                            if [ "$CHECK_RTC_SAVE" != "enabled" ]; then
                                systemctl enable hwclock-load.service > /dev/null 2>&1
                            fi
                            systemctl disable fake-hwclock > /dev/null 2>&1
                            # reload services
                            systemctl daemon-reload > /dev/null 2>&1
                            # set tzdata
                            timedatectl set-timezone $(cat /tmp/${PARTITION}/cs-backup/${SERIAL}/etc/timezone) > /dev/null 2>&1
                            # failsafe for coming from pre1
                            if [ -d /tmp/${PARTITION}/cs-backup/etc ]; then
                                timedatectl set-timezone $(cat /tmp/${PARTITION}/cs-backup/${SERIAL}/etc/timezone) > /dev/null 2>&1
                            fi
                            # reset i2c modules
                            sed -i '/i2c/d' /etc/modules
                            # clean empty lines
                            sed -i '/./,/^$/!d' /etc/modules
                            # set modules
                            echo 'i2c_dev' >> /etc/modules
                        fi

                        # check camera setup
                        CAM_CHECK=$(cat /boot/config.txt | grep "^start_x=1")
                        if [ ! -z $CAM_CHECK ]; then
                            touch /etc/button_camera_visible
                            systemctl enable rpicamserver > /dev/null 2>&1
                            systemctl daemon-reload > /dev/null 2>&1
                        fi

                        # restore day/night
                        if [ $RTC_DAYNIGHT -eq 1 ]; then
                            /usr/local/bin/crankshaft timers daynight $RTC_DAY_START $RTC_NIGHT_START > /dev/tty3
                        fi

                        # set done
                        touch /etc/cs_backup_restore_done

                        # sync wait and reboot
                        sync
                        sleep 5
                        reboot
                    fi
                    umount /tmp/${PARTITION}
                    rmdir /tmp/${PARTITION}
                else
                    echo "${RESET}" > /dev/tty3
                    echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                    echo "[${RED}${BOLD} WARN ${RESET}] Mount failed!" > /dev/tty3
                    echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                    sleep 5
                fi
            fi
        fi
    done
else
    echo "${RESET}" > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] Backup already restored." > /dev/tty3
    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
fi

exit 0