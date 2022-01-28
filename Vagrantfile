#!/usr/bin/ruby
# Below you can define specific parameters for each individual VM to be deployed by Vagrant.
# ip = assign this static IP
# box = which vagrant box should be deployed
# osd = configure an additonal virtual disk
# osdsize = size of the additional virtual disk in GB
# the remaining parameters should be pretty much self explanatory :)
# run the following to fix vagrant ssh issue
# set VAGRANT_PREFER_SYSTEM_BIN=0
# https://stackoverflow.com/questions/51437693/permission-denied-with-vagrant

nodes = [
	{ :hostname => 'seed', 		:ip => '192.168.45.210', :public_ip => '192.168.2.210', :box => 'bento/centos-stream-8', :clone_from => 'template-centos8stream', :cpus => 4, :ram => 8192, :osd => 'no', :osdsize => 200, :hv => 'no', 	:esxi => 'yes' },
	{ :hostname => 'control01', :ip => '192.168.45.211', :public_ip => '192.168.2.211', :box => 'bento/centos-stream-8', :clone_from => 'template-centos8stream', :cpus => 2, :ram => 8192, :osd => 'no', :osdsize => 200, :hv => 'no', 	:esxi => 'yes' },
	{ :hostname => 'control02', :ip => '192.168.45.212', :public_ip => '192.168.2.212', :box => 'bento/centos-stream-8', :clone_from => 'template-centos8stream', :cpus => 2, :ram => 8192, :osd => 'no', :osdsize => 200, :hv => 'no',		:esxi => 'yes' },
	{ :hostname => 'control03', :ip => '192.168.45.213', :public_ip => '192.168.2.213', :box => 'bento/centos-stream-8', :clone_from => 'template-centos8stream', :cpus => 2, :ram => 8192, :osd => 'no', :osdsize => 200, :hv => 'no', 	:esxi => 'yes' },
	{ :hostname => 'compute01', :ip => '192.168.45.214', :public_ip => '192.168.2.214', :box => 'bento/centos-stream-8', :clone_from => 'template-centos8stream', :cpus => 2, :ram => 4096, :osd => 'no', :osdsize => 200, :hv => 'yes',	:esxi => 'yes' },
	{ :hostname => 'compute02', :ip => '192.168.45.215', :public_ip => '192.168.2.215', :box => 'bento/centos-stream-8', :clone_from => 'template-centos8stream', :cpus => 2, :ram => 4096, :osd => 'no', :osdsize => 200, :hv => 'yes', 	:esxi => 'yes' },
]

varDomain = "fritz.box"
varRepository = "files"

$logger = Log4r::Logger.new('vagrantfile')
def read_ip_address(machine)

  command = "hostname -I | cut -d ' ' -f 2"
  result  = ""

  $logger.info "Processing #{ machine.name } ... "

  begin
    # sudo is needed for ifconfig
    machine.communicate.sudo(command) do |type, data|
      result << data if type == :stdout
    end
    $logger.info "Processing #{ machine.name } ... success"
  rescue
    result = "# NOT-UP"
    $logger.info "Processing #{ machine.name } ... not running"
  end
  
  result.chomp
end																					 

Vagrant.configure("2") do |config|
	config.vm.synced_folder('.', '/vagrant', type: 'nfs', disabled: true)
	config.vm.synced_folder('.', '/Vagrantfiles', type: 'rsync', disabled: false)
    nodes.each do |node|
        config.vm.define node[:hostname] do |node_config|
			memory = node[:ram] ? node[:ram] : 512;
			osddisksize = node[:osdsize] ? node[:osdsize] : 100;
			vcpus = node[:cpus] ? node[:cpus] : 1;
			vmbox = node[:clone_from] ? 'esxi_clone/dummy' : node[:box];
			#puts "Setting config.vm.box for VM #{node[:hostname]} to #{vmbox}"
			node_config.vm.box = vmbox
            #node_config.hostmanager.aliases = "#{node[:hostname]}"
			#node_config.hostmanager.aliases = "#{node[:hostname]}.#{varDomain}"
			#node_config.vm.hostname = node[:hostname]
			node_config.vm.hostname = "#{node[:hostname]}.#{varDomain}"
			node_config.vm.network "public_network", "ip": '0.0.0.0', auto_network: true			
			node_config.vm.network 'public_network', ip: node[:public_ip], netmask: '255.255.255.0'
			node_config.vm.network 'public_network', ip: node[:ip], netmask: '255.255.255.0'
			#node_config.vm.provision "shell", path: "scripts/setup_ssh_root_access.sh"
			#node_config.vm.provision "shell", path: "scripts/yum-update.sh"			
			node_config.vm.post_up_message = "This is the start up message!"
			
			if node[:esxi] == "yes"
				node_config.vm.provider :vmware_esxi do |esxi|
					esxi.esxi_hostname = '192.168.2.10'
					esxi.esxi_username = 'root'
					esxi.esxi_password = 'file:'
					esxi.clone_from_vm = node[:clone_from]
					esxi.esxi_resource_pool = "/"
					esxi.esxi_disk_store = 'truenas_nvme_01'
					esxi.esxi_virtual_network = ['VM Network','VM Network','VM Network']
					esxi.guest_memsize = memory.to_s
					esxi.guest_numvcpus = vcpus.to_s
					esxi.local_allow_overwrite = 'True'
					esxi.guest_nic_type = 'vmxnet3'
					#esxi.local_use_ip_cache = 'False'
					esxi.debug = 'true'
					if node[:hv] == "yes"
						esxi.guest_custom_vmx_settings = [['vhv.enable','TRUE']]
					end #if node[:hv] == "yes"
				end #node_config.vm.provider :vmware_esxi do |esxi|
			end #if node[:esxi] == "yes"
			if node[:esxi] == "no"
				node_config.vm.provider :virtualbox do |v|					
					v.customize ["modifyvm", :id, "--memory", memory.to_s]
					v.customize ["modifyvm", :id, "--cpus", vcpus.to_s]
					if node[:osd] == "yes"
						v.customize [ "createhd", "--filename", "disk_osd-#{node[:hostname]}", "--size", "10000" ]
						v.customize [ "storageattach", :id, "--storagectl", "SATA Controller", "--port", 3, "--device", 0, "--type", "hdd", "--medium", "disk_osd-#{node[:hostname]}.vdi" ]
					end #if node[:osd] == "yes"
					if node[:hv] == "yes"         
						v.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
					end #if node[:hv] == "yes"					
				end #node_config.vm.provider :virtualbox do |v|
			end #if node[:esxi] == "no"
		end #config.vm.define node[:hostname] do |node_config|
		config.hostmanager.enabled = true
		config.hostmanager.manage_host = false
		config.hostmanager.manage_guest = true
		#config.hostmanager.ignore_private_ip = false
		#config.hostmanager.include_offline = true
		if Vagrant.has_plugin?("HostManager")
			config.hostmanager.ip_resolver = proc do |vm, resolving_vm|
				read_ip_address(vm)
			end
		end
	end #nodes.each do |node|
end #Vagrant.configure("2") do |config|