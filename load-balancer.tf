resource "docker_network" "loadbalancer" {
  name       = "public"
  driver     = "overlay"
  attachable = true
}

resource "docker_service" "loadbalancer" {
  name = "loadbalancer"
  depends_on = [
    docker_network.loadbalancer
  ]

  mode {
    global = true
  }
  task_spec {
    restart_policy = {
      condition    = "any"
      max_attempts = 0
    }
    container_spec {
      image = "byjg/easy-haproxy:2.0"
      privileges {
        se_linux_context {
          disable = true
        }
      }
      env = {
        DISCOVER             = "swarm"
        HAPROXY_USERNAME     = "stats"
        HAPROXY_PASSWORD     = "CaptainMorgan"
        HAPROXY_STATS_PORT   = "1936"
        HAPROXY_CUSTOMERRORS = "false"
      }
      mounts {
        target    = "/var/run/docker.sock"
        source    = "/var/run/docker.sock"
        read_only = false
        type      = "bind"
      }
    }
    networks = [docker_network.loadbalancer.id]
    resources {
      reservation {
        nano_cpus    = 100000000
        memory_bytes = 10000000
      }
      limits {
        nano_cpus    = 200000000
        memory_bytes = 128000000
      }
    }
    placement {
      constraints = [
        "engine.labels.node-purpose == manager",
      ]
      platforms {
        architecture = "amd64"
        os           = "linux"
      }
    }

  }

  update_config {
    parallelism       = 1
    delay             = "10s"
    failure_action    = "pause"
    monitor           = "5s"
    max_failure_ratio = "0.1"
    order             = "stop-first"
  }

  rollback_config {
    parallelism       = 2
    delay             = "5ms"
    failure_action    = "pause"
    monitor           = "10h"
    max_failure_ratio = "0.9"
    order             = "stop-first"
  }

  endpoint_spec {
    ports {
      target_port    = "80"
      published_port = "80"
      publish_mode   = "ingress"
    }
    ports {
      target_port    = "1936"
      published_port = "1936"
      publish_mode   = "ingress"
    }
  }
}
