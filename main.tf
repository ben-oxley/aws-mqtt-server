terraform {
  #Start with backend commented out then uncomment once the s3 bucket is created
  #Once done, re-run terraform init -migrate-state
  backend "s3" {
    bucket = "aws-mqtt-state-dev"
    key    = "prod/terraform.tfstate"
    region = "eu-west-2"
    profile = "main"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  profile = "main"
  region  = "eu-west-2"
}

resource "aws_s3_bucket" "state" {
  bucket = "aws-mqtt-state-dev"

  tags = {
    Name        = "AWS MQTT Dev Terraform State"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_acl" "state_acl" {
  bucket = aws_s3_bucket.state.id
  acl    = "private"
}

resource "aws_iot_policy" "pubsub" {
  name = "PubSubToAnyTopic"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iot:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iot_thing" "ESP8266" {
  name = "4-Channel-Mains-Current-Sensor-ESP8266"

  attributes = {
    Mode = "examplevalue"
    Sensor1 = "Sensor1"
    Sensor2 = "Sensor2"
  }
}

resource "aws_iot_policy_attachment" "att" {
  policy = aws_iot_policy.pubsub.name
  target = "arn:aws:iot:eu-west-2:536507824931:cert/ece436695904f406c4965ea5907efbbe1d692e06d225aa9bd27cdec341ae6f8f"
}