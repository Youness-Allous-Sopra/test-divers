# Variable environement a definir dans pipeline github, sinon la valeur par default sera utilisee
variable "environement" {
  default = "envir-formation"
}


locals {
  env_reseau = {
      prod   = ["172.25.20.0/24"]
      dev    = ["172.25.21.0/24"]
      qualif = ["172.25.22.0/24"]
      rect   = ["172.25.23.0/24"]
      
      envir-formation = ["172.25.50.0/24"]
  }  
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = null
}

variable "address_prefix_to_fw_route"{
  default = [ "10.130.0.0/16", "10.131.0.0/16", "10.142.0.0/16","10.40.0.0/16", "172.25.0.224/27", "172.25.0.128/27", "0.0.0.0/0" ]
}

variable "private_dns_zone_name" {
  description = "The name of the Hub Private DNS zone"
  default     = null
}