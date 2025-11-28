output "metering_token" {
  value     = module.meshplatform.metering_token
  sensitive = true
}

output "metering_expose_token" {
  value = module.meshplatform.metering_expose_token
}

output "replicator_token" {
  value     = module.meshplatform.replicator_token
  sensitive = true
}

output "replicator_expose_token" {
  value = module.meshplatform.replicator_expose_token
}
