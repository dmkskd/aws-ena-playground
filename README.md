# Goals
- learn about the AWS ENA driver's internals
- build and install a custom ENA driver
- re-implement some basic parts in Rust

# Learning Material

## Source code location
 - [Amazon github repo](https://github.com/amzn/amzn-drivers/tree/master/kernel/linux/ena)
 - [Linux](https://github.com/torvalds/linux/tree/master/drivers/net/ethernet/amazon/ena)

## Official documentation

### Source code documentation
- [Linux kernel driver for Elastic Network Adapter (ENA) family](https://github.com/amzn/amzn-drivers/blob/master/kernel/linux/ena/README.rst)
  - The same documentation can be found in the kernel tree, e.g. [Linux kernel driver for Elastic Network Adapter (ENA) family](https://www.kernel.org/doc/html/v6.16/networking/device_drivers/ethernet/amazon/ena.html)
- [ENA Linux Driver Best Practices and Performance Optimization Guide](https://github.com/amzn/amzn-drivers/blob/master/kernel/linux/ena/ENA_Linux_Best_Practices.rst)

### AWS documentation
- [Improve network latency for Linux based EC2 instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ena-improve-network-latency-linux.html)
- [Monitor network performance for ENA settings on your EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-network-performance-ena.html)
- [Troubleshoot the ENA kernel driver on Linux](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/troubleshooting-ena.html)
  - [Available statistics through ethtool](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/troubleshooting-ena.html#statistics-ena)
- [Nitro system considerations for performance tuning](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ena-nitro-perf.html)

## Blogs
- [Deep Dive into Amazon's ena driver in the Linux Kernel](https://shungh.si/blog/deep-dive-into-amazons-ena-driver#driver-queue)
- [What I Learned From AWS ENA Driver](https://www.linkedin.com/pulse/what-i-learned-from-aws-ena-driver-zhiyi-sun)
- [Advanced Networking Performance on Amazon EC2 Linux: Achieving high throughput and low latency](https://engineering.doit.com/advanced-networking-performance-on-a-ec2-linux-achieving-high-throughput-and-low-latency-85457294f822)
- [Cloud Notes: AWS EC2](https://codingpackets.com/blog/cloud-notes-aws-ec2/)

# Compiling and loading a modified ENA driver

## Goals
We want to:
- download the ENA driver sources and compile them
- attach a second NIC to the AWS EC2 instance and load the compiled driver

## Assumptions
- Amazon Linux `6.1`
- AWS ENA driver version `2.15.0`

## Setting all up

### Create Resources

From your local machine or from Cloud Shell, execute [1_create_resources.sh](scripts/1_create_resources.sh)

This will create:

- a security group
- an EC2 instance
- a secondary AWS Network Interface, attached to the instance, where the custom ena driver will be loaded on

Please take time to review the script:

- understand the resources being created and the cost impact
- review the needed variables, as dependon on your AWS account and region
- at the end of the script, as set of values are provided for the cleanup script

### Check prerequisites

Use [2_check_nitro_prerequisites.sh](scripts/2_check_nitro_prerequisites.sh) to see if your instance is compatible with the ENA driver.

A prerequiste is to be a Nitro-powered instance.

### Compile a custom ENA driver and load it as a kernel module

Download and compile the ENA Driver with [3_compile_ena_driver.sh](scripts/3_compile_ena_driver.sh).

Take the time to look at what the script is doing.

### Mount the module on the 2nd Network Interface

Run the [5_bind_ena_custom.sh](scripts/5_bind_ena_custom.sh) to have the custom built model bound to the 2nd NIC.

### Test traffic is flowing on the 2nd NIC

Run the [5_test_ena_custom_traffic.sh](scripts/6_test_ena_custom_traffic.sh)

### Tear down resources

Use [7_delete_resources.sh](scripts/7_delete_resouces.sh) to tear down the environment

