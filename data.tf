# data source : a piece of readonly data fetched from provider every time you run tf , it queries API for data and make it available for code
data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}