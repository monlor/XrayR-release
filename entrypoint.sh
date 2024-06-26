#!/bin/sh

set -ue

echo "生成XrayR配置..."
cat > /etc/XrayR/config.yml <<-EOF
Log:
  Level: warning # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: "${PANEL_TYPE:-NewV2board}" # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "${API_HOST}"
      ApiKey: "${API_KEY}"
      NodeID: ${NODE_ID}
      NodeType: ${NODE_TYPE:-V2ray} # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: ${ENABLE_VLESS:-false} # Enable Vless for V2ray Type
      VlessFlow: "xtls-rprx-vision" # Only support vless
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings
      DeviceLimit: 0 # Local settings will replace remote settings
      RuleListPath: /etc/XrayR/rulelist # Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: ${ENABLE_DNS:-true} # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: ${DNS_TYPE:-UseIP} # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: ${ENABLE_PROXY_PROTOCOL:-false} # Only works for WebSocket and TCP
      # 限速500mbps，5次告警阈值之后限速到100mbps，持续60分钟
      AutoSpeedLimitConfig:
        Limit: 500 # Warned speed. Set to 0 to disable AutoSpeedLimit ()
        WarnTimes: 5 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 100 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 20 # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: ${DEVICE_LIMIT:-false} # Enable the global device limit of a user
        RedisAddr: ${REDIS_ADDR:-127.0.0.1} # The redis server address
        RedisPassword: ${REDIS_PASSWORD:-} # Redis password
        RedisDB: 0 # Redis DB
        Timeout: 5 # Timeout for redis request
        Expiry: 60 # Expiry time (second)
      EnableFallback: ${ENABLE_FALLBACK:-false} # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      EnableREALITY: ${ENABLE_REALITY} # Enable REALITY
      REALITYConfigs:
        Show: ${REALITY_DEBUG:-true} # Show REALITY debug
        Dest: ${REALITY_DEST:-www.smzdm.com:443} # Required, Same as fallback
        ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
        ServerNames: # Required, list of available serverNames for the client, * wildcard is not supported at the moment.
$(echo ${REALITY_SERVER_NAMES} | tr ',' '\n' | while read domain; do
  echo "          - ${domain}"
done)
        PrivateKey: ${REALITY_PRIVATE_KEY} # Required, execute './xray x25519' to generate.
        MinClientVer: # Optional, minimum version of Xray client, format is x.y.z.
        MaxClientVer: # Optional, maximum version of Xray client, format is x.y.z.
        MaxTimeDiff: 0 # Optional, maximum allowed time difference, unit is in milliseconds.
        ShortIds: # Required, list of available shortIds for the client, can be used to differentiate between different clients.
$(echo ${REALITY_SHORT_IDS} | tr ',' '\n' | while read id; do
  echo "          - ${ids}"
done)
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

echo "生成dns配置..."
if [ -n "${MEDIA_DNS_SERVER:-}" ]; then
  dns_ip=$(echo ${MEDIA_DNS_SERVER} | awk -F ':' '{print $1}')
  # 判断dns_ip是不是ip格式，如果不是则认为是域名，自动解析出ip
  if ! echo ${dns_ip} | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    dns_ip=$(nslookup ${dns_ip} | grep -A 1 'Name:' | tail -n 1 | awk '{print $NF}')
  fi
  
  dns_port=$(echo ${MEDIA_DNS_SERVER} | awk -F ':' '{print $2}')
  cat > /etc/XrayR/dns.json <<-EOF
{
    "servers": [
      "8.8.8.8",
      "8.8.4.4",
      {
        
        "address": "${dns_ip}",
        "port": ${dns_port:-53},
        "domains": [
          "geosite:netflix",
          "geosite:disney"
        ]
      },
      "localhost"
    ],
    "tag": "dns_inbound"
}
EOF
else
  cat > /etc/XrayR/dns.json <<-EOF
{
    "servers": [
        "1.1.1.1",
        "8.8.8.8",
        "localhost"
    ],
    "tag": "dns_inbound"
}
EOF
fi

# chatgpt outbound, ChatGPT(default) Warp IPv4_out IPv6_out
CHATGPT_OUT=${CHATGPT_OUT:-ChatGPT}

cat > /etc/XrayR/route.json <<-EOF
{
    "domainStrategy": "AsIs",
    "rules": [
        {
            "type": "field",
            "domain": [
                "domain:openai.com",
                "domain:ai.com"
            ],
            "outboundTag": "${CHATGPT_OUT}"
        },
        {
            "type": "field",
            "outboundTag": "block",
            "ip": [
                "geoip:private"
            ]
        },
        {
            "type": "field",
            "outboundTag": "block",
            "protocol": [
                "bittorrent",
                "BitTorrent protocol",
                "torrent",
                "SMTP",
                "Thunder"
            ]
        }
    ]
}
EOF

XrayR --config /etc/XrayR/config.yml