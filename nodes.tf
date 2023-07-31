data "template_file" "worker" {
  #count = 1
  template = (join("\n", tolist([
    file("${path.root}/templates/base.sh"),
    file("${path.root}/templates/worker.sh")
  ])))
  vars = {
    priv_key              = var.pri_key
    boundary_cluster_addr = local.boundary_cluster_addr
    worker_token          = local.worker_token
  }
}

data "template_cloudinit_config" "worker" {
  #count         = 1
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    #content      = element(data.template_file.worker.*.rendered, count.index)
    content      = data.template_file.worker.rendered
  }
}

# INSTANCES

resource "aws_instance" "bastionhost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 10)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.bastionhost.id]
  key_name                    = var.pub_key
  #user_data = element(data.template_cloudinit_config.worker.*.rendered, count.index)
  user_data = data.template_cloudinit_config.worker.rendered

  tags = {
    Name        = "bastionhost-${var.name}"
  }
}

resource "aws_instance" "web_nodes" {
  count                       = var.web_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.web_subnet.*.id, count.index + 1)
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.pub_key


  tags = {
    Name        = format("web-%02d", count.index + 1)
  }
}


resource "boundary_host_catalog_static" "catalog" {
  name        = "server-catalog"
  description = "My webnodes catalog"
  scope_id    = local.demo_org_id
  }

resource "boundary_host_set_static" "set" {
  type            = "static"
  name            = "server-host-set"
  host_catalog_id = boundary_host_catalog_static.catalog.id
  host_ids = boundary_host_static.servers.*.id
}
resource "boundary_host_static" "servers" {
  count           = var.web_node_count
  type            = "static"
  #name            = "web-${count.index}"
  name            = aws_instance.web_nodes.*.tags[count.index]["Name"]
  host_catalog_id = boundary_host_catalog_static.catalog.id
  address         = element(aws_instance.web_nodes.*.private_ip, count.index)
}

resource "boundary_target" "ssh_hosts" {
  name                                       = "ssh-injection-upcloud"
  description                                = "Ssh targets"
  type                                       = "ssh"
  default_port                               = "22"
  scope_id                                   = local.demo_project_id
  ingress_worker_filter                      = "\"worker1\" in \"/tags/type\""
  enable_session_recording                   = false
  #storage_bucket_id                          = boundary_storage_bucket.session-storage.id
  host_source_ids                            = [
    boundary_host_set_static.set.id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.example.id
  ]
}



resource "boundary_credential_store_static" "example" {
  name        = "example_static_credential_store"
  description = "My first static credential store!"
  scope_id    = local.demo_project_id
}

resource "boundary_credential_ssh_private_key" "example" {
  name                   = "example_ssh_private_key"
  description            = "My first ssh private key credential!"
  credential_store_id    = boundary_credential_store_static.example.id
  username               = "ubuntu"
  private_key            = local.priv_key
  #private_key            =  file("~/.ssh/id_rsa") # change to valid SSH Private Key
  #private_key_passphrase = "optional-passphrase" # change to the passphrase of the Private Key if required
}




# resource "aws_instance" "api_nodes" {
#   count                       = var.api_node_count
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = var.instance_type
#   subnet_id                   = element(aws_subnet.api_subnet.*.id, count.index + 1)
#   associate_public_ip_address = "false"
#   vpc_security_group_ids      = [aws_security_group.api.id]
#   key_name                    = var.pub_key_n

#   tags = {
#     Name        = format("api-%02d", count.index + 1)
#   }
# }