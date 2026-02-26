# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  
  # Ansible Provisioning will be run manually from WSL
  # config.vm.provision "ansible" do |ansible|
  #   ansible.playbook = "ansible/playbook.yml"
  #   ansible.inventory_path = "ansible/inventory.yml"
  #   ansible.limit = "all"
  #   ansible.verbose = "v"
  #   ansible.extra_vars = {
  #     ansible_python_interpreter: "/usr/bin/python3"
  #   }
  # end

  # ==========================================
  # Node 1: Neural Core (The Brain)
  # ==========================================
  config.vm.define "brain" do |brain|
    brain.vm.hostname = "brain-node"
    brain.vm.network "private_network", ip: "192.168.174.10"
    
    brain.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["memsize"] = "3072"
      vmware.vmx["numvcpus"] = "2"
      vmware.vmx["mainMem.useNamedFile"] = "FALSE"
      vmware.gui = false
    end
  end

  # ==========================================
  # Node 2: Workload Mesh (The Body - Worker 1)
  # ==========================================
  config.vm.define "body" do |body|
    body.vm.hostname = "body-node"
    body.vm.network "private_network", ip: "192.168.174.20"
    
    body.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["memsize"] = "1536"
      vmware.vmx["numvcpus"] = "1"
      vmware.vmx["mainMem.useNamedFile"] = "FALSE"
      vmware.gui = false
    end
  end

  # ==========================================
  # Node 2-2: Workload Mesh (The Body - Worker 2)
  # ==========================================
  config.vm.define "body2" do |body2|
    body2.vm.hostname = "body2-node"
    body2.vm.network "private_network", ip: "192.168.174.21"
    
    body2.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["memsize"] = "1536"
      vmware.vmx["numvcpus"] = "1"
      vmware.vmx["mainMem.useNamedFile"] = "FALSE"
      vmware.gui = false
    end
  end

  # ==========================================
  # Node 3: Persistence Layer (The Memory)
  # ==========================================
  config.vm.define "memory" do |memory|
    memory.vm.hostname = "memory-node"
    memory.vm.network "private_network", ip: "192.168.174.30"
    
    memory.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["memsize"] = "1536"
      vmware.vmx["numvcpus"] = "1"
      vmware.vmx["mainMem.useNamedFile"] = "FALSE"
      vmware.gui = false
    end
  end

  # ==========================================
  # Node 4: Quantum Edge (The Shield)
  # ==========================================
  config.vm.define "shield" do |shield|
    shield.vm.hostname = "shield-node"
    shield.vm.network "private_network", ip: "192.168.174.40"
    
    shield.vm.provider "vmware_desktop" do |vmware|
      vmware.vmx["memsize"] = "1024"
      vmware.vmx["numvcpus"] = "1"
      vmware.vmx["mainMem.useNamedFile"] = "FALSE"
      vmware.gui = false
    end
  end

end
