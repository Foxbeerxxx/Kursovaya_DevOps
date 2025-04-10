variable "flow" {
  type    = string
  default = "24-01"
}

variable "cloud_id" {
  type    = string
  default = "b1gvjpk4qbrvling8qq1"
}
variable "folder_id" {
  type    = string
  default = "b1gse67sen06i8u6ri78"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}

