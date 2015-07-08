variable "do_token" {}
variable "domain" {}
variable "pub_key" {}
variable "pvt_key" {}
variable "ssh_fingerprint" {}

# Configure the DigitalOcean Provider
provider "digitalocean" {
	token = "${var.do_token}"
}

# Create a web server
resource "digitalocean_droplet" "suitecrm-terraform" {
	image = "ubuntu-14-04-x64"
	name = "${var.domain}"
	region = "nyc2"
	size = "512mb"
	ssh_keys = [
		"${var.ssh_fingerprint}"
	]

	connection {
		user = "root"
		type = "ssh"
		key_file = "${var.pvt_key}"
		timeout = "2m"
	}

	provisioner "file" {
		source = "install.sh"
		destination = "/root/install.sh"
	}

	provisioner "remote-exec" {
		inline = [
			# Export the required variables
			"DOMAIN='${var.domain}'; export DOMAIN",

			# Set install.sh to be executable, then run it
			"cd /root",
			"chmod +x install.sh",
			"./install.sh"
		]
	}

}

resource "digitalocean_domain" "suitecrm-terraform" {
	name = "${var.domain}"
	ip_address = "${digitalocean_droplet.suitecrm-terraform.ipv4_address}"
}