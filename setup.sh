apt install -y golang-go make

git clone https://github.com/containernetworking/plugins
cd plugins
bash build_linux.sh
mkdir -p /opt/cni/bin
sudo cp bin/* /opt/cni/bin/

cd ..
git clone https://github.com/awslabs/tc-redirect-tap
cd tc-redirect-tap
make
sudo cp tc-redirect-tap /opt/cni/bin/
cd ..

wget https://github.com/firecracker-microvm/firecracker/releases/download/v1.11.0/firecracker-v1.11.0-x86_64.tgz
tar -xzf firecracker-v1.11.0-x86_64.tgz
cp release-v1.11.0-x86_64/firecracker-v1.11.0-x86_64 /usr/bin/firecracker

rm -rf release-v1.11.0-x86_64 firecracker-v1.11.0-x86_64.tgz

mkdir -p /etc/cni/conf.d
cp fcnet.conflist /etc/cni/conf.d/fcnet.conflist

ARCH="$(uname -m)"

latest=$(wget "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/v1.11/$ARCH/vmlinux-5.10&list-type=2" -O - 2>/dev/null | grep -oP "(?<=<Key>)(firecracker-ci/v1.11/$ARCH/vmlinux-5\.10\.[0-9]{1,3})(?=</Key>)")

# Download a linux kernel binary
wget "https://s3.amazonaws.com/spec.ccfc.min/${latest}"

# Download a rootfs
wget -O ubuntu-24.04.squashfs.upstream "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.11/${ARCH}/ubuntu-24.04.squashfs"

# Create an ssh key for the rootfs
unsquashfs ubuntu-24.04.squashfs.upstream
ssh-keygen -f id_rsa -N ""
cp -v id_rsa.pub squashfs-root/root/.ssh/authorized_keys
mv -v id_rsa ./ubuntu-24.04.id_rsa

# Add nameserver to resolv.conf
echo "nameserver 1.1.1.1" > squashfs-root/etc/resolv.conf

# create ext4 filesystem image
sudo chown -R root:root squashfs-root
truncate -s 400M ubuntu-24.04.ext4
sudo mkfs.ext4 -d squashfs-root -F ubuntu-24.04.ext4

rm -rf squashfs-root ubuntu-24.04.squashfs.upstream


go mod tidy
