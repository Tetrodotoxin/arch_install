#before running this file on the live cd
#pacman -Syyy
#pacman -S openssh
#systemctl start sshd
#passwd      change to "toor"
#ip a

#on this machine run
#scp -r ~/Desktop/arch_install.sh root@(((with ip address from live cd))):~

#back to live cd, run
#chmod +x arch_install.sh

echo " "
echo "Which part of the script do you wish to run."
echo "(1 for pre-chroot, 2 for post-chroot, 3 for post-reboot)"
read SCRIPT_ID

case $SCRIPT_ID in

  "1")  # This is the pre-chroot script
    pacman -Syyy
    pacman -S reflector
    reflector -c Canada -a 6 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syyy

    timedatectl set-ntp true

    if [ -d /sys/firmware/efi ]
    then
      IS_EFI=true
    else
      IS_EFI=false
    fi

    echo "Is the storage 'fake' RAID based: true or false"
    read IS_SSD

    echo "Is the storage 'fake' RAID based: true or false"
    read IS_RAID

    lsblk
    echo "Enter the disk identifier..."
    echo "Eg. if /dev/sda -> sda , if /dev/md/SSDRAID_0 -> md/SSDRAID_0"
    if [ "$IS_RAID" = true ] ; then
      ls /dev/md/
      echo "system is 'fake' raid based use /dev/md/* identifier"
    fi
    read DISK_ID

    #partition 1 is a 500M efi part
    #partition 2 is the rest of the disk to be subdivided w/ btrfs
    if [ "$IS_EFI" = true ]
    then
      echo "quick recap, this is EFI, use 'g' to make new gpt table"
      echo "'n' to make new partition, boot partition should be 500M"
      echo "'t' to change type of partition to efi, flag = 1"
    else
      echo "quick recap, this is BIOS, use 'o' to make new mbr record"
      echo "'n' to make new partition, boot partition should be 500M"
      echo "give boot partition bootable flag by 'a'  command"
      echo "make both boot and data partitions primary, linux filesystems"
    fi
    echo "make a new data part for btrfs, usually takes up the rest of the disk"
    echo "'p' to check it is right, and 'w' to finish and write out"
    echo "press enter to continue..."
    read NOTHING

    fdisk /dev/$DISK_ID

    lsblk
    echo "Enter the boot partition identifier..."
    echo "Eg. if /dev/sda2 -> 2 , if /dev/md/SSDRAID_0p5 -> p5"
    read BOOT_ID

    lsblk
    echo "Enter the BTRFS data partition identifier..."
    echo "Eg. if /dev/sda2 -> 2 , if /dev/md/SSDRAID_0p5 -> p5"
    read DATA_ID

    if [ "$IS_EFI" = true ]
    then
      mkfs.fat -F32 /dev/$DISK_ID$BOOT_ID
    else
      mkfs.ext4 /dev/$DISK_ID$BOOT_ID
    fi
    mkfs.btrfs /dev/$DISK_ID$DATA_ID

    mount /dev/$DISK_ID$DATA_ID /mnt

    btrfs su cr /mnt/@
    btrfs su cr /mnt/@home
    btrfs su cr /mnt/@swap


    umount /mnt

    if [ "$IS_SSD" = true ]
    then #to add trimming "discard=async" mount options when lts kernel is >=v5.6#####
      mount -o noatime,compress=lzo,space_cache,subvol=@ /dev/$DISK_ID$DATA_ID /mnt
      mkdir -p /mnt/{boot,swap,home}
      mount -o noatime,compress=lzo,space_cache,subvol=@home /dev/$DISK_ID$DATA_ID /mnt/home
      mount -o noatime,compress=lzo,space_cache,subvol=@swap /dev/$DISK_ID$DATA_ID /mnt/swap
    else
      mount -o noatime,compress=lzo,space_cache,subvol=@ /dev/$DISK_ID$DATA_ID /mnt
      mkdir -p /mnt/{boot,swap,home}
      mount -o noatime,compress=lzo,space_cache,subvol=@home /dev/$DISK_ID$DATA_ID /mnt/home
      mount -o noatime,compress=lzo,space_cache,subvol=@swap /dev/$DISK_ID$DATA_ID /mnt/swap
    fi


    mount /dev/$DISK_ID$BOOT_ID /mnt/boot

    pacstrap /mnt base linux-lts linux-lts-headers linux-firmware nano

    genfstab -U /mnt >> /mnt/etc/fstab

    if [ "$IS_RAID" = true ] ; then
      mdadm --detail --scan >> /mnt/etc/mdadm.conf
    fi


    mv ~/arch_install.sh /mnt

    echo "execute arch-chroot /mnt and run arch_install.sh"
    ;;

  "2")  # This is the post-chroot script

    echo "Is this system Intel based: true or false"
    read IS_INTEL

    echo "Do you wish to install graphics drivers: true or false"
    read WANT_GRAPHICS

    if [ "$WANT_GRAPHICS" = true ] ; then
      echo "Is this system NVIDIA based: true or false"
      read IS_NVIDIA
    fi

    if [ -d /sys/firmware/efi ]
    then
      IS_EFI=true
    else
      IS_EFI=false
    fi

    echo "Is the storage 'fake' RAID based: true or false"
    read IS_RAID

    echo "Input desired Hostname"
    read HOSTNAME

    pacman -Syyy
    pacman -S reflector
    reflector -c Canada -a 6 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syyy

    ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
    hwclock --systohc

    echo "uncomment line containing en_us.utf-8"
    echo "Press enter to continue..."
    read NOTHING
    nano /etc/locale.gen

    locale-gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf

    echo $HOSTNAME >> /etc/hostname

    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "::1   localhost" >> /etc/hosts
    echo "127.0.1.1 ${HOSTNAME}.knet ${HOSTNAME}" >> /etc/hosts

    echo "Set root password"
    passwd

    echo "uncomment multilib repos and resync pacman"
    echo "press enter to continue..."
    read NOTHING
    nano /etc/pacman.conf
    pacman -Syyy

    pacman -S sudo man htop zsh grub networkmanager network-manager-applet wireless_tools wpa_supplicant dialog os-prober mtools dosfstools base-devel cron openssh base-devel netctl mesa btrfs-progs


    if [ "$IS_INTEL" = true ]
    then
      pacman -S intel-ucode
    else
      pacman -S amd-ucode
    fi

    if [ "$IS_EFI" = true ] ; then
      pacman -S efibootmgr
    fi

    if [ "$WANT_GRAPHICS" = true ] ; then
      if [ "$IS_NVIDIA" = true ]
      then
        pacman -S nvidia-lts nvidia-utils xorg
      else
        pacman -S xf86-video-amdgpu xorg
      fi
    fi

    if [ "$IS_RAID" = true ] ; then
      pacman -S mdadm dmraid
      echo "Add mdadm_udev to HOOKS list and add /sbin/mdmon to BINARIES list"
      echo "press enter to continue"
      read NOTHING
      echo "remember, mdadm_udev to HOOKS , /sbin/mdmon to BINARIES "
      echo "press enter to continue"
      read NOTHING
      nano /etc/mkinitcpio.conf
    fi


    systemctl enable sshd
    systemctl enable NetworkManager

    mkinitcpio -p linux-lts


    useradd -mG wheel kadmin
    echo "Set kadmin's password"
    passwd kadmin

    echo "allow wheel group members to use sudo, uncomment line %wheel ALL=(ALL) ALL"
    echo "Press enter to continue..."
    read NOTHING
    EDITOR=nano visudo



    if [ "$IS_EFI" = true ]
    then
      grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
    else
      lsblk
      echo "Enter the disk identifier..."
      echo "Eg. if /dev/sda -> sda , if /dev/md/SSDRAID_0 -> md/SSDRAID_0"
      if [ "$IS_RAID" = true ] ; then
        ls /dev/md/
        echo "system is 'fake' raid based use /dev/md/* identifier"
      fi
      read DISK_ID
      grub-install --target=i386-pc /dev/$DISK_ID
    fi

    mkdir /boot/grub/locale
    cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
    grub-mkconfig -o /boot/grub/grub.cfg

    grep MemTotal /proc/meminfo
    echo "enter number of gigabytes of swapfile to be allocated"
    echo "minimum the same amount of ram+1 on the system to a minimum of 8"
    echo "if this is a machine for the kube cluster double ram to a min of 10"
    read SWAP_SIZE

    fallocate -l ${SWAP_SIZE}G /swap/swapfile
    chmod 600 /swap/swapfile
    mkswap /swap/swapfile

    cp /etc/fstab /etc/fstab.bak
    echo '/swap/swapfile none swap sw 0 0' | tee -a /etc/fstab

    if [ "$IS_RAID" = true ] ; then
      echo "the raid route in this script is untested, if something fails go to "
      echo "https://wiki.archlinux.org/index.php/Install_Arch_Linux_with_Fake_RAID"
      echo "it had worked for me before and may help again, just remember to update "
      echo "the script after the problem is solved to improve in the future."
    fi

    echo 'edit makepkg.conf, uncomment MAKEFLAGS and change to ="j$(nrpoc)" '
    echo "press enter to continue..."
    read NOTHING
    nano /etc/makepkg.conf


    mv arch_install.sh /home/kadmin
    echo "Now exit chroot, umount -a, reboot and pray"

    ;;
  "3")
    #post reboot installation of yay and timeshift and (?others?)...
    echo "Is this computer going to one of the kube cluster: true or false"
    read IS_KUBE

    cd ~
    sudo pacman -S git grub-theme-vimix screenfetch zsh-theme-powerlevel10k lm_sensors
    mkdir aur_repos
    cd aur_repos
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ~
    yay -S timeshift

    lsblk
    sudo timeshift --list-devices
    echo "select target device for timeshift (whole partition path eg. /dev/sda2)"
    read TS_TARGET
    sudo timeshift --target $TS_TARGET

    echo 'edit  /etc/timeshift.json to preference'
    echo 'usually; btrfs_mode true,include btrfs home backup true,<-restore false '
    echo 'all schedules active, counts... month 12,week 4,daily 7,hourly 12,boot 5... '
    #######lookup snapshot count and exclude fields########
    echo 'press enter to continue...'
    read NOTHING
    sudo nano /etc/timeshift.json
    sudo timeshift --target $TS_TARGET #make timeshift optional
    sudo timeshift --check
    sudo timeshift --list-snapshots
    echo 'Does this list of snapshots look good?'
    echo 'press enter to continue...'
    read NOTHING

    echo 'next you will be asked if you want to change the default shell to zsh'
    echo 'select yes, then type the "exit" command for the script to continue'
    echo 'press enter to continue...'
    read NOTHING
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    yay -S nerd-fonts-complete
    ln -s /usr/share/zsh-theme-powerlevel10k .oh-my-zsh/themes/powerlevel10k
    echo 'enter "powerlevel10k/powerlevel10k" into ZSH_THEME field in .zshrc'
    echo 'press enter to continue...' #needs work, nerd fonts come different now
    read NOTHING
    nano .zshrc

    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    echo 'enter zsh-autosuggestions into plugins field in .zshrc'
    echo 'press enter to continue...' #add more plugins zsh autocomplete zsh-syntax-highlighting
    read NOTHING
    nano .zshrc

    echo 'if [ -f /usr/bin/screenfetch ]; then screenfetch; fi' | tee -a .zshrc

    echo 'uncomment GRUB_THEME field and enter '
    echo '"/usr/share/grub/themes/Vimix/theme.txt" in /etc/default/grub'
    echo 'press enter to continue...' #changs so vimix theme lives on /boot
    read NOTHING
    sudo nano /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg

    sudo sensors-detect

    #look more into irq failure
    #find out issue with btrfs swapfile

    if [ "$IS_KUBE" = true ] ; then
      echo 'reduce GRUB_TIMEOUT field to 3 seconds to speed up reboot'
      echo 'press enter to continue...'
      read NOTHING
      sudo nano /etc/default/grub
      sudo grub-mkconfig -o /boot/grub/grub.cfg
      sudo pacman -S docker-compose
    fi

    # add optional addition of kde plasma +sddm +themeing


    echo 'fix any boot errors such as no irq handler et al. then grub-mkconfig -o /boot/grub/grub.cfg '
    echo 'press enter to continue...'
    read NOTHING
    ip a
    echo 'then SSH into this machine and perform "p10k configure" command as the'
    echo 'headless machine cannot display the required fonts, and reboot'
    echo 'press enter to continue...'
    read NOTHING

    chsh -s /bin/zsh
    ;;

  *)
    echo "invalid selection, try again"
esac
