#!/bin/bash
# Script de instalación automatizada de Arch Linux
# Autor: eybolo
# ADVERTENCIA: Este script formateará /dev/sda completamente
set -eu  # Salir en error (-e) y tratar variables no definidas como error (-u)

# ===========================
# Variables de configuración
# ===========================
user="manu"
hostname="eybolo"

disk="sda"      # Nombre del disco
size_boot="512M" # Definir tamanio para boot
size_swap="2G"   # Definir tamnio para swap
size_root="16G"  # Definir tamanio para root o /
# Particion Home obtiene el resto del tamanio del disco

# Códigos de color ANSI para mensajes en terminal
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
MAGENTA="\e[35m"
ENDCOLOR="\e[0m"

# ===========================
# Función auxiliar
# ===========================

# Ejecuta un comando y muestra estado visual de éxito/fallo
# Parámetro: $1 = nombre de la función a ejecutar
# Sale del script si el comando falla

status_command(){
    $1  && (echo -e "$run ${GREEN}>>>>> OK${ENDCOLOR}"; exit 0) \
    || (code=$?; echo -e "$run ${RED}>>>>> FAILED${ENDCOLOR}"; \
    (echo -e "${MAGENTA}Code Error $code${ENDCOLOR}"; exit $code))
}

# ===========================
# Banner inicial
# ===========================
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

# Countdown antes de comenzar la instalación
sleep 1
for (( c=5; c>=1; c--))
do
    echo "Arch installation starts in $c"; sleep 1
done

# ===========================
# Funciones de instalación
# ===========================

# Crea la tabla de particiones GPT en /dev/sda
# Layout: 512MB EFI + 2GB swap + 40GB root + resto home
doCreatePartitions(){
    echo "This script will create and format the partitions as follows:"
    echo "/dev/${disk}1 - ${size_boot} will be mounted as /boot/efi"
    echo "/dev/${disk}2 - ${size_swap} will be used as swap"
    echo "/dev/${disk}3 - ${size_root} will be used in /"
    echo "/dev/${disk}4 - rest of space will be mounted as Home"
    sleep 5
    
    # Usa sed para limpiar comentarios y enviar comandos a fdisk
    # Basado en: https://superuser.com/a/984637
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${disk}
      g # Crear tabla de particiones GPT vacía
      n # Nueva partición
      1 # Número de partición 1
        # Inicio por defecto (comienzo del disco)
      +${size_boot} # Partición de arranque EFI 
      n # Nueva partición
      2 # Número de partición 2
        # Inicio por defecto (después de la anterior)
      +${size_swap} # Partición de swap
      n # Nueva partición
      3 # Número de partición 3
        # Inicio por defecto
      +${size_root} # Partición root
      n # Nueva partición
      4 # Número de partición 4
        # Inicio por defecto
        # Fin por defecto (usa todo el espacio restante para Home)
      p # Imprimir tabla de particiones en memoria
      w # Escribir cambios al disco

EOF
}

# Formatea las particiones con los sistemas de archivos apropiados
doFormatingPartitions(){
    mkfs.ext4 "/dev/${disk}3"    # Root con ext4
    mkfs.ext4 "/dev/${disk}4"    # Home con ext4
    mkfs.fat -F32 "/dev/${disk}1"  # EFI con FAT32
    mkswap "/dev/${disk}2"       # Inicializar swap
    swapon "/dev/${disk}2"       # Activar swap
}

# Monta las particiones en /mnt para la instalación
doMount(){
    mount "/dev/${disk}3" /mnt              # Montar root
    mount --mkdir "/dev/${disk}1" /mnt/boot  # Montar EFI (crea directorio)
    mount --mkdir "/dev/${disk}4" /mnt/home  # Montar home (crea directorio)
}

# Instala el sistema base de Arch Linux con pacstrap
doInstallArch(){
    # Detectar tipo de CPU
    if grep -q "Intel" /proc/cpuinfo; then
        ucode="intel-ucode"
    elif grep -q "AMD" /proc/cpuinfo; then
        ucode="amd-ucode"
    else
        ucode=""  # CPU desconocido
    fi
    
    # Instalar con el microcode apropiado
    pacstrap /mnt base linux linux-firmware grub efibootmgr sudo zsh $ucode
            #$ucode networkmanager man-db man-pages \
            #texinfo nano zsh sudo
}

# Genera el archivo fstab con UUIDs para montaje automático al boot
doCreateFstab(){
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Ejecuta el script de configuración del sistema dentro del chroot
# Configura timezone, locale, hostname, usuarios, etc.
doScriptConfigSystem(){
    cp ~/easy_arch/config_system /mnt/home
    arch-chroot /mnt sh /home/config_system "$user" "$hostname"
    rm /mnt/home/config_system  # Limpiar script temporal
}

# Ejecuta el script de configuración personal del usuario
# Instala dotfiles, paquetes adicionales, entorno de desarrollo, etc.
doScriptMiEnviroment(){
    cp ~/easy_arch/mi_enviroment /mnt/home/$user
    arch-chroot /mnt su $user -c "cd /home/$user; bash /home/$user/mi_enviroment '$user'"
    rm /mnt/home/$user/mi_enviroment  # Limpiar script temporal
}

# Desmonta todas las particiones antes del reboot
doUmount(){
    umount -R /mnt
}

# ===========================
# Ejecución principal
# ===========================

# Array de funciones a ejecutar secuencialmente
# Estas constituyen la instalación base del sistema
run_system=(
    doCreatePartitions
    doFormatingPartitions
    doMount
    doInstallArch
    doCreateFstab
)

# Ejecutar cada función del array en orden
# Si alguna falla, el script se detiene (gracias a status_command)
for run in ${run_system[@]}; do
    printf "\n${BLUE}Execute $run${ENDCOLOR}\n"
    sleep 2
    status_command $run
done

# Configuración post-instalación
doScriptConfigSystem
doScriptMiEnviroment
doUmount

# ===========================
# Finalización
# ===========================
printf "\nSetup Complete arch!\n"
printf "type 'reboot' and remove installation media."
