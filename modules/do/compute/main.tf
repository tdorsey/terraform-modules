# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = "${var.digitalocean_token}"
}

#Set up the http provider
provider "http" { }


#Get the IP of the host executing terraform plan
data "http" "public_ip" {
  url = "https://ifconfig.co/ip" 
}


data "template_file" "user_data" {
  template = "${file("${path.module}/user-data-ubuntu.tpl")}"

  vars {
#    docker_pkg_name = "${var.docker_pkg_name}"
    hostname-prefix = "${var.instance_type}"
    docker_cmd      = "${var.docker_cmd}"
  }
}

resource "digitalocean_droplet" "rancher_instance" {
  count              = "${var.node_count}"
  image              = "ubuntu-16-04-x64"
  name              = "${var.instance_name}"
  region             = "${var.do_region}"
  size               = "${var.do_droplet_size}"
  backups            = false
  ipv6               = false
  private_networking = false
  user_data          = "${data.template_file.user_data.rendered}"
  ssh_keys           = "${var.ssh_keys}"
}

resource "digitalocean_floating_ip" "rancher_floating_ip" {
  droplet_id = "${digitalocean_droplet.rancher_instance.id}"
  region     = "${digitalocean_droplet.rancher_instance.region}"
}


# Create a new domain
resource "digitalocean_domain" "default" {
  name = "rtd3.me"
}

# Add a record to the domain
resource "digitalocean_record" "floating_a_record" {
  domain = "rtd3.me"
  type   = "A"
  name   = "${var.instance_name}"
  value  = "${digitalocean_floating_ip.rancher_floating_ip.ip_address}"
}

# Add a record to the domain
resource "digitalocean_record" "bare_A_record" {
  domain = "rtd3.me"
  type   = "A"
  name   = "@"
  value  = "${chomp(data.http.public_ip.body)}"
}

#variable "cnames" {
 # default = ["auth", "tv", "movies", "status", "docker", "plex", "plexpy", "mail", "www", "bt", "graphs","nzb"]
#}


resource "digitalocean_record" "cname_wildcard" {
  domain = "rtd3.me"
  type   = "CNAME"
  name   = "*"
  value  = "@"
}

  #  resource "digitalocean_record" "cnames" {
   #   count   = "${length(var.cnames)}"
   #   domain = "rtd3.me."
    #  type   = "CNAME"
    #  name    = "${element(var.cnames, count.index)}"
    #  value  = "${digitalocean_record.redwood.name}"
   # }


# Output the FQDN for the record
output "fqdn" {
  value = "${digitalocean_record.floating_a_record.fqdn}"
}

output "server-ip" {
  value = "${digitalocean_droplet.rancher_instance.*.ipv4_address[0]}"
}
