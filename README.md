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

# Building seperate initrd and squasfs

```bash
nix build --out-link initrd .\#nixosConfigurations.minimal.config.system.build.initialRamdisk
nix build --out-link squashfs .\#nixosConfigurations.minimal.config.system.build.squashfsStore
```
