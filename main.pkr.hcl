variable "os_version" {
  type = string
  description = "The version of the operating system to download and install"
}

variable "architecture" {
  type = object({
    name = string
    image = string
    qemu = string
  })
  description = "The type of CPU to use when building"
}

variable "machine_type" {
  default = "q35"
  type = string
  description = "The type of machine to use when building"
}

variable "cpu_type" {
  default = "max"
  type = string
  description = "The type of CPU to use when building"
}

variable "memory" {
  default = 8192
  type = number
  description = "The amount of memory to use when building the VM in megabytes"
}

variable "cpus" {
  default = 4
  type = number
  description = "The number of cpus to use when building the VM"
}

variable "disk_size" {
  default = "12G"
  type = string
  description = "The size in bytes of the hard disk of the VM"
}

variable "checksum" {
  type = string
  description = "The checksum for the virtual hard drive file"
}

variable "root_password" {
  default = "vagrant"
  type = string
  description = "The password for the root user"
}

variable "secondary_user_username" {
  default = "vagrant"
  type = string
  description = "The name for the secondary user"
}

variable "secondary_user_password" {
  default = "vagrant"
  type = string
  description = "The password for the `secondary_user_username` user"
}

variable "headless" {
  default = false
  description = "When this value is set to `true`, the machine will start without a console"
}

variable "use_default_display" {
  default = true
  type = bool
  description = "If true, do not pass a -display option to qemu, allowing it to choose the default"
}

variable "display" {
  default = "cocoa"
  description = "What QEMU -display option to use"
}

locals {
  iso_target_extension = "iso"
  iso_target_path = "packer_cache"
  iso_full_target_path = "${local.iso_target_path}/${sha1(var.checksum)}.${local.iso_target_extension}"

  vm_name = "omnios-${var.os_version}-${var.architecture.name}.qcow2"
  iso_path = "${var.os_version}/omnios-${var.os_version}.iso"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus = var.cpus
  memory = var.memory
  net_device = "virtio-net"
  vnc_bind_address = "0.0.0.0"
  vnc_port_min = 5900
  vnc_port_max = 5900

  disk_compression = true
  disk_interface = "virtio"
  disk_size = var.disk_size
  format = "qcow2"

  headless = var.headless
  use_default_display = var.use_default_display
  display = var.display
  accelerator = "none"
  qemu_binary = "qemu-system-${var.architecture.qemu}"
  cpu_model = var.cpu_type

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout = "10000s"

  qemuargs = [
    ["-boot", "strict=off"],
    ["-monitor", "none"],
    ["-accel", "hvf"],
    ["-accel", "kvm"],
    ["-accel", "tcg"],

    ["-device", "virtio-blk,drive=drive0,bootindex=0"],
    ["-device", "ide-cd,drive=drive1,bootindex=1"],
    ["-drive", "if=none,file={{ .OutputDir }}/{{ .Name }},id=drive0,cache=writeback,discard=ignore,format=qcow2"],
    ["-drive", "if=none,file=${local.iso_full_target_path},id=drive1,media=disk,format=raw,readonly=on"]
  ]

  iso_checksum = var.checksum
  iso_target_extension = local.iso_target_extension
  iso_target_path = local.iso_target_path
  iso_urls = [
    "https://downloads.omnios.org/media/${local.iso_path}",
    "https://us-west.mirror.omnios.org/downloads/media/${local.iso_path}"
  ]

  http_directory = "."
  output_directory = "output"
  shutdown_command = "shutdown -i5 -g0 -y"
  vm_name = local.vm_name

  boot_wait = "3s"

  boot_steps = [
    ["1<wait2m>", "Boot Multi User"],
    ["<enter><wait5s>", "Please select a keyboard layout"],
    ["f<wait><enter><wait10s>", "Find disks, create rpool and install OmniOS"],
    ["<spacebar><enter><wait5s>", "Select disks for installation"],
    ["<enter><wait20s>", "ZFS Root Pool Configuration"],
    ["<bs><bs><bs><bs><bs><bs>runnervmg1sw1<enter><wait10s>", "Enter the system hostname"],
    ["<enter><wait>", "Please identify a location so that time zone rules can be set correctly"],
    ["y<wait6m>", "The following information has been given"],

    // Installation Complete
    ["<enter><wait>", "OK"],

    // Welcome to the OmniOS installer
    ["s<wait><enter><wait5s>", "Shell"],

    // shell
    // configure network
    ["ipadm create-if vioif0<enter><wait>"],
    ["ipadm create-addr -T static -a 10.0.2.15/24 vioif0/v4static<enter><wait>"],
    // ["ipadm create-addr -T dhcp vioif0/v4<enter><wait15>"],

    // run post install script
    ["curl -o /tmp/post_install.sh 'http://{{.HTTPIP}}:{{.HTTPPort}}/resources/post_install.sh'<enter><wait10>"],
    ["sh /tmp/post_install.sh && exit<enter><wait5>"],

    // Welcome to the OmniOS installer
    ["c<wait><enter><wait5s>", "Configure the installed OmniOS sytem"],

    // OmniOS configuration menu
    ["c<wait><enter><wait5s>", "Configure Networking"],

    // OmniOS network configuration menu
    ["c", "Configuration Mode"],
    ["<spacebar>", "DHCP"],
    ["<enter><wait5s>", "Return to main configuration menu"],

    // OmniOS configuration menu
    ["c<wait>c<wait><enter><wait5s>", "Create User"],

    // Creating user
    ["${var.secondary_user_username}<down><wait>", "Username"],
    ["${var.secondary_user_password}<down><wait>", "Password"],
    ["${var.secondary_user_password}<enter><wait>", "Re-type Password"],

    // Select shell
    ["<enter><wait>", "OK (Ksh93 Korn Shell)"],

    // Select user privileges
    ["<down><spacebar>", "Grant 'sudo' access"],
    ["<enter><wait>", "OK"],

    // User <user> created successfully
    ["<enter><wait5s>", "OK"],

    // OmniOS configuration menu
    ["s<wait>", "Set Root Password"],
    ["<enter>", "OK"],

    // Setting root password
    ["${var.root_password}<down>", "Password"],
    ["${var.root_password}", "Retype Password"],
    ["<enter><wait5s>", "OK"],

    // The root password has been set
    ["<enter><wait5s>", "OK"],

    // OmniOS configuration menu
    ["s<wait>s<wait><enter><wait5s>", "SSH Server"],
    ["s<wait>s<wait>s<wait><enter><wait5s>", "Serial Console"],

    // OmniOS serial console configuration menu
    ["s<wait><enter><wait5s>", "Serial Console -> ttya"],
    ["r<wait><enter><wait5s>", "Return to main configuration menu"],

    // OmniOS configuration menu
    ["r<wait><enter><wait5s>", "Return to main menu"],

    // Welcome to the OmniOS installer
    ["r<wait><enter>", "Reboot"],
  ]
}

packer {
  required_plugins {
    qemu = {
      version = "~> 1.1.3"
      source = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["qemu.qemu"]

  provisioner "shell" {
    script = "resources/provision.sh"
  }

  provisioner "shell" {
    script = "resources/custom.sh"
  }

  provisioner "shell" {
    script = "resources/cleanup.sh"
  }
}
