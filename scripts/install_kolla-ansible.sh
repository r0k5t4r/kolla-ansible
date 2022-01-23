# the deployment variable can be either $deployment or all-in-one, by default it is $deployment
cd
deployment="multinode"
sudo dnf install -y python3-devel libffi-devel gcc openssl-devel python3-libselinux
sudo dnf install -y python3-pip
sudo dnf install -y sshpass
sudo pip3 install -U pip
sudo yum -y install epel-release
# Install Ansible. Kolla Ansible requires at least Ansible 2.10 and supports up to 4.
sudo pip3 install -U 'ansible<3.0'
sudo pip3 install --ignore-installed PyYAML kolla-ansible
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp -r /usr/local/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp /usr/local/share/kolla-ansible/ansible/inventory/* ~
#sudo sed -i '/^\[defaults\]/a host_key_checking=False\npipelining=True\nforks=100\ntimeout=40' /etc/ansible/ansible.cfg
# ansible cfg has to be created from scratch when using pip!!!#
cat > ~/ansible.cfg << EOF
[defaults]
host_key_checking=False
pipelining=True
forks=100
timeout=40
EOF

sed -i 's/^#kolla_base_distro:.*/kolla_base_distro: "centos"/g' /etc/kolla/globals.yml
sed -i 's/^#kolla_install_type:.*/kolla_install_type: "source"/g' /etc/kolla/globals.yml
sed -i 's/^#kolla_internal_vip_address:.*/kolla_internal_vip_address: "192.168.2.222"/g' /etc/kolla/globals.yml
sed -i 's/^#network_interface:.*/network_interface: "eth2"/g' /etc/kolla/globals.yml
sed -i 's/^#neutron_external_interface:.*/neutron_external_interface: "eth1"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_haproxy:.*/enable_haproxy: "yes"/g' /etc/kolla/globals.yml
sed -i 's/^#openstack_release:.*/openstack_release: "wallaby"/g' /etc/kolla/globals.yml

grep ^[^#] /etc/kolla/globals.yml

curl -sSL https://get.docker.io | sudo bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker
sudo pip3 install docker
sudo mkdir -p /var/lib/registry
sudo docker run -d \
 --name registry \
 --restart=always \
 -p 4000:5000 \
 -v registry:/var/lib/registry \
 registry:2
kolla-ansible -i all-in-one pull

# push all image to local registry, e.g.:
#     docker tag kolla/centos-binary-heat-api:3.0.1 \
#         localhost:4000/kolla/centos-binary-heat-api:3.0.1
#     docker push localhost:4000/kolla/centos-binary-heat-api:3.0.1

#cat <<EOT > push_docker_img.sh
cat > ~/push_docker_img.sh << EOF
docker images | grep kolla | grep -v local | awk '{print \$1,\$2}' | while read -r image tag; do 
        newimg=\`echo \${image} | cut -d / -f2-\`
        docker tag \${image}:\${tag} localhost:4000/\${newimg}:\${tag}
        docker push localhost:4000/\${newimg}:\${tag}
done
EOF
sudo sh push_docker_img.sh

#sed -i 's/^#docker_registry:.*/docker_registry: 192.168.2.210:4000\/quay.io/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry:.*/docker_registry: 192.168.2.210:4000/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry_insecure:.*/docker_registry_insecure: yes/g' /etc/kolla/globals.yml

cp /Vagrantfiles/scripts/$deployment ~

ansible -i $deployment compute,control -m shell -a "yum -y update" -b
ansible -i $deployment compute,control --forks 1 -m reboot
ansible -i $deployment all -m shell -a "systemctl enable chronyd; systemctl restart chronyd" -b
kolla-genpwd

time kolla-ansible -i ./$deployment bootstrap-servers
time kolla-ansible -i ./$deployment prechecks
time kolla-ansible -i ./$deployment deploy

pip install python-openstackclient
time kolla-ansible post-deploy