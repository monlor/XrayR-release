#!/bin/sh

set -ue

cat > /etc/XrayR/config.yml <<-EOF
Log:
  Level: warning # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: "NewV2board" # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "${API_HOST}"
      ApiKey: "${API_KEY}"
      NodeID: ${NODE_ID}
      NodeType: ${NODE_TYPE} # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: ${ENABLE_VLESS:-false} # Enable Vless for V2ray Type
      EnableXTLS: ${ENABLE_XTLS:-false} # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings
      DeviceLimit: 0 # Local settings will replace remote settings
      RuleListPath: /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      DisableSniffing: false # Disable domain sniffing 
      EnableProxyProtocol: false
      # 限速500mbps，5次告警阈值之后限速到100mbps，持续60分钟
      AutoSpeedLimitConfig:
        Limit: 500 # Warned speed. Set to 0 to disable AutoSpeedLimit ()
        WarnTimes: 5 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 100 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 60 # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: ${DEVICE_LIMIT:-false} # Enable the global device limit of a user
        RedisAddr: ${REDIS_ADDR:-127.0.0.1} # The redis server address
        RedisPassword: ${REDIS_PASSWORD:-} # Redis password
        RedisDB: 0 # Redis DB
        Timeout: 8 # Timeout for redis request
        Expiry: 60 # Expiry time (second)
      CertConfig:
        CertMode: ${CERT_MODE:-http} # Option about how to get certificate: none, file, http, dns
        CertDomain: "${DOMAIN:-}" # Domain to cert
        Email: ${EMAIL:-admin@examle.com}
        CertFile: /etc/XrayR/cert/node.crt # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/node.key
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: ${EMAIL:-admin@examle.com}
          CLOUDFLARE_API_KEY: ${CLOUDFLARE_API_KEY:-}
EOF

XrayR --config /etc/XrayR/config.yml