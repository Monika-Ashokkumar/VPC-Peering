provider "aws" {
  region = "us-west-1"
  alias  = "west"
}

provider "aws" {
  region = "us-east-1"
  alias  = "east"
}
