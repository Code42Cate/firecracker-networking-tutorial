#!/bin/bash

install_prerequisites() {
    echo "Installing prerequisites (golang-go and make)..."
    apt install -y golang-go make
    if [ $? -eq 0 ]; then
        echo "Prerequisites installed successfully"
    else
        echo "Failed to install prerequisites"
        exit 1
    fi
}

build_cni_plugins() {
    echo "Cloning and building CNI plugins..."
    git clone https://github.com/containernetworking/plugins
    cd plugins || exit
    bash build_linux.sh
    mkdir -p /opt/cni/bin
    sudo cp bin/* /opt/cni/bin/
    cd ..
    echo "CNI plugins built and installed"
}

build_tc_redirect() {
    echo "Cloning and building tc-redirect-tap..."
    git clone https://github.com/awslabs/tc-redirect-tap
    cd tc-redirect-tap || exit
    make
    sudo cp tc-redirect-tap /opt/cni/bin/
    cd ..
    echo "tc-redirect-tap built and installed"
}

install_firecracker() {
    echo "Downloading and installing Firecracker v1.11.0..."
    wget https://github.com/firecracker-microvm/firecracker/releases/download/v1.11.0/firecracker-v1.11.0-x86_64.tgz
    tar -xzf firecracker-v1.11.0-x86_64.tgz
    cp release-v1.11.0-x86_64/firecracker-v1.11.0-x86_64 /usr/bin/firecracker
    rm -rf release-v1.11.0-x86_64 firecracker-v1.11.0-x86_64.tgz
    echo "Firecracker installed to /usr/bin/firecracker"
}

setup_cni_config() {
    echo "Setting up CNI configuration..."
    mkdir -p /etc/cni/conf.d
    cp fcnet.conflist /etc/cni/conf.d/fcnet.conflist
    echo "CNI configuration copied to /etc/cni/conf.d/"
}

download_kernel() {
    ARCH="$(uname -m)"
    echo "Detecting architecture: $ARCH"
    echo "Fetching latest kernel version..."
    latest=$(wget "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/v1.11/$ARCH/vmlinux-5.10&list-type=2" -O - 2>/dev/null | grep -oP "(?<=<Key>)(firecracker-ci/v1.11/$ARCH/vmlinux-5\.10\.[0-9]{1,3})(?=</Key>)")
    echo "Downloading kernel: $latest"
    wget "https://s3.amazonaws.com/spec.ccfc.min/${latest}"
    echo "Kernel downloaded"
}

setup_rootfs() {
    echo "Downloading Ubuntu 24.04 rootfs..."
    wget -O ubuntu-24.04.squashfs.upstream "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.11/${ARCH}/ubuntu-24.04.squashfs"

    echo "Extracting squashfs..."
    unsquashfs ubuntu-24.04.squashfs.upstream

    echo "Generating SSH key pair..."
    ssh-keygen -f id_rsa -N "" -q
    cp -v id_rsa.pub squashfs-root/root/.ssh/authorized_keys
    mv -v id_rsa ./ubuntu-24.04.id_rsa

    echo "Configuring nameserver..."
    echo "nameserver 1.1.1.1" > squashfs-root/etc/resolv.conf

    echo "Creating ext4 filesystem image..."
    sudo chown -R root:root squashfs-root
    truncate -s 400M ubuntu-24.04.ext4
    sudo mkfs.ext4 -d squashfs-root -F ubuntu-24.04.ext4

    echo "Cleaning up temporary files..."
    rm -rf squashfs-root ubuntu-24.04.squashfs.upstream
    echo "Root filesystem setup complete"
}

tidy_go_modules() {
    echo "Tidying Go modules..."
    go mod tidy
    if [ $? -eq 0 ]; then
        echo "Go modules tidied successfully"
    else
        echo "No Go modules to tidy or command failed"
    fi
}

main() {
    echo "Starting setup process..."
    install_prerequisites
    build_cni_plugins
    build_tc_redirect
    install_firecracker
    setup_cni_config
    download_kernel
    setup_rootfs
    tidy_go_modules
    echo "Setup process completed!"
}

main
