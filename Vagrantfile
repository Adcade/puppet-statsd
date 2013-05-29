# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box     = 'precise64'
  config.vm.box_url = 'http://files.vagrantup.com/precise64.box'

  config.vm.network   :forwarded_port, guest:80,   host:18080
  config.vm.network   :forwarded_port, guest:8125, host:8125, protocol:"udp"
  config.vm.provision :puppet do |puppet|
     puppet.module_path    = ".."
     puppet.manifests_path = "tests"
     puppet.manifest_file  = "init.pp"
  end
end
