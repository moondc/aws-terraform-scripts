# data "aws_caller_identity" "current" {}

# locals {
#   domain = var.hosted_zone
# }

// Hosted Zone

# data "aws_route53_zone" "zone" {
#     name = local.domain
# }

// VPC

# resource "aws_vpc" "main" {
#     cidr_block = "10.0.0.0/16"
# }


// API Gateway

# resource "aws_api_gateway_rest_api" "api" {
#     name = var.api_name
#     description = "generic empty api gateway"

#     endpoint_configuration {
#         types = ["REGIONAL"]
#     }
# }

# resource "aws_api_gateway_domain_name" "api_gateway_domain" {
#     domain_name = local.domain
#     security_policy = "TLS_1_2"

#     regional_certificate_arn = aws_acm_certificate.cert.arn
#     endpoint_configuration {
#       types = ["REGIONAL"]
#     }
# }
# resource "aws_api_gateway_base_path_mapping" "base_path" {
#     api_id = aws_api_gateway_rest_api.api.id
#     stage_name = aws_api_gateway_deployment.deployment.stage_name
#     domain_name = aws_api_gateway_domain_name.api_gateway_domain.domain_name
# }

# resource "aws_api_gateway_resource" "pathRoot" {
#     rest_api_id = aws_api_gateway_rest_api.api.id
#     parent_id = aws_api_gateway_rest_api.api.root_resource_id
#     path_part = "apiStatus"
# }

# resource "aws_api_gateway_method" "methodRoot" {
#     rest_api_id = aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.pathRoot.id
#     http_method = "GET"
#     authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "integrationRoot" {
#     rest_api_id = aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.pathRoot.id
#     http_method = aws_api_gateway_method.methodRoot.http_method
#     type        = "MOCK"
#     request_templates = {
#         "application/json" = <<EOF
# {
#     "statusCode":200
# }
# EOF
#     }
# }

# resource "aws_api_gateway_method_response" "two_hundred" {
#     rest_api_id = aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.pathRoot.id
#     http_method = aws_api_gateway_method.methodRoot.http_method
#     status_code = "200"
# }

# resource "aws_api_gateway_integration_response" "mock_response" {
#     rest_api_id = aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.pathRoot.id
#     http_method = aws_api_gateway_method.methodRoot.http_method
#     status_code = aws_api_gateway_method_response.two_hundred.status_code
#     response_templates = {
#         "${var.api_content_type}" = var.api_content
#     }
# }

# resource "aws_api_gateway_deployment" "deployment" {
#     depends_on = [ aws_api_gateway_integration.integrationRoot, aws_api_gateway_method.methodRoot ]
#     rest_api_id = aws_api_gateway_rest_api.api.id
#     stage_name = "api"
#     variables = {
#       deployed_at = timestamp()
#     }

#     lifecycle {
#         create_before_destroy = true
#     }
# }

// Api Gateway ACM

# resource "aws_route53_record" "domain" {
#     name = local.domain
#     type = "A"
#     zone_id = data.aws_route53_zone.zone.id
#     ttl     = 300

#     records = [var.public_ip]
# }

# resource "aws_route53_record" "www_domain" {
#     name = "www.${local.domain}"
#     type = "A"
#     zone_id = data.aws_route53_zone.zone.id
#     ttl     = 300

#     records = [var.public_ip]
# }

# resource "aws_route53_record" "domain" {
#     name = local.domain
#     type = "A"
#     zone_id = data.aws_route53_zone.zone.id

#     alias {
#         name    = aws_api_gateway_domain_name.api_gateway_domain.regional_domain_name
#         zone_id = aws_api_gateway_domain_name.api_gateway_domain.regional_zone_id
#         evaluate_target_health = false
#     }
# }

# resource "aws_acm_certificate" "cert"{
#     domain_name = local.domain
#     subject_alternative_names = [local.domain]
#     validation_method = "DNS"
#     lifecycle {
#       create_before_destroy = true
#     }
# }

# resource "aws_route53_record" "validation" {
#     zone_id = data.aws_route53_zone.zone.zone_id
#     name = element(aws_acm_certificate.cert.domain_validation_options.*.resource_record_name,0)
#     type = element(aws_acm_certificate.cert.domain_validation_options.*.resource_record_type,0)
#     records = [element(aws_acm_certificate.cert.domain_validation_options.*.resource_record_value,0)]
#     ttl = 60
# }

# resource "aws_acm_certificate_validation" "cert" {
#     certificate_arn = aws_acm_certificate.cert.arn
#     validation_record_fqdns = aws_route53_record.validation.*.fqdn
# }