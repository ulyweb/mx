  ---
  What's Different — SysVinit vs systemd

  ┌────────────────┬──────────────────────────────────┬──────────────────────────────────────┐
  │                │        mx_post_install.sh        │     mx_post_install_sysVinit.sh      │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ Init check     │ Exits if NOT systemd             │ Exits if NOT SysVinit                │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ Service helper │ systemctl enable --now           │ service start + update-rc.d defaults │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ UFW            │ systemctl enable --now ufw       │ ufw enable (self-managed)            │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ Samba          │ systemctl enable --now smbd/nmbd │ service start + update-rc.d          │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ libvirtd       │ systemctl enable --now libvirtd  │ service libvirtd start + update-rc.d │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ libvirt-guests │ Always enabled                   │ Only if init script exists           │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ PM2 startup    │ pm2 startup systemd              │ pm2 startup (auto-detects SysVinit)  │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ fwupd          │ Full daemon support              │ Warning shown — CLI mode only        │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ Docker         │ systemctl enable docker          │ service docker start + update-rc.d   │
  ├────────────────┼──────────────────────────────────┼──────────────────────────────────────┤
  │ Menu header    │ [systemd] implied                │ [SysVinit] labeled                   │
  └────────────────┴──────────────────────────────────┴──────────────────────────────────────┘

  Both scripts are self-protecting — each one detects the wrong init system and exits before doing anything.

  To use:
  chmod +x mx_post_install.sh mx_post_install_sysVinit.sh

  # systemd install:
  ./mx_post_install.sh

  # SysVinit install:
  ./mx_post_install_sysVinit.sh
