#!/bin/bash

echo "
     **                    **            **       **
    ****                  /**           /**      //
   **//**   ******  ***** /**           /**       ** *******  **   ** **   **
  **  //** //**//* **///**/******       /**      /**//**///**/**  /**//** **
 ********** /** / /**  // /**///**      /**      /** /**  /**/**  /** //***
/**//////** /**   /**   **/**  /**      /**      /** /**  /**/**  /**  **/**
/**     /**/***   //***** /**  /**      /********/** ***  /**//****** ** //**
//      // ///     /////  //   //       //////// // ///   //  ////// //   //
"
sleep 1
for (( c=5; c>=1; c--))
do
   echo "Arch installation starts in $c"; sleep 1
done

set -eu

user="manu"
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
MAGENTA="\e[35m"
ENDCOLOR="\e[0m"

status_command(){
    $1  && (echo -e "$run ${GREEN}>>>>> OK${ENDCOLOR}"; exit 0) || (code=$?; echo -e "$run ${RED}>>>>> FAILED${ENDCOLOR}"; (echo -e "${MAGENTA}Code Error $code${ENDCOLOR}"; exit $code))
}

doCreatePartitions(){
    echo "This script will create and format the partitions as follows:"
    echo "/dev/sda1 - 512Mib will be mounted as /boot/efi"
    echo "/dev/sda2 - 2GB will be used as swap"
    echo "/dev/sda3 - 5GB will be used in /"
    echo "/dev/sda4 - rest of space will be mounted as Home"

    # to create the partitions programatically (rather than manually)
    # https://superuser.com/a/984637
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
      g # Create a new empty GTP partition table
      n # new partition
      1 # partition number 1
        # default - start at beginning of disk 
      +512M # 512 MB boot parttion
      n # new partition
      2 # partion number 2
        # default, start immediately after preceding partition
      +2G # 4 GB swap parttion
      n # new partition
      3 # partion number 3
        # default, start immediately after preceding partition
      +6G # 6 GB root 
      n # new partition
      4 # partion number 4
        # default, start immediately after preceding partition
        # default, extend partition to end of disk
      p # print the in-memory partition table
      w # write the partition table
EOF
}

doFormatingPartitions(){
    mkfs.ext4 /dev/sda3
    mkfs.ext4 /dev/sda4
    mkfs.fat -F32 /dev/sda1
    mkswap /dev/sda2
    swapon /dev/sda2
}

doMount(){
    mount /dev/sda3 /mnt
    mount --mkdir /dev/sda1 /mnt/boot
    mount --mkdir /dev/sda4 /mnt/home
}

doInstallArch(){
    pacstrap  /mnt base linux linux-firmware grub efibootmgr intel-ucode networkmanager  man-db man-pages texinfo nano zsh sudo
}

doCreateFstab(){
    genfstab -U /mnt >> /mnt/etc/fstab
}

doScriptConfigSystem(){
    cp ~/easy_arch/config_system /mnt/home
    arch-chroot /mnt sh /home/config_system
    rm /mnt/home/config_system
}

doScriptMiEnviroment(){
    cp ~/easy_arch/mi_enviroment /mnt/home/$user
    arch-chroot /mnt su $user -c "cd /home/$user; bash /home/$user/mi_enviroment"
    rm /mnt/home/$user/mi_enviroment
}

doUmount(){
    umount -R /mnt
}

run_system=(
doCreatePartitions
doFormatingPartitions
doMount
doInstallArch
doCreateFstab
)

for run in ${run_system[@]}; do
    printf "\n${BLUE}Execute $run${ENDCOLOR}\n" ; sleep 2
    status_command $run
done

doScriptConfigSystem
doScriptMiEnviroment
doUmount

printf "\nSetup Complete arch!\n"
printf "type 'reboot' and remove installation media."

