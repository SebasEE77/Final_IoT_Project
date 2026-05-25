variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "iot-edge"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "lab"
}

variable "vpc_id" {
  default = "vpc-0347dcdaa7bce104f"
}

variable "subnet_id" {
  default = "subnet-0015eacaa2b133769" #us-east-1a
}

variable "ami_id" {
  default = "ami-02dfbd4ff395f2a1b" # Amazon Linux 2023
}

variable "key_name" {
  default = "Projects"
}

variable "instance_type" {
  default = "t3.micro"
}
