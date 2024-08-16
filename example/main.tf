// Create a server using all defaults

provider "aws" {
  profile = "my_profile"
  region = "us-east-1"
}

module "ec2_instance" {
  source = "../"

  name        = "my-ec2-server"
  namespace   = "my-namespace"

  ami = "ami-053b0d53c279acc90" # Ubuntu 22.04 LTS
  instance_type = "t2.micro"

  application_port = 8000

  db_username = "postgres"
  db_password = "my-db-password"
}
