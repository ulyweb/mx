

Normally, Virt-Manager uses the SPICE display protocol to handle copy-and-paste natively, but since we know SPICE is missing from your host's QEMU packages, we have to use a clever workaround to force the VNC display to accept clipboard sharing instead.

To do this, I have added two specific things to your XML file:

1. A `<clipboard copypaste="yes"/>` tag inside your VNC graphics block.
2. A special background communication channel called `qemu-vdagent` that securely passes your copied text between the VM and your host.

Here is your MXVM-ISO updated XML file. Copy this entire block, replace the code in your Virt-Manager XML window, and click **Apply**:

```xml
<domain type="kvm" xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0">
  <name>MX-25.1-ISO</name>
  <uuid>c6d4d034-3968-4742-b848-186e159f93c6</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://debian.org/debian/13"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">4194304</memory>
  <currentMemory unit="KiB">4194304</currentMemory>
  <vcpu placement="static">4</vcpu>
  <os>
    <type arch="x86_64" machine="pc-q35-10.0">hvm</type>
    <boot dev="cdrom"/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode="host-passthrough" check="none" migratable="on"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <target dev="sda" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <controller type="usb" index="0" model="qemu-xhci" ports="15">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    <controller type="pci" index="0" model="pcie-root"/>
    <controller type="pci" index="1" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="1" port="0x10"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="2" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="2" port="0x11"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    <controller type="pci" index="3" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="3" port="0x12"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    <controller type="pci" index="4" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="4" port="0x13"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    <controller type="pci" index="5" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="5" port="0x14"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x4"/>
    </controller>
    <controller type="pci" index="6" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="6" port="0x15"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x5"/>
    </controller>
    <controller type="pci" index="7" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="7" port="0x16"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x6"/>
    </controller>
    <controller type="pci" index="8" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="8" port="0x17"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x7"/>
    </controller>
    <controller type="pci" index="9" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="9" port="0x18"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="10" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="10" port="0x19"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x1"/>
    </controller>
    <controller type="pci" index="11" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="11" port="0x1a"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x2"/>
    </controller>
    <controller type="pci" index="12" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="12" port="0x1b"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x3"/>
    </controller>
    <controller type="pci" index="13" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="13" port="0x1c"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x4"/>
    </controller>
    <controller type="pci" index="14" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="14" port="0x1d"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x5"/>
    </controller>
    <controller type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    <controller type="virtio-serial" index="0">
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </controller>
    <interface type="network">
      <mac address="52:54:00:48:0b:b8"/>
      <source network="default"/>
      <model type="virtio"/>
      <link state="down"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <channel type="unix">
      <target type="virtio" name="org.qemu.guest_agent.0"/>
      <address type="virtio-serial" controller="0" bus="0" port="1"/>
    </channel>
    <channel type="qemu-vdagent">
      <target type="virtio" name="com.redhat.spice.0"/>
    </channel>
    <input type="tablet" bus="usb">
      <address type="usb" bus="0" port="1"/>
    </input>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="vnc" port="-1" autoport="yes">
      <listen type="address"/>
      <clipboard copypaste="yes"/>
    </graphics>
    <sound model="ich9">
      <audio id="1"/>
    </sound>
    <audio id="1" type="pulseaudio"/>
    <video>
      <model type="virtio" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    <watchdog model="itco" action="reset"/>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
    </memballoon>
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </rng>
  </devices>
  <qemu:commandline>
    <qemu:env name="XDG_RUNTIME_DIR" value="/run/user/1000"/>
  </qemu:commandline>
</domain>

```

### One Final Step Inside the VM

For the clipboard to successfully pass back and forth, the virtual machine itself needs to know how to listen for it. Once you boot up your MX Linux VM and get to the desktop, open the terminal *inside* the VM and make sure the communication package is installed:

```bash
sudo apt update
sudo apt install spice-vdagent

```

*(Even though we aren't using SPICE for video, this package handles the actual text copying).*

Reboot the VM once that is installed, and you should be able to copy from your Dell and paste directly into the VM!




Master cheat sheet for building the fastest, most stable virtual machines in Virt-Manager.

Because Virt-Manager doesn't natively apply the absolute best performance tweaks out-of-the-box, applying these specific settings during the "Customize configuration before install" step will save you massive amounts of headaches later.

### Virt-Manager Best Settings Cheat Sheet

| Hardware Component | Windows (10 & 11) | Linux (MX, Ubuntu, etc.) | Android-x86 (BlissOS) |
| --- | --- | --- | --- |
| **Chipset / Machine** | Q35 | Q35 | i440fx |
| **Firmware** | UEFI (OVMF) + TPM | BIOS or UEFI | BIOS (SeaBIOS) |
| **CPU Model** | `host-passthrough` | `host-passthrough` | `host-passthrough` |
| **Disk Bus** | Virtio *(Requires Driver)* | Virtio | IDE or SATA |
| **Network Device** | Virtio *(Requires Driver)* | Virtio | e1000 |
| **Display Protocol** | VNC Server | VNC Server | VNC Server |
| **Video Model** | Virtio or QXL | Virtio | VGA *(Edit XML to 64MB)* |
| **Sound Model** | ich9 | ich9 | ac97 |

---

### The 3 Golden Rules of KVM/QEMU Performance

**1. Always Use `host-passthrough` for the CPU**
By default, Virt-Manager emulates a generic, heavily restricted CPU (often called "QEMU Virtual CPU"). This robs you of your Dell's actual processing power. Changing the CPU model to `host-passthrough` lets the VM talk directly to your physical processor, unlocking massive speed boosts and hardware acceleration.

**2. Use Virtio for Disks and Network**
Whenever possible, use the **Virtio** bus type for your virtual hard drives and network cards. Standard IDE or SATA emulation is incredibly slow. Virtio bypasses the emulation bottleneck entirely.

* *Note for Windows:* Windows does not have Virtio drivers built-in. You have to temporarily attach a second virtual CD-ROM drive containing the Red Hat "virtio-win" drivers during installation to see your hard drive.

**3. The Audio XML Workaround is Mandatory**
As long as you are forced to use the VNC Display protocol, the Virt-Manager setup wizard will permanently mute your VM. You will always need to do that quick 10-second XML edit after creating the soundcard:

```xml
<audio id="1" type="pulseaudio"/>
<sound model="ich9">
  <audio id="1"/>
</sound>

```

*(Remember to use `ac97` instead of `ich9` for Android VMs!)*

Here's the XML for Android VMs!

```xml
<domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  <name>android-x86-9.0</name>
  <uuid>398abad5-929a-4ee3-9eb8-09183de6ee43</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://android-x86.org/android-x86/9.0"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">8392704</memory>
  <currentMemory unit="KiB">8392704</currentMemory>
  <vcpu placement="static">4</vcpu>
  <os>
    <type arch="x86_64" machine="pc-i440fx-10.0">hvm</type>
    <bootmenu enable="yes"/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode="host-passthrough" check="none" migratable="on"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2" discard="unmap"/>
      <source file="/var/lib/libvirt/images/android-x86-9.0.qcow2"/>
      <target dev="hda" bus="ide"/>
      <boot order="1"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/home/uly/Downloads/android-x86_64-9.0-r2-k49.iso"/>
      <target dev="hdb" bus="ide"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="1"/>
    </disk>
    <controller type="usb" index="0" model="ich9-ehci1">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x7"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci1">
      <master startport="0"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x0" multifunction="on"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci2">
      <master startport="2"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x1"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci3">
      <master startport="4"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x2"/>
    </controller>
    <controller type="pci" index="0" model="pci-root"/>
    <controller type="ide" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x1"/>
    </controller>
    <interface type="network">
      <mac address="52:54:00:10:b3:89"/>
      <source network="default"/>
      <model type="virtio"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <input type="tablet" bus="usb">
      <address type="usb" bus="0" port="1"/>
    </input>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="vnc" port="-1" autoport="yes">
      <listen type="address"/>
    </graphics>
    <sound model="ac97">
      <audio id="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x06" function="0x0"/>
    </sound>
    <audio id="1" type="pulseaudio"/>
    <video>
      <model type="vga" vram="65536" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0"/>
    </video>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x05" function="0x0"/>
    </memballoon>
  </devices>
  <qemu:commandline>
    <qemu:env name="XDG_RUNTIME_DIR" value="/run/user/1000"/>
  </qemu:commandline>
</domain>
```

and Here's for BlissOS Android XML file.

```xml
<domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
  <name>blissOS</name>
  <uuid>00adc3db-a1ef-4823-916b-6baa5a5e3cd4</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://android-x86.org/android-x86/9.0"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">8392704</memory>
  <currentMemory unit="KiB">8392704</currentMemory>
  <vcpu placement="static">4</vcpu>
  <os>
    <type arch="x86_64" machine="pc-i440fx-10.0">hvm</type>
    <boot dev="cdrom"/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode="host-passthrough" check="none" migratable="on"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="/home/uly/Downloads/BassOS_AIO-Android_12.1-v15.9.3-x86_64-OFFICIAL-foss-2025081414.iso"/>
      <target dev="hda" bus="ide"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <controller type="usb" index="0" model="ich9-ehci1">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x7"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci1">
      <master startport="0"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x0" multifunction="on"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci2">
      <master startport="2"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x1"/>
    </controller>
    <controller type="usb" index="0" model="ich9-uhci3">
      <master startport="4"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x2"/>
    </controller>
    <controller type="pci" index="0" model="pci-root"/>
    <controller type="ide" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x1"/>
    </controller>
    <interface type="network">
      <mac address="52:54:00:e1:1d:0f"/>
      <source network="default"/>
      <model type="e1000"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <input type="tablet" bus="usb">
      <address type="usb" bus="0" port="1"/>
    </input>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="vnc" port="-1" autoport="yes">
      <listen type="address"/>
    </graphics>
    <sound model="ac97">
      <audio id="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x06" function="0x0"/>
    </sound>
    <audio id="1" type="pulseaudio"/>
    <video>
      <model type="vga" vram="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0"/>
    </video>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x05" function="0x0"/>
    </memballoon>
  </devices>
  <qemu:commandline>
    <qemu:env name="XDG_RUNTIME_DIR" value="/run/user/1000"/>
  </qemu:commandline>
</domain>
```

You can download the BlissOS from here: https://bassos.navotpala.tech/s/77e038bd
