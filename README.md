# 🥧 AWS Certification Lab - Raspberry Pi Edition

> **AWS certification preparation from your Raspberry Pi!**

This repository contains a complete AWS certification lab environment managed from a Raspberry Pi, demonstrating:

- Infrastructure as Code with Terraform on ARM
- AWS CLI operations from edge devices  
- Portable DevOps workflows
- Cost-efficient cloud management

## Pi Specifications
- **Model**: Detected automatically during setup
- **Architecture**: ARM64/ARM32 compatible
- **Memory**: Optimized for 2GB+ systems
- **Storage**: Minimal footprint design

## Quick Start on Pi

```bash
# 1. Run the Pi setup (if not done already)
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/aws-certification-lab/main/scripts/pi-setup.sh | bash

# 2. Configure AWS credentials
aws configure

# 3. Deploy infrastructure
cd terraform
./scripts/setup.sh
```

## Pi-Specific Optimizations

- ✅ ARM-native tool installations
- ✅ Memory usage optimization
- ✅ Swap configuration for constrained systems
- ✅ GPU memory reallocation
- ✅ Efficient caching strategies

## Performance Notes

- **Terraform operations**: 2-3x slower than x86, but fully functional
- **AWS API calls**: No performance difference
- **Git operations**: Optimized for Pi storage
- **Monitoring**: Lightweight tools included

## Power Consumption

Typical power usage during operations:
- **Idle**: ~2-3W
- **Terraform planning**: ~4-5W  
- **AWS operations**: ~3-4W
- **24/7 monitoring**: ~2W average

Perfect for always-on infrastructure management!
