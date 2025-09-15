#!/bin/bash

### Prepare the Environment
# Install development tools
sudo yum groupinstall "Development Tools" -y  # RHEL/Amazon Linux

# Install kernel headers
sudo yum install kernel-devel-$(uname -r) -y  # RHEL/Amazon Linux

DRIVER_VERSION="2.15.0"
echo "Download ena driver source ${DRIVER_VERSION}"
wget https://github.com/amzn/amzn-drivers/archive/ena_linux_${DRIVER_VERSION}.tar.gz
tar -xzf ena_linux_${DRIVER_VERSION}.tar.gz
cd amzn-drivers-ena_linux_${DRIVER_VERSION}/kernel/linux/ena/

echo "### Compile and install the driver"
echo "We need to change the compiled module name to so"

echo "1. Modify Makefile: change DRIVER_NAME from ena to ena_custom"
sed -i 's/DRIVER_NAME := ena/DRIVER_NAME := ena_custom/' Makefile

echo "2. Modify ena_netdev.h: change DRV_MODULE_NAME from 'ena' to 'ena_custom'"
sed -i 's/"ena"/"ena_custom"/' ena_netdev.h

echo "3. Compile the driver"
make

echo "4. Install modified driver"
MODULES_PATH=/usr/lib/modules/$(uname -r)/kernel/drivers/amazon/net
ENA_CUSTOM_MODULE_PATH=$MODULES_PATH/ena_custom
sudo mkdir -p $ENA_CUSTOM_MODULE_PATH

echo "5. Copying the driver into $ENA_CUSTOM_MODULE_PATH"
sudo cp ena_custom.ko $ENA_CUSTOM_MODULE_PATH

echo "6. Loading the new module with 'depmod -a'"
sudo depmod -a

echo "7. Validate it has been loaded correctly"
modinfo --filename ena_custom
