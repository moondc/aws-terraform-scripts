# data "aws_vpc" "main" {}
# data "aws_subnet" "private_subnet"{
#     filter{
#         name = "tag:Name"
#         values = [ "private" ]
#     }
# }

# data "aws_route53_zone" "zone" {
#     name = "<domain_name>.com"
# }
# // Load Balancer
# resource "aws_lb" "lb" {
#     name = "${var.container_name}-lb"
#     internal = true
#     load_balancer_type = "network"
#     subnets = [data.aws_subnet.private_subnet.id]
# }

# resource "aws_lb_target_group" "target_group" {
#     name     = "${var.container_name}-target-group"
#     port     = var.container_port
#     protocol = var.container_port == 443 || var.container_port == 8443 ? "TLS" : "TCP"
#     vpc_id   = data.aws_vpc.main.id
#     target_type = "ip"

#     health_check {
#       enabled = true
#       protocol = var.container_port == 443 || var.container_port == 8443 ? "HTTPS" : "HTTP"
#       path     = var.healthcheck_path
#       matcher = "200-399"
#     }
# }

# resource "aws_acm_certificate" "cert" {
#     domain_name = aws_route53_record.domain.name
#     validation_method = "DNS"
# }

# resource "aws_route53_record" "validation"{
#     zone_id = data.aws_route53_zone.zone.zone_id
#     name = element(aws_acm_certificate.cert.domain_validation_options.*.resource_record_name,0)
#     type = element(aws_acm_certificate.cert.domain_validation_options.*.resource_record_type,0)
#     records = [element(aws_acm_certificate.cert.domain_validation_options.*.resource_record_value,0)]
#     ttl = 60
# }

# resource "aws_acm_certificate_validation" "cert" {
#   certificate_arn = aws_acm_certificate.cert.arn
#   validation_record_fqdns = aws_route53_record.validation.*.fqdn
# }

# resource "aws_lb_listener" "lb_listener" {
#     load_balancer_arn = aws_lb.lb.arn
#     port = 443
#     protocol = "TLS"
#     ssl_policy = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
#     certificate_arn = aws_acm_certificate.cert.arn

#     default_action {
#       type = "forward"
#       target_group_arn = aws_lb_target_group.target_group.arn
#     }
# }

# resource "aws_route53_record" "domain"{
#     name = "${var.container_name}.internal.${data.aws_route53_zone.zone.name}"
#     type = "A"
#     zone_id = data.aws_route53_zone.zone.id

#     alias {
#       name = aws_lb.lb.dns_name
#       zone_id = aws_lb.lb.zone_id
#       evaluate_target_health = false
#     }
# }

// Api Gateway

# data "aws_api_gateway_rest_api" "api" {
#     name = var.api_gateway
# }

# resource "aws_api_gateway_vpc_link" "privateLink"{
#     name = "<service_name>"
#     target_arns = [aws_lb.lb.arn]
# }

# resource "aws_api_gateway_resource" "pathRoot" {
#     rest_api_id = data.aws_api_gateway_rest_api.api.id
#     parent_id = data.aws_api_gateway_rest_api.api.root_resource_id
#     path_part = "<service_name>"
# }

# resource "aws_api_gateway_method" "methodRoot" {
#     rest_api_id = data.aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.pathRoot.id
#     http_method = "ANY"
#     authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "integrationRoot" {
#     rest_api_id = data.aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.pathRoot.id
#     http_method = aws_api_gateway_method.methodRoot.http_method
#     integration_http_method =  "ANY"
#     type = "HTTP_PROXY"
#     uri = "https://${data.aws_route53_zone.zone.name}/<service_name>/"
#     passthrough_behavior = "WHEN_NO_MATCH"
#     content_handling = "CONVERT_TO_TEXT"
#     connection_type = "VPC_LINK"
#     connection_id = aws_api_gateway_vpc_link.privateLink.id
# }

# resource "aws_api_gateway_resource" "resource" {
#     rest_api_id = data.aws_api_gateway_rest_api.api.id
#     parent_id = aws_api_gateway_resource.pathRoot.id
#     path_part = "{proxy+}"
# }

# resource "aws_api_gateway_method" "method" {
#   rest_api_id = data.aws_api_gateway_rest_api.api.id
#   resource_id = aws_api_gateway_resource.resource.id
#   http_method = "ANY"
#   authorization = "NONE"
#   request_parameters = {
#     "method.request.path.proxy" = true
#   }
# }

# resource "aws_api_gateway_integration" "integration"{
#     rest_api_id = data.aws_api_gateway_rest_api.api.id
#     resource_id = aws_api_gateway_resource.resource.id
#     http_method = aws_api_gateway_method.method.http_method
#     integration_http_method = "ANY"
#     type = "HTTP_PROXY"
#     uri = "https://${data.aws_route53_zone.zone.name}/<service_name>/{proxy}"
#     passthrough_behavior = "WHEN_NO_MATCH"
#     content_handling = "CONVERT_TO_TEXT"
#     connection_type = "VPC_LINK"
#     connection_id = aws_api_gateway_vpc_link.privateLink.id
#     request_parameters = {
#       "integration.request.path.proxy" = "method.request.path.proxy"
#     }
# }

# resource "aws_api_gateway_deployment" "deployment" {
#     depends_on = [ aws_api_gateway_integration.integrationRoot, aws_api_gateway_integration.integration ]
#     rest_api_id = data.aws_api_gateway_rest_api.api.id
#     stage_name = "api"
#     triggers = {
#       redeployment = sha1(jsonencode([
#         aws_api_gateway_resource.resource.id,
#         aws_api_gateway_method.method,
#         aws_api_gateway_integration.integration,
#         aws_api_gateway_resource.pathRoot,
#         aws_api_gateway_method.methodRoot,
#         aws_api_gateway_integration.integrationRoot
#       ]))
#     }
# }

// ECS service

# resource "aws_iam_role" "ecs_task_role" {
#     name = "ecs_task_role"
#     assume_role_policy = jsonencode(
#     {
#         "Version": "2012-10-17",
#         "Statement":[{
#             "Action": "sts:AssumeRole",
#             "Principal":{
#                 "Service": [
#                     "ecs-tasks.amazonaws.com",
#                     "ecs.amazonaws.com"
#                 ]

#             },
#             "Effect":"Allow",
#             "Sid":""
#         }]
#     })
# }

# resource "aws_iam_role_policy" "ecs_execution_role_policy"{
#     role = aws_iam_role.ecs_task_role.id
#     policy = jsonencode(
#     {
#         "Version": "2012-10-17",
#         "Statement": [{
#             "Effect": "Allow",
#             "Action": [
#                 "ecr:BatchCheckLayerAvailability",
#                 "ecr:GetDownloadUrlForLayer",
#                 "ecr:BatchGetImage",
#                 "ecr:GetAuthorizationToken",
#                 "ecr:DescribeImages"
#             ],
#             "Resource": "*"
#         }]
#     })
# }

# resource "aws_ecs_task_definition" "task"{
#     family = var.container_name
#     network_mode = "awsvpc"
#     execution_role_arn = aws_iam_role.ecs_task_role.arn
#     requires_compatibilities = ["FARGATE"]
#     cpu = "256"
#     memory = "512"
#     container_definitions = <<EOF
#     [{
#         "name": "${var.container_name}",
#         "image": "<account_number>.dkr.ecr.us-east-2.amazonaws.com/${var.container_name}:latest",
#         "portMappings": [{
#             "containerPort": ${var.container_port},
#             "hostPort": ${var.container_port}
#         }],
#         "healthcheck" : {
#             "command": ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/${var.healthcheck_path} || exit 1"],
#             "interval": 30,
#             "timeout": 5,
#             "retries": 3,
#             "startPeriod": 120
#         },
#         "cpu" : 256,
#         "memory" : 512
#     }]
#     EOF
# }


# resource "aws_security_group" "ecs_security_group" {
#     vpc_id = data.aws_vpc.main.id
#     egress {
#         from_port   = 0
#         to_port     = 0
#         protocol    = "-1"
#         cidr_blocks = ["0.0.0.0/0"]
#         ipv6_cidr_blocks = ["::/0"]
#     }
#     ingress {
#         from_port   = var.container_port
#         to_port     = var.container_port
#         protocol    = "TCP"
#         cidr_blocks = data.aws_vpc.main.cidr_block_associations.*.cidr_block
#     }
# }

# resource "aws_ecs_service" "<service_name>" {
#     name            = var.container_name
#     cluster         = var.cluster_name
#     task_definition = aws_ecs_task_definition.task.arn
#     desired_count   = 1
#     launch_type     = "FARGATE"
#     network_configuration {
#         security_groups  = [aws_security_group.ecs_security_group.id]
#         subnets          = [data.aws_subnet.private_subnet.id]
#         assign_public_ip = true
#     }
#     load_balancer {
#         target_group_arn = aws_lb_target_group.target_group.arn
#         container_name   = var.container_name
#         container_port   = var.container_port
#     }
# }