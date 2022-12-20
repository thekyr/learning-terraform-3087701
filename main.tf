data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true


  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  subnet_id              = module.blog_vpc.public_subnets[0]
  vpc_security_group_ids = [module.blog_sg.security_group_id]

  tags = {
    Name = "Learning Terraform"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "blog-alb"

  load_balancer_type = "application"

  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = module.blog_sg.security_group_id

  access_logs = {
    bucket = "my-alb-logs"
  }

  target_groups = [
    {
      name_prefix      = "blog-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = {
        my_target = {
          target_id = aws_instance.blog.id
          port = 80
        }
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}
HTTP to HTTPS redirect and HTTPS cognito authentication:

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id             = "vpc-abcde012"
  subnets            = ["subnet-abcde012", "subnet-bcde012a"]
  security_groups    = ["sg-edcd9784", "sg-edcd9785"]

  access_logs = {
    bucket = "my-alb-logs"
  }

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "instance"
    }
  ]

  https_listeners = [
    {
      port                 = 443
      protocol             = "HTTPS"
      certificate_arn      = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
      action_type          = "authenticate-cognito"
      target_group_index   = 0
      authenticate_cognito = {
        user_pool_arn       = "arn:aws:cognito-idp::123456789012:userpool/test-pool"
        user_pool_client_id = "6oRmFiS0JHk="
        user_pool_domain    = "test-domain-com"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  tags = {
    Environment = "Test"
  }
}
    
    
module "blog_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "blog"
  description = "Security group for web-server with HTTP ports open within VPC"
  vpc_id      = module.blog_vpc.vpc_id

  ingress_rules = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks  = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}
