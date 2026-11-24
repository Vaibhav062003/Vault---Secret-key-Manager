storage "postgresql" {
  connection_url = "{{env \"DATABASE_URL\"}}"
  table          = "vault_kv_store"
  ha_enabled     = "false"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr      = "http://0.0.0.0:8200"
ui            = true
disable_mlock = true
