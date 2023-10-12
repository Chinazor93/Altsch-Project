 #  !/bin/bash

if [[ "$PWD" == "/c/Users/CHINAZOR/Desktop/Vagrant/Project" ]]; then
  vagrant init ubuntu/focal64
else
  mkdir -p "/c/Users/CHINAZOR/Desktop/Vagrant/Project"
  cd "/c/Users/CHINAZOR/Desktop/Vagrant/Project"
  vagrant init ubuntu/focal64
fi

 
#Creating master machine, slave machine and also setting disk usage

cat <<EOF > Vagrantfile
Vagrant.configure("2") do |config|

  config.vm.define "slave" do |slave|

    slave.vm.hostname = "slave-1"
    slave.vm.box = "ubuntu/focal64"
    slave.vm.network "private_network", ip: "192.168.20.15"

    slave.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install sshpass -y
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    sudo apt-get install -y avahi-daemon libnss-mdns
    SHELL
  end

  config.vm.define "master" do |master|

    master.vm.hostname = "master"
    master.vm.box = "ubuntu/focal64"
    master.vm.network "private_network", ip: "192.168.20.14"

    master.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y avahi-daemon libnss-mdns
    sudo apt install sshpass -y
    SHELL
  end

    config.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = "2"
    end
end
EOF

vagrant up

#This stops the code if there's any error
set -e

#creating a user "altshool" and granting altschool root priviledges
#Enabling SSH key-based authentication (altschool user can SSH into the slave node without password)
#copying the contents of /mnt/altschool directory from the master node to the slave node

vagrant ssh master <<EOF

    sudo useradd -m -G sudo altschool
    echo -e "dike\ndike\n" | sudo passwd altschool 
    sudo usermod -aG root altschool
    sudo useradd -ou 0 -g 0 altschool
    sudo -u altschool ssh-keygen -t rsa -b 4096 -f /home/altschool/.ssh/id_rsa -N "" -y
    sudo cp /home/altschool/.ssh/id_rsa.pub altschoolkey
    sudo ssh-keygen -t rsa -b 4096 -f /home/vagrant/.ssh/id_rsa -N ""
    sudo cat /home/vagrant/.ssh/id_rsa.pub | sshpass -p "vagrant" ssh -o StrictHostKeyChecking=no vagrant@192.168.20.15 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    sudo cat ~/altschoolkey | sshpass -p "vagrant" ssh vagrant@192.168.20.15 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    sshpass -p "dike" sudo -u altschool mkdir -p /mnt/altschool/slave
    sshpass -p "dike" sudo -u altschool scp -r /mnt/* vagrant@192.168.20.15:/home/vagrant/mnt
    sudo ps aux > /home/vagrant/running_processes
    exit
EOF


#LAMP stack deployment on the master machine
vagrant ssh master <<EOF


echo -e "\n\nUpdating Apt Packages and upgrading latest patches\n"
sudo apt update -y

sudo apt install apache2 -y

echo -e "\n\nAdding firewall rule to Apache\n"
sudo ufw allow in "Apache"

sudo ufw status

echo -e "\n\nInstalling MySQL\n"
sudo apt install mysql-server -y

echo -e "\n\nPermissions for /var/www\n"
sudo chown -R www-data:www-data /var/www
echo -e "\n\n Permissions have been set\n"

sudo apt install php libapache2-mod-php php-mysql -y

echo -e "\n\nEnabling Modules\n"
sudo a2enmod rewrite
sudo phpenmod mcrypt

sudo sed -i 's/DirectoryIndex index.html index.cgi index.pl index.xhtml index.htm/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf

echo -e "\n\nRestarting Apache\n"
sudo systemctl reload apache2

echo -e "\n\nLAMP Installation Completed"

exit 0

EOF

#LAMP stack deployment on the slave machine
vagrant ssh slave <<EOF


echo -e "\n\nUpdating Apt Packages and upgrading latest patches\n"
sudo apt update -y

sudo apt install apache2 -y

echo -e "\n\nAdding firewall rule to Apache\n"
sudo ufw allow in "Apache"

sudo ufw status

echo -e "\n\nInstalling MySQL\n"
sudo apt install mysql-server -y

echo -e "\n\nPermissions for /var/www\n"
sudo chown -R www-data:www-data /var/www
echo -e "\n\n Permissions have been set\n"

sudo apt install php libapache2-mod-php php-mysql -y

echo -e "\n\nEnabling Modules\n"
sudo a2enmod rewrite
sudo phpenmod mcrypt

sudo sed -i 's/DirectoryIndex index.html index.cgi index.pl index.xhtml index.htm/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf

echo -e "\n\nRestarting Apache\n"
sudo systemctl reload apache2

echo -e "\n\nLAMP Installation Completed"

exit 0

EOF

