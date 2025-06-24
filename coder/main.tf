terraform {
  required_providers {
    coder = {
      source = "coder/coder"
      version = "~> 2.5"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
}

variable "docker_host" {
  type        = string
  description = "Docker host"
  default     = "tcp://katerose-fsn-cdr-dev.tailscale.svc.cluster.local:2375"
}

provider "docker" {
  host = var.docker_host
}

provider "coder" {}

data "coder_external_auth" "github" {
  id = "github"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_workspace_preset" "model_speed" {
  name        = "Best speed with instruction tunning"
  parameters = {
    "model_name"     = "Llama-3.2-1B"
    "model_quant"    = "Q2_K"
    "model_instruct" = "true"
  }
}

data "coder_workspace_preset" "model_quality" {
  name        = "Best quality with instruction tunning"
  parameters = {
    "model_name"     = "Meta-Llama-3.1-8B"
    "model_quant"    = "Q8_0"
    "model_instruct" = "true"
  }
}

data "coder_parameter" "model_name" {
  name          = "model_name"
  display_name  = "Model name"
  type          = "string"
  default       = "Meta-Llama-3-8B"

  # Models published on: https://huggingface.co/QuantFactory
  option {
    name = "Meta Llama 3 8B"
    value = "Meta-Llama-3-8B"
  }
  option {
    name = "Meta Llama 3.1 8B"
    value = "Meta-Llama-3.1-8B"
  }
  option {
    name = "Meta Llama 3.2 1B"
    value = "Llama-3.2-1B"
  }
  
  order = 1
}

data "coder_parameter" "model_quant" {
  name          = "model_quant"
  display_name  = "Quantization"
  type          = "string"
  default       = "Q4_0"

  option {
    name = "2-bit"
    value = "Q2_K"
  }
  option {
    name = "4-bit"
    value = "Q4_0"
  }
  option {
    name = "8-bit"
    value = "Q8_0"
  }

  order = 2
}

data "coder_parameter" "model_instruct" {
  name          = "model_instruct"
  display_name  = "Instructions tuning enabled?"
  type          = "bool"
  default       = true

  order = 3
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Add any commands that should be executed at workspace startup (e.g install requirements, start a program, etc) here
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # you can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
  }
}

resource "coder_script" "setup_dev_environment" {
  agent_id           = coder_agent.main.id
  display_name       = "Setup dev environment"
  run_on_start       = true
  start_blocks_login = true

  script = <<-EOF
    #!/bin/bash
    set -e

    MODEL_REPO_NAME=${data.coder_parameter.model_name.value}${data.coder_parameter.model_instruct.value ? "-Instruct" : ""}-GGUF
    MODEL_GGUF=${data.coder_parameter.model_name.value}${data.coder_parameter.model_instruct.value ? "-Instruct" : ""}.${data.coder_parameter.model_quant.value}.gguf

    # Install packages
    sudo apt-get update
    sudo apt-get install tmux -y

    # Download LLM model in the GGUF format
    pipx install huggingface_hub[cli]
    /home/coder/.local/bin/huggingface-cli download QuantFactory/$MODEL_REPO_NAME --include $MODEL_GGUF --local-dir 'hf-models'

    # Install llama.cpp
    if [ ! -d llama-cpp ]; then
      wget https://github.com/ggml-org/llama.cpp/releases/download/b5634/llama-b5634-bin-ubuntu-x64.zip
      unzip -x llama-b5634-bin-ubuntu-x64.zip && rm llama-b5634-bin-ubuntu-x64.zip
      mv build llama-cpp
    fi

    # Start llama-server
    (
      cd llama-cpp/bin
      ./llama-server --model /home/coder/hf-models/$MODEL_GGUF --host 0.0.0.0 --port 8080 > /tmp/llama-server.log 2>&1  &
    )

    # Prepare project
    if [ ! -d coder-llm-starter-kit ]; then
      git clone https://github.com/mtojek/coder-llm-starter-kit
      (
        cd coder-llm-starter-kit
        python3 -m venv venv
        source venv/bin/activate
        python3 -m pip install -r requirements.txt
      )
    fi
  EOF
}

resource "coder_script" "tear_down_dev_environment" {
  agent_id     = coder_agent.main.id
  display_name = "Tear down dev environment"
  run_on_stop  = true

  script       = <<-EOF
    #!/bin/sh
    pkill llama-server
  EOF
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  lifecycle {
    ignore_changes = all
  }

  count = data.coder_workspace.me.start_count
  image = "codercom/enterprise-base:ubuntu"
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
