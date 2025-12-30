resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.splunk_ent[0].id
  public_ip     = var.eip
  count         = var.splunk_ent_count
}


output "splunk_ent_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.splunk_ent.*.tags.Name,
    aws_eip_association.eip_assoc.*.public_ip
  )
}

output "splunk_ent_url" {
  value =  formatlist(
    "%s%s:%s", 
    "http://",
    aws_eip_association.eip_assoc.*.public_ip,
    "80",
  )
}

output "splunk_ent_url_fqdn" {
  value =  formatlist(
    "%s%s:%s", 
    "http://",
    var.fqdn,
    "80",
  )
}