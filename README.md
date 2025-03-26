# Usage

- Build the kernel
	- ```bash
		nix build .\#nixosConfigurations.minimal.config.boot.kernelPackages.kernel
		```

- Build the kernel config file
	- ```bash
		nix build .\#nixosConfigurations.minimal.config.boot.kernelPackages.kernel.configfile
		```

- Build the initrd
	- ```bash
		nix build .\#nixosConfigurations.minimal.config.system.build.netbootRamdisk
		```

- Build the toplevel system closure
	- ```bash
		nix build .\#nixosConfigurations.minimal.config.system.build.toplevel
		```

- Build and run as VM
	- ```bash
		nix run .\#nixosConfigurations.minimal.config.system.build.run-with-qemu
		```
