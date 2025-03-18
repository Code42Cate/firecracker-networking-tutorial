package main

import (
	"context"
	"os"

	"github.com/firecracker-microvm/firecracker-go-sdk"
	"github.com/firecracker-microvm/firecracker-go-sdk/client/models"
)

func main() {
	ctx := context.TODO()

	machine, err := firecracker.NewMachine(ctx, firecracker.Config{
		SocketPath:      "./firecracker.sock",
		KernelImagePath: "./vmlinux-5.10.225",
		KernelArgs:      "console=ttyS0 reboot=k panic=1 pci=off",
		Drives: []models.Drive{{
			IsRootDevice: firecracker.Bool(true),
			IsReadOnly:   firecracker.Bool(false),
			PathOnHost:   firecracker.String("./ubuntu-24.04.ext4"),
			DriveID:      firecracker.String("rootfs"),
		}},
		MachineCfg: models.MachineConfiguration{
			VcpuCount:  firecracker.Int64(2),
			MemSizeMib: firecracker.Int64(1024),
		},
		NetworkInterfaces: []firecracker.NetworkInterface{
			{
				CNIConfiguration: &firecracker.CNIConfiguration{
					NetworkName: "fcnet",
					IfName:      "veth0",
					BinPath:     []string{"/opt/cni/bin"},
				},
			},
		},
	})
	if err != nil {
		panic(err)
	}

	if err := machine.Start(ctx); err != nil {
		panic(err)
	}

	<-make(chan os.Signal, 1)

	if err := machine.Shutdown(ctx); err != nil {
		panic(err)
	}
}
