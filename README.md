# Goals
- learn about the AWS ENA driver's internals
- build and install a custom ENA driver
- re-implement some basic parts in Rust

# Learning Material

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
- [Advanced Networking Performance on Amazon EC2 Linux: Achieving high throughput and low latency](https://engineering.doit.com/advanced-networking-performance-on-a-ec2-linux-achieving-high-throughput-and-low-latency-85457294f822)
- [Cloud Notes: AWS EC2](https://codingpackets.com/blog/cloud-notes-aws-ec2/)