storage "raft" {
  path    = "/vault/file"
  node_id = "vault2"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = 1
}

api_addr      = "http://vault2:8200"
cluster_addr  = "http://vault2:8201"
ui            = true
disable_mlock = true
