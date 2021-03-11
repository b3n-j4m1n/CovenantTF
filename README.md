# CovenantTF

This will build in AWS a Covenant C2 + HTTP redirector routing traffic on port 80

## Installation

```bash
git clone https://github.com/b3n-j4m1n/CovenantTF.git
```

_terraform.tfvars_ needs to be edited with your AWS details and IP whitelist if required.

```bash
# --- providers ---
aws_access_key = "AKIAXXXXXXXXXXXXXXXX"
aws_secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
aws_region     = "ap-southeast-2"

# --- whitelist ---
ip_whitelist  = [
  "0.0.0.0/0"
]
```

Download Terraform to the CovenantTF directory - https://www.terraform.io/downloads.html

```bash
./terraform init
./terraform apply
```

## Resources
https://github.com/cobbr/Covenant/wiki
