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

provider "google" {
  project = var.project
  region  = var.region
}

resource "google_compute_network" "frontend_network" {
  name = "frontend-network"
}

resource "google_compute_network" "backend_network" {
  name = "backend-network"
}

resource "google_compute_instance" "webapp" {
  name         = "webapp"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = google_compute_network.frontend_network.name
    access_config {
    }
  }

  metadata_startup_script = <<-EOF
    #! /bin/bash
    sudo apt-get update
    sudo apt-get install -y apache2 php libapache2-mod-php php-mysql openssl
    sudo a2enmod ssl

    # Copy self-signed SSL certificates from metadata
    sudo mkdir -p /etc/ssl/private /etc/ssl/certs
    echo '${file("/home/your-username/ssl/private/selfsigned.key")}' | sudo tee /etc/ssl/private/selfsigned.key
    echo '${file("/home/your-username/ssl/certs/selfsigned.crt")}' | sudo tee /etc/ssl/certs/selfsigned.crt

    # Configure Apache to use the self-signed certificates
    sudo bash -c 'cat > /etc/apache2/sites-available/default-ssl.conf <<EOF
    <IfModule mod_ssl.c>
      <VirtualHost _default_:443>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        SSLEngine on
        SSLCertificateFile    /etc/ssl/certs/selfsigned.crt
        SSLCertificateKeyFile /etc/ssl/private/selfsigned.key

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
                SSLOptions +StdEnvVars
        </Directory>

      </VirtualHost>
    </IfModule>
    EOF'

    sudo a2ensite default-ssl
    sudo service apache2 reload
    sudo apt-get install -y unzip
    EOF

  provisioner "file" {
    source      = "webapp/"
    destination = "/var/www/html/"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl restart apache2"
    ]
  }
}

resource "google_compute_instance" "database" {
  name         = "database"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = google_compute_network.backend_network.name
  }

  metadata_startup_script = <<-EOF
    #! /bin/bash
    sudo apt-get update
    sudo apt-get install -y mysql-server
    sudo service mysql start
    EOF

  lifecycle {
    create_before_destroy = true
  }

  attached_disk {
    source = google_compute_disk.db_disk.name
    mode   = "rw"
  }
}

resource "google_compute_disk" "db_disk" {
  name  = "database-disk"
  type  = "pd-standard"
  zone  = var.zone
  size  = 10
}

resource "google_compute_firewall" "default_allow_http" {
  name    = "default-allow-http"
  network = google_compute_network.frontend_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "default_allow_https" {
  name    = "default-allow-https"
  network = google_compute_network.frontend_network.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}
