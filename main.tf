
# ============================================================
# 1. AWS PROVIDER
# ============================================================
# The provider tells Terraform which cloud platform we want
# to work with and which AWS region to use.
#
# us-east-1 = Northern Virginia.
# All the AWS resources below will be created in this region
# unless another region is specifically configured.
provider "aws" {
  region = "us-east-1"
}


# ============================================================
# 2. VPC - VIRTUAL PRIVATE CLOUD
# ============================================================
# A VPC is our own private network inside AWS.
#
# Think of the VPC as the main network/container where our
# subnet, security group, route table and EC2 instances live.
#
# 10.0.0.0/16 gives us a large private IP address range:
# 10.0.0.0 - 10.0.255.255
#
# Our subnet below will take a smaller section of this range.
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}


# ============================================================
# 3. SECURITY GROUP
# ============================================================
# A Security Group acts like a virtual firewall.
#
# It controls what network traffic is allowed INTO and OUT OF
# resources such as our EC2 instances.
#
# Because we specify:
#
#   vpc_id = aws_vpc.my_vpc.id
#
# Terraform knows this Security Group belongs to the VPC
# created above.
resource "aws_security_group" "my_sg" {

  name        = "my-security-group"
  description = "Security group for my EC2 instance"

  # Attach this Security Group to our VPC.
  vpc_id = aws_vpc.my_vpc.id


  # ----------------------------------------------------------
  # INBOUND / INGRESS RULE
  # ----------------------------------------------------------
  # Ingress means traffic coming INTO the EC2 instance.
  #
  # Port 22 is used for SSH.
  # SSH allows us to remotely connect to a Linux EC2 instance.
  #
  # from_port = 22 and to_port = 22 means ONLY port 22.
  #
  # protocol = "tcp" because SSH uses TCP.
  #
  # WARNING:
  # 0.0.0.0/0 means ANY IPv4 address on the internet can
  # attempt to connect to port 22.
  #
  # This is convenient for a temporary learning lab but is
  # not a good security setting for a real environment.
  #
  # A safer option would be your own public IP:
  #
  # cidr_blocks = ["YOUR_PUBLIC_IP/32"]
  #
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # ----------------------------------------------------------
  # OUTBOUND / EGRESS RULE
  # ----------------------------------------------------------
  # Egress means traffic leaving the EC2 instance.
  #
  # protocol = "-1" means ALL protocols.
  #
  # 0.0.0.0/0 means the EC2 instance is allowed to send
  # traffic to any IPv4 address.
  #
  # This allows things such as downloading software updates
  # or contacting services on the internet.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ============================================================
# 4. SUBNET
# ============================================================
# A subnet is a smaller network inside our VPC.
#
# Our VPC uses:
#
#     10.0.0.0/16
#
# This subnet uses:
#
#     10.0.1.0/24
#
# So the subnet takes a smaller range from the VPC's
# overall address space.
#
# map_public_ip_on_launch = true tells AWS to automatically
# assign a public IPv4 address to instances launched into
# this subnet (where the instance/network settings allow it).
#
# Together with the Internet Gateway and route table below,
# this is being configured as a PUBLIC subnet.
resource "aws_subnet" "my_subnet" {

  # Create the subnet inside our VPC.
  vpc_id = aws_vpc.my_vpc.id

  # Private IP address range for this subnet.
  cidr_block = "10.0.1.0/24"

  # Automatically request a public IPv4 address for instances.
  map_public_ip_on_launch = true
}


# ============================================================
# 5. INTERNET GATEWAY
# ============================================================
# An Internet Gateway (IGW) connects the VPC to the internet.
#
# Simply creating an Internet Gateway is NOT enough.
#
# We also need a route in a Route Table telling AWS:
#
# "Send internet-bound traffic to this Internet Gateway."
#
# That route is created in the next section.
resource "aws_internet_gateway" "my_igw" {

  # Attach the Internet Gateway to our VPC.
  vpc_id = aws_vpc.my_vpc.id
}


# ============================================================
# 6. ROUTE TABLE
# ============================================================
# A Route Table contains rules that tell AWS where network
# traffic should go.
#
# Think of it like a road-sign system for network traffic.
resource "aws_route_table" "my_route_table" {

  # This Route Table belongs to our VPC.
  vpc_id = aws_vpc.my_vpc.id


  # ----------------------------------------------------------
  # INTERNET ROUTE
  # ----------------------------------------------------------
  # 0.0.0.0/0 means:
  #
  # "Any IPv4 destination that isn't matched by a more
  # specific route."
  #
  # gateway_id tells AWS to send that traffic through our
  # Internet Gateway.
  #
  # In simple terms:
  #
  # Internet-bound traffic ---> Internet Gateway
  #
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}


# ============================================================
# 7. ROUTE TABLE ASSOCIATION
# ============================================================
# Creating a Route Table doesn't automatically make our
# subnet use it.
#
# We must associate the Route Table with the subnet.
#
# This connects:
#
#     SUBNET ---> ROUTE TABLE
#
# Because the Route Table has a route to the Internet Gateway,
# this subnet has a route to the internet.
resource "aws_route_table_association" "my_route_table_assoc" {

  # The subnet that should use the Route Table.
  subnet_id = aws_subnet.my_subnet.id

  # The Route Table the subnet should use.
  route_table_id = aws_route_table.my_route_table.id
}


# ============================================================
# 8. EC2 INSTANCE
# ============================================================
# Finally, we create our virtual servers.
#
# The EC2 instances will:
#
# 1. Be created inside our subnet.
# 2. Use our Security Group.
# 3. Receive public IP addresses because the subnet has
#    map_public_ip_on_launch = true.
# 4. Reach the internet through the subnet's Route Table
#    and Internet Gateway.
resource "aws_instance" "my_ec2" {

  # count tells Terraform how many identical EC2 resources
  # to create.
  #
  # count = 3 means Terraform will create THREE EC2 instances:
  #
  # aws_instance.my_ec2[0]
  # aws_instance.my_ec2[1]
  # aws_instance.my_ec2[2]



  # AMI = Amazon Machine Image.
  #
  # The AMI determines the operating system/template used
  # to create the EC2 instance.
  #
  # AMI IDs are region-specific, so this AMI must exist
  # in us-east-1.
  ami = "ami-0d97d7f07b25dd693"


  # Defines the amount/type of virtual CPU and memory.
  instance_type = "t2.micro"


  # The AWS EC2 Key Pair used for SSH authentication.
  #
  # This key pair must already exist in AWS in us-east-1.
  key_name = "terra_ec2_key"


  # Attach our Security Group to the EC2 instances.
  #
  # This controls the allowed inbound and outbound traffic.
  vpc_security_group_ids = [aws_security_group.my_sg.id]


  # Place the EC2 instances inside our subnet.
  subnet_id = aws_subnet.my_subnet.id
user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update system packages
              sudo apt-get update -y
              sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

              # --- INSTALL DOCKER ---
              sudo mkdir -p /etc/at/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io
              sudo systemctl enable docker
              sudo systemctl start docker

              # Add default ubuntu user to docker group
              sudo usermod -aG docker ubuntu

              # --- PULL AND RUN DOCKER CONTAINER ---
              # Replace 'nginx:latest' with your target Docker image (e.g., username/repository:tag)
              
              sudo docker pull akebire/websiteproject
              
              sudo docker run -d --name my_app --restart always -p 80:80 akebire/websiteproject
              EOF

  # Tags help identify and organise AWS resources.
  #
  # NOTE:
  # Because count = 3, all three instances currently receive
  # the SAME Name tag.
  tags = {
    Name = "terraform-ec2-instance"
  }
}
# Step 1 
