variable "short_sha" {
  type = string
}

variable "branch_name" {
  type = string
}

variable "build_id" {
  type = string
}

variable "zone" {
  type = string
  default = "us-central1-b"
}

source "googlecompute" "kne-image" {
  project_id   = "gep-kne"
  source_image = "ubuntu-2004-focal-v20210927"
  disk_size    = 50
  image_name   = "kne-external-${var.build_id}"
  image_family = "kne-external-untested"
  image_labels = {
    "kne_gh_commit_sha" : "${var.short_sha}",
    "kne_gh_branch_name" : "${var.branch_name}",
    "cloud_build_id" : "${var.build_id}",
  }
  image_description     = "Ubuntu based linux VM image with KNE and all external dependencies installed."
  ssh_username          = "user"
  machine_type          = "e2-medium"
  zone                  = "${var.zone}"
  service_account_email = "packer@gep-kne.iam.gserviceaccount.com"
  use_internal_ip       = true
  scopes                = ["https://www.googleapis.com/auth/cloud-platform"]
}

build {
  name    = "kne-builder"
  sources = ["sources.googlecompute.kne-image"]

  provisioner "shell" {
    inline = [
      "echo Installing golang...",
      "curl -O https://dl.google.com/go/go1.18.2.linux-amd64.tar.gz",
      "sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.2.linux-amd64.tar.gz",
      "rm go1.18.2.linux-amd64.tar.gz",
      "echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc",
      "echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc",
      "/usr/local/go/bin/go version",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing docker...",
      "sudo apt-get update",
      "sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io build-essential -y",
      "sudo usermod -aG docker $USER",
      "sudo docker version",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing kubectl...",
      "sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install kubectl -y",
      "kubectl version --client",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing golang license tool...",
      "/usr/local/go/bin/go install github.com/google/go-licenses@latest",
      "curl --create-dirs -o third_party/licenses/go-licenses/LICENSE https://raw.githubusercontent.com/google/go-licenses/master/LICENSE",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing kind...",
      "/usr/local/go/bin/go install sigs.k8s.io/kind@latest",
      "curl --create-dirs -o third_party/licenses/kind/LICENSE https://raw.githubusercontent.com/kubernetes-sigs/kind/main/LICENSE",
      "sudo cp /home/$USER/go/bin/kind /usr/local/bin/",
      "/home/$USER/go/bin/kind version",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Cloning google/kne github repo...",
      "sudo apt-get install git -y",
      "git clone -b ${var.branch_name} https://github.com/google/kne.git",
      "cd kne",
      "PATH=$PATH:/usr/local/go/bin",
      "/home/$USER/go/bin/go-licenses check github.com/google/kne/kne_cli",
      "/home/$USER/go/bin/go-licenses save github.com/google/kne/kne_cli --save_path=\"../third_party/licenses/kne_cli\"",
      "cd kne_cli",
      "/usr/local/go/bin/go build -v",
      "sudo cp kne_cli /usr/local/bin/",
      "cd ../controller/server",
      "/usr/local/go/bin/go build -v",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Cloning openconfig/ondatra github repo...",
      "git clone https://github.com/openconfig/ondatra.git",
      "cd ondatra",
      "PATH=$PATH:/usr/local/go/bin",
      "/home/$USER/go/bin/go-licenses check github.com/openconfig/ondatra",
      "/home/$USER/go/bin/go-licenses save github.com/openconfig/ondatra --save_path=\"../third_party/licenses/ondatra\"",
    ]
  }
}