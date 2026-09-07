#!/bin/bash
set -e

# ==============================================================================
# Arch Linux LUKS + Limine + Minimal KDE Plasma Installation Script
# ==============================================================================

# EDIT THESE VARIABLES BEFORE RUNNING
DISK="/dev/nvme0n1"           # Target drive (WARNING: WILL BE WIPED)
HOSTNAME="archlinux"
USERNAME="karim"
TIMEZONE="America/Toronto"    # Timezone for London, Ontario

# Detect partition naming convention (nvme0n1p1 vs sda1)
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    PART_ESP="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_ESP="${DISK}1"
    PART_ROOT="${DISK}2"
fi

# Prompt for password to use for encryption and user accounts
read -s -p "Enter password (used for LUKS, root, and $USERNAME): " PASSWORD
echo

# 1. Update system clock
timedatectl set-ntp true

# 2. Partition the disk (UEFI Layout: 1GB ESP, Remainder Root)
echo "Wiping and partitioning $DISK..."
sgdisk -Z "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 "$DISK"
sgdisk -n 2:0:0 -t 2:8309 "$DISK"
partprobe "$DISK"
sleep 2

# 3. Setup LUKS Encryption
echo "Encrypting root partition..."
echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 "$PART_ROOT" -
echo -n "$PASSWORD" | cryptsetup open "$PART_ROOT" cryptroot -d -

# 4. Format the partitions (Simplest layout: ext4 inside LUKS)
echo "Formatting filesystems..."
mkfs.fat -F32 "$PART_ESP"
mkfs.ext4 /dev/mapper/cryptroot

# 5. Mount the filesystems
echo "Mounting filesystems..."
mount /dev/mapper/cryptroot /mnt
mount --mkdir "$PART_ESP" /mnt/boot

# 6. Install Base System and Minimal KDE Packages
# Including both amd-ucode and intel-ucode for hardware portability between laptops
echo "Running pacstrap..."
pacstrap -K /mnt base linux linux-firmware mkinitcpio cryptsetup sudo efibootmgr limine \
    amd-ucode intel-ucode nano vim \
    networkmanager pipewire pipewire-pulse wireplumber \
    sddm plasma-desktop plasma-nm plasma-pa konsole dolphin

# 7. Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 8. Get LUKS partition UUID for the bootloader configuration
LUKS_UUID=$(blkid -s UUID -o value "$PART_ROOT")

# 9. Configure the system in chroot
echo "Entering chroot to configure system..."
cat <<EOF | arch-chroot /mnt
set -e

# Timezone and Localization
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Passwords and User
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Configure mkinitcpio for encryption
# Adds 'keyboard', 'keymap', and 'encrypt' hooks before 'filesystems'
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Install and configure Limine Bootloader
mkdir -p /boot/EFI/BOOT
# Copy Limine EFI executable to standard fallback path
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
# Register Limine with UEFI boot manager
efibootmgr --create --disk "$DISK" --part 1 --loader /EFI/BOOT/BOOTX64.EFI --label "Limine"

# Create Limine configuration file
cat <<LIMINE > /boot/limine.conf
timeout: 3

/Arch Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    initramfs_path: boot():/initramfs-linux.img
    cmdline: cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rw quiet
LIMINE

# Enable Display Manager and Networking
systemctl enable sddm
systemctl enable NetworkManager
EOF

# 10. Clean up and unmount
echo "Installation complete. Unmounting..."
umount -R /mnt
cryptsetup close cryptroot

echo "You can now reboot."
