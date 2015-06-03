# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# Require a recent version of vagrant otherwise some have reported errors setting host names on boxes
Vagrant.require_version ">= 1.6.2"

if ARGV.first == "up" && ENV['USING_KUBE_SCRIPTS'] != 'true'
  raise Vagrant::Errors::VagrantError.new, <<END
Calling 'vagrant up' directly is not supported.  Instead, please run the following:

  export KUBERNETES_PROVIDER=vagrant
  ./cluster/kube-up.sh
END
end

# The number of minions to provision
$num_minion = (ENV['NUM_MINIONS'] || 1).to_i

# ip configuration
$master_ip = ENV['MASTER_IP']
$minion_ip_base = ENV['MINION_IP_BASE'] || ""
$minion_ips = $num_minion.times.collect { |n| $minion_ip_base + "#{n+3}" }

# Determine the OS platform to use
$kube_os = ENV['KUBERNETES_OS'] || "fedora"

# Check if we already have kube box
$kube_box_url = ENV['KUBERNETES_BOX_URL'] || "http://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_fedora-20_chef-provisionerless.box"

# OS platform to box information
$kube_box = {
  "fedora" => {
    "name" => "fedora20",
    "box_url" => $kube_box_url 
  }
}

# This stuff is cargo-culted from http://www.stefanwrobel.com/how-to-make-vagrant-performance-not-suck
# Give access to half of all cpu cores on the host. We divide by 2 as we assume
# that users are running with hyperthreads.
host = RbConfig::CONFIG['host_os']
if host =~ /darwin/
  $vm_cpus = (`sysctl -n hw.ncpu`.to_i/2.0).ceil
elsif host =~ /linux/
  $vm_cpus = (`nproc`.to_i/2.0).ceil
else # sorry Windows folks, I can't help you
  $vm_cpus = 2
end

# Give VM 1024MB of RAM by default
# In Fedora VM, tmpfs device is mapped to /tmp.  tmpfs is given 50% of RAM allocation.
# When doing Salt provisioning, we copy approximately 200MB of content in /tmp before anything else happens.
# This causes problems if anything else was in /tmp or the other directories that are bound to tmpfs device (i.e /run, etc.)
$vm_mem = (ENV['KUBERNETES_MEMORY'] || 1024).to_i

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  def customize_vm(config)
    config.vm.box = $kube_box[$kube_os]["name"]
    config.vm.box_url = $kube_box[$kube_os]["box_url"]

    config.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--memory", $vm_mem]
      v.customize ["modifyvm", :id, "--cpus", $vm_cpus]

      # Use faster paravirtualized networking
      v.customize ["modifyvm", :id, "--nictype1", "virtio"]
      v.customize ["modifyvm", :id, "--nictype2", "virtio"]
    end
  end

  # Kubernetes master
  config.vm.define "master" do |c|
    customize_vm c
    if ENV['KUBE_TEMP'] then
      script = "#{ENV['KUBE_TEMP']}/master-start.sh"
      c.vm.provision "shell", run: "always", path: script
    end
    c.vm.network "private_network", ip: "#{$master_ip}"
    c.vm.hostname = ENV['MASTER_NAME']
  end

  # Kubernetes minion
  $num_minion.times do |n|
    config.vm.define "minion-#{n+1}" do |minion|
      customize_vm minion

      minion_index = n+1
      minion_ip = $minion_ips[n]
      if ENV['KUBE_TEMP'] then
        script = "#{ENV['KUBE_TEMP']}/minion-start-#{n}.sh"
        minion.vm.provision "shell", run: "always", path: script
      end
      minion.vm.network "private_network", ip: "#{minion_ip}"
      minion.vm.hostname = "#{ENV['INSTANCE_PREFIX']}-minion-#{minion_index}"
    end
  end
end
