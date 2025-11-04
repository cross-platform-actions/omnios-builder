#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'expect'

# Path to the QEMU binary
QEMU_BINARY = '/opt/homebrew/bin/qemu-system-x86_64'

# Updated QEMU options based on packer.sh
QEMU_OPTIONS = [
  '-nographic', # Disable graphical output, use serial console
  '-serial', 'stdio', # Redirect serial port to standard input/output
  '-drive',
  'if=none,file=output/omnios-r151056-x86-64.qcow2,id=drive0,cache=writeback,discard=ignore,format=qcow2', # Primary drive
  '-drive',
  'if=none,file=packer_cache/6eb4fe732afd393754f2e072fd4ea4137e8898e5.iso,id=drive1,media=disk,format=raw,readonly=on', # Secondary drive
  '-device', 'virtio-blk,drive=drive0,bootindex=0', # Virtio block device for primary drive
  '-device', 'ide-cd,drive=drive1,bootindex=1', # IDE CD-ROM device for secondary drive
  '-vnc', '127.0.0.1:38', # VNC server
  '-name', 'omnios-r151056-x86-64.qcow2', # VM name
  '-machine', 'type=q35', # Machine type
  '-boot', 'strict=off', # Boot options
  '-device', 'virtio-net,netdev=user.0', # Virtio network device
  '-netdev', 'user,id=user.0,hostfwd=tcp::3969-:22', # User-mode networking with port forwarding
  '-smp', '4', # Number of CPU cores
  '-m', '8192M', # Memory size
  '-cpu', 'max', # Maximum CPU features
  '-monitor', 'none', # Disable QEMU monitor
  '-accel', 'hvf', # Hardware virtualization framework
  '-accel', 'kvm', # Kernel-based virtualization
  '-accel', 'tcg' # Tiny Code Generator (fallback)
].freeze

# Launch QEMU
Open3.popen2e(QEMU_BINARY, *QEMU_OPTIONS) do |stdin, stdout_and_stderr, wait_thr|
  # Use the built-in Expect library to monitor the output
  stdout_and_stderr.sync = true

  # Debugging log to confirm output redirection
  puts 'Starting to read QEMU output...'

  # Regular expression to match and remove ANSI escape sequences
  ansi_escape = /\e\[[\d;]*[a-zA-Z]/

  # Thread to redirect QEMU output to the terminal
  Thread.new do
    stdout_and_stderr.each do |line|
      # Strip ANSI escape sequences
      clean_line = line.gsub(ansi_escape, '')
      puts "QEMU: #{clean_line}"
    end
  end

  stdout_and_stderr.expect(/Please select a keyboard layout/) do |match|
    puts "Detected prompt: #{match}" # Log the detected prompt

    # Send the Enter key to the VM
    stdin.puts "\n"
    puts 'Sent Enter key to the VM'
  end

  # Wait for the QEMU process to exit
  wait_thr.join
rescue Errno::EPIPE
  puts 'Error: Broken pipe. The QEMU process may have terminated unexpectedly.'
rescue StandardError => e
  puts "An unexpected error occurred: #{e.message}"
ensure
  stdin.close unless stdin.closed?
  stdout_and_stderr.close unless stdout_and_stderr.closed?
end
