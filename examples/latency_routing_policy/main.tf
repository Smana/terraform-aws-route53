provider "aws" {
  region = "eu-west-1"
}

module "zones" {
  source = "../../modules/zones"

  zones = {
    "terraform-aws-modules-example.com" = {
      comment = "terraform-aws-modules-example.com (production)"
      tags = {
        Name = "terraform-aws-modules-example.com"
      }
    }

    "app.terraform-aws-modules-example.com" = {
      comment = "app.terraform-aws-modules-example.com"
      tags = {
        Name = "app.terraform-aws-modules-example.com"
      }
    }

    "private-vpc.terraform-aws-modules-example.com" = {
      comment = "private-vpc.terraform-aws-modules-example.com"
      vpc = [
        {
          vpc_id = module.vpc_use1.vpc_id
        },
        {
          vpc_id = module.vpc_euw1.vpc_id
        },
        {
          vpc_id = module.vpc_ape1.vpc_id
        },
      ]
      tags = {
        Name = "private-vpc.terraform-aws-modules-example.com"
      }
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

module "records" {
  source = "../../modules/records"

  zone_name = keys(module.zones.route53_zone_zone_id)[0]

  records = [
    {
      name = "api-gw"
      type = "A"
      alias = {
        name    = module.api_gateway_use1.apigatewayv2_domain_name_configuration[0].target_domain_name
        zone_id = module.api_gateway_use1.apigatewayv2_domain_name_configuration[0].hosted_zone_id
        evaluate_target_health = false
      }

      set_identifier = "api-gw-use1"

      latency_routing_policy = {
        region = "us-east-1"
      }
    },
    {
      name = "api-gw"
      type = "A"
      alias = {
        name    = module.api_gateway_euw1.apigatewayv2_domain_name_configuration[0].target_domain_name
        zone_id = module.api_gateway_euw1.apigatewayv2_domain_name_configuration[0].hosted_zone_id
        evaluate_target_health = false
      }

      set_identifier = "api-gw-euw1"

      latency_routing_policy = {
        region = "eu-west-1"
      }
    },
    {
      name = "api-gw"
      type = "A"
      alias = {
        name    = module.api_gateway_ape1.apigatewayv2_domain_name_configuration[0].target_domain_name
        zone_id = module.api_gateway_ape1.apigatewayv2_domain_name_configuration[0].hosted_zone_id
        evaluate_target_health = false
      }

      set_identifier = "api-gw-ape1"

      latency_routing_policy = {
        region = "ap-east-1"
      }
    },
  ]
}

#########
# Extras - should be created in advance
#########

resource "random_pet" "this" {
  length = 2
}

module "api_gateway_use1" {
    source  = "terraform-aws-modules/apigateway-v2/aws"
    version = "1.0.0"

    name        = "${random_pet.this.id}-http"
    domain_name = keys(module.zones.route53_zone_zone_id)[0]

    providers = {
        aws = aws.use1
    }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.0"

  domain_name               = keys(module.zones.route53_zone_name)[0]
  zone_id                   = keys(module.zones.route53_zone_zone_id)[0]
  subject_alternative_names = [
      "use1.${keys(module.zones.route53_zone_name)[0]}",
      "euw1.${keys(module.zones.route53_zone_name)[0]}",
      "ape1.${keys(module.zones.route53_zone_name)[0]}"
  ]
}

module "api_gateway_euw1" {
    source  = "terraform-aws-modules/apigateway-v2/aws"
    version = "1.0.0"

    name        = "${random_pet.this.id}-http"
    domain_name = keys(module.zones.route53_zone_name)[0]
    domain_name_certificate_arn = module.acm.acm_certificate_arn

    providers = {
        aws = aws.euw1
    }
}

module "api_gateway_ape1" {
    source  = "terraform-aws-modules/apigateway-v2/aws"
    version = "1.0.0"

    name        = "${random_pet.this.id}-http"
    domain_name = keys(module.zones.route53_zone_name)[0]
    domain_name_certificate_arn = module.acm.acm_certificate_arn

    providers = {
        aws = aws.ape1
    }
}

module "vpc_use1" {
    source = "terraform-aws-modules/vpc/aws"

    providers = {
        aws = aws.use1
    }

    name = "use1-vpc-for-private-route53-zone"
    cidr = "10.0.0.0/16"
}

module "vpc_euw1" {
    source = "terraform-aws-modules/vpc/aws"

    providers = {
        aws = aws.euw1
    }

    name = "euw1-vpc-for-private-route53-zone"
    cidr = "10.1.0.0/16"
}

module "vpc_ape1" {
    source = "terraform-aws-modules/vpc/aws"

    providers = {
        aws = aws.ape1
    }

    name = "ape1-vpc-for-private-route53-zone"
    cidr = "10.2.0.0/16"
}
