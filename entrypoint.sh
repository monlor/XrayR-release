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
    PanelType: "NewV2board" # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "${API_HOST}"
      ApiKey: "${API_KEY}"
      NodeID: ${NODE_ID}
      NodeType: ${NODE_TYPE} # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: ${ENABLE_VLESS:-false} # Enable Vless for V2ray Type
      EnableXTLS: ${ENABLE_XTLS:-false} # Enable XTLS for V2ray and Trojan
      SpeedLimit: ${SPEED_LIMIT:-0} # Mbps, Local settings will replace remote settings
      DeviceLimit: 0 # Local settings will replace remote settings
      RuleListPath: /etc/XrayR/rulelist # Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: ${ENABLE_DNS:-true} # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
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
      EnableFallback: ${ENABLE_FALLBACK:-false} # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: ${CERT_MODE:-http} # Option about how to get certificate: none, file, http, dns
        CertDomain: "${DOMAIN:-}" # Domain to cert
        Email: ${EMAIL:-admin@examle.com}
        CertFile: /etc/XrayR/cert/node-${NODE_ID}.crt # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/node-${NODE_ID}.key
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
          "geosite:disney",
          "geosite:hulu",
          "geosite:primevideo",
          "geosite:cbs",
          "geosite:abc",
          "geosite:dmm",
          "geosite:fox",
          "geosite:bbc",
          "geosite:hbo",
          "geosite:bahamut",
          "geosite:abema",
          "geosite:openai"
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
export CHATGPT_OUT="${CHATGPT_OUT:-ChatGPT}"

# inject variables
inject_var() {
  envsubst < "$1" > "$1".tmp
  mv "$1".tmp "$1"
}

# inject json object to json file
inject_json_obj() {
  file="$1"
  # json path, eg: .rules .
  path="$2"
  # json array, eg: [{"a": 1}]
  arr="$3"
  jq "$path += $arr" < "$file" > "$file".tmp
  mv "$file".tmp "$file"
}

cp -f /etc/XrayR/route.json.example /etc/XrayR/route.json
cp -f /etc/XrayR/custom_outbound.json.example /etc/XrayR/custom_outbound.json

inject_var /etc/XrayR/route.json

# 住宅ip代理
if [ "${RESIDENTIAL_PROXY:-false}" = "true" ]; then
  echo "生成住宅ip代理配置..."
  proxy_outbound_config='[{
    "tag": "residential_proxy",
    "protocol": "socks",
    "settings": {
      "servers": [
        {
          "address": "'${RESIDENTIAL_PROXY_SERVER}'",
          "port": '${RESIDENTIAL_PROXY_PORT}',
          "users": [
            {
              "user": "'${RESIDENTIAL_PROXY_USER}'",
              "pass": "'${RESIDENTIAL_PROXY_PASS}'",
              "level": 1
            }
          ]
        }
      ]
    }
  }]'
  proxy_route_config='[{
    "type": "field",
    "network": "tcp,udp",
    "outboundTag": "residential_proxy"
  }]'
  inject_json_obj /etc/XrayR/custom_outbound.json '.' "$proxy_outbound_config"
  inject_json_obj /etc/XrayR/route.json '.rules' "$proxy_route_config"
fi


XrayR --config /etc/XrayR/config.yml