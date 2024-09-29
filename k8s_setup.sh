#!/bin/bash

# Variables
TEMPLATE_VMID=9000
VMID1=100
VMID2=101
VMID3=102
NODE1_NAME="controller"
NODE2_NAME="worker1"
NODE3_NAME="worker2"
CPU=2
RAM=2048
DISK_SIZE=20G
BRIDGE="vmbr0"
ISO_STORAGE="local"
STORAGE="local-lvm"

# Create Ubuntu Cloud-Init Template VM
if ! qm status $TEMPLATE_VMID &>/dev/null; then
    echo "Creating Ubuntu Cloud-Init Template VM..."

    # Download Ubuntu Cloud Image
    CLOUD_IMAGE="jammy-server-cloudimg-amd64.img"
    if [ ! -f /var/lib/vz/template/qcow2/$CLOUD_IMAGE ]; then
        wget -O /var/lib/vz/template/qcow2/$CLOUD_IMAGE https://cloud-images.ubuntu.com/jammy/current/$CLOUD_IMAGE
    fi

    # Create VM
    qm create $TEMPLATE_VMID --name "ubuntu2204-template" --memory $RAM --cores $CPU --net0 virtio,bridge=$BRIDGE --serial0 socket --vga serial0 --scsihw virtio-scsi-pci

    # Import disk
    qm importdisk $TEMPLATE_VMID /var/lib/vz/template/qcow2/$CLOUD_IMAGE $STORAGE

    # Attach the disk
    qm set $TEMPLATE_VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_VMID-disk-0

    # Add Cloud-Init Drive
    qm set $TEMPLATE_VMID --ide2 $STORAGE:cloudinit

    # Set bootdisk and bootorder
    qm set $TEMPLATE_VMID --boot c --bootdisk scsi0

    # Set serial console
    qm set $TEMPLATE_VMID --serial0 socket --vga serial0

    # Convert to template
    qm template $TEMPLATE_VMID
else
    echo "Template VM $TEMPLATE_VMID already exists."
fi

# Function to create a VM from template
create_vm() {
    local NEW_VMID=$1
    local NEW_VMNAME=$2

    echo "Creating VM $NEW_VMID ($NEW_VMNAME)..."

    # Clone the template
    qm clone $TEMPLATE_VMID $NEW_VMID --name $NEW_VMNAME

    # Resize disk
    qm resize $NEW_VMID scsi0 $DISK_SIZE

    # Set VM configuration
    qm set $NEW_VMID --cores $CPU --memory $RAM

    # Set Cloud-Init user data
    qm set $NEW_VMID --ciuser ubuntu --cipassword ubuntu --sshkeys "$(cat ~/.ssh/id_rsa.pub)" --hostname $NEW_VMNAME

    # Start the VM
    qm start $NEW_VMID
}

# Create VMs
create_vm $VMID1 $NODE1_NAME
create_vm $VMID2 $NODE2_NAME
create_vm $VMID3 $NODE3_NAME

echo "All VMs have been created and started."

# Instructions to initialize Kubernetes cluster

echo "Please SSH into the controller node and run the following commands to initialize the Kubernetes cluster:"

echo "ssh ubuntu@<controller-node-ip>"
echo "sudo kubeadm init --pod-network-cidr=10.244.0.0/16"

echo "Then, join the worker nodes using the token provided by kubeadm."

