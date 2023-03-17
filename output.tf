output "alb_dns_name" {
    value = aws_lb.ec2-lb.dns_name
    description = "the domain name of the load balancer"
}