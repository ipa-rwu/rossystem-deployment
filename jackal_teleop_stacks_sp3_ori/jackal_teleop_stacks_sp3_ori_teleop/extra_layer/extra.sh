apt-get install wget
wget https://packages.clearpathrobotics.com/public.key -O - | sudo apt-key add -
sh -c 'echo "deb https://packages.clearpathrobotics.com/stable/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/clearpath-latest.list'
apt-get update
wget https://raw.githubusercontent.com/ipa-rwu/public-rosdistro/rwu/fix-noetic/rosdep/50-clearpath.list -O /etc/ros/rosdep/sources.list.d/50-clearpath.list
apt-get dist-upgrade -y
