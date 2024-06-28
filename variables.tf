variable "project" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "australia-southeast1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "australia-southeast1-a"
}
