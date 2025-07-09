#!/bin/sh

set -ue

echo "生成XrayR配置..."
cat > /etc/XrayR/config.yml <<-EOF
Log:
  Level: ${LOG_LEVEL:-warning} # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: ${HANDSHAKE:-4} # Handshake time limit, Second
  ConnIdle: ${CONN_IDLE:-600} # Connection idle time limit, Second
  UplinkOnly: ${UPLINK_ONLY:-2} # Time limit when the connection downstream is closed, Second
  DownlinkOnly: ${DOWNLINK_ONLY:-4} # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: ${BUFFER_SIZE:-4096} # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: ${PANEL_TYPE:-NewV2board} # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "${API_HOST}"
      ApiKey: "${API_KEY}"
      NodeID: ${NODE_ID}
      NodeType: ${NODE_TYPE} # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: ${ENABLE_VLESS:-false} # Enable Vless for V2ray Type
      EnableXTLS: ${ENABLE_XTLS:-false} # Enable XTLS for V2ray and Trojan
      SpeedLimit: ${SPEED_LIMIT:-0} # Mbps, Local settings will replace remote settings
      # 如果使用了中转节点，限制会不准确，所以值要设置大一些
      DeviceLimit: ${DEVICE_LIMIT_NUM:-0} # Local settings will replace remote settings
      RuleListPath: /etc/XrayR/rulelist # Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: ${UPDATE_PERIODIC:-60} # Time to update the nodeinfo, how many sec.
      EnableDNS: ${ENABLE_DNS:-true} # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: ${DNSType:-AsIs} # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: ${ENABLE_PROXY_PROTOCOL:-false} # Only works for WebSocket and TCP
      # 限速500mbps，5次告警阈值之后限速到100mbps，持续60分钟
      AutoSpeedLimitConfig:
        Limit: ${AUTO_SPEED_LIMIT:-500} # Warned speed. Set to 0 to disable AutoSpeedLimit ()
        WarnTimes: ${AUTO_SPEED_LIMIT_WARN_TIMES:-5} # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: ${AUTO_SPEED_LIMIT_SPEED:-100} # The speedlimit of a limited user (unit: mbps)
        LimitDuration: ${AUTO_SPEED_LIMIT_DURATION:-60} # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: ${DEVICE_LIMIT:-false} # Enable the global device limit of a user
        RedisAddr: ${REDIS_ADDR:-127.0.0.1} # The redis server address
        RedisPassword: ${REDIS_PASSWORD:-} # Redis password
        RedisDB: ${REDIS_DB:-0} # Redis DB
        Timeout: ${REDIS_TIMEOUT:-8} # Timeout for redis request
        Expiry: ${REDIS_EXPIRY:-60} # Expiry time (second)
      EnableFallback: ${ENABLE_FALLBACK:-false} # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: ${FALLBACK_DEST:-80} # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: ${FALLBACK_PROXY_PROTOCOL_VER:-0} # Send PROXY protocol version, 0 for dsable
      REALITYConfigs:
        Show: ${REALITY_SHOW:-true} # Show REALITY debug
        Dest: ${REALITY_DEST:-www.amazon.com:443} # Required, Same as fallback
        ProxyProtocolVer: ${REALITY_PROXY_PROTOCOL_VER:-0} # Send PROXY protocol version, 0 for disable
        ServerNames: # Required, list of available serverNames for the client, * wildcard is not supported at the moment.
          - ${REALITY_SERVER_NAMES:-www.amazon.com}
        PrivateKey: ${REALITY_PRIVATE_KEY:-} # Required, execute './XrayR x25519' to generate.
        MinClientVer: ${REALITY_MIN_CLIENT_VER:-} # Optional, minimum version of Xray client, format is x.y.z.
        MaxClientVer: ${REALITY_MAX_CLIENT_VER:-} # Optional, maximum version of Xray client, format is x.y.z.
        MaxTimeDiff: 0 # Optional, maximum allowed time difference, unit is in milliseconds.
        ShortIds: # Required, list of available shortIds for the client, can be used to differentiate between different clients.
          - ${REALITY_SHORT_IDS:-0}
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
  dns_ip=$(echo "${MEDIA_DNS_SERVER}" | awk -F ':' '{print $1}')
  # 判断dns_ip是不是ip格式，如果不是则认为是域名，自动解析出ip
  if ! echo "${dns_ip}" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    dns_ip=$(nslookup "${dns_ip}" | grep -A 1 'Name:' | tail -n 1 | awk '{print $NF}')
  fi
  
  dns_port=$(echo "${MEDIA_DNS_SERVER}" | awk -F ':' '{print $2}')
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
          "geosite:4chan",
          "geosite:niconico",
          "geosite:pixiv",
          "geosite:abema",
          "geosite:viu",
          "geosite:bilibili",
          "geosite:openai",
          "geosite:anthropic"
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

# 默认路由出口
export DEFAULT_OUT="${DEFAULT_OUT:-IPv4_Out}"
# chatgpt outbound
export CHATGPT_OUT="${CHATGPT_OUT:-IPv4_Warp}"
# 流媒体
export MEDIA_OUT="${MEDIA_OUT:-IPv4_Out}"

# 住宅ip代理
# 端口需要有默认值
export RESIDENTIAL_PROXY_PORT="${RESIDENTIAL_PROXY_PORT:-6001}"
if [ "${RESIDENTIAL_PROXY:-false}" = "true" ]; then
  echo "生成住宅代理已启用..."
  DEFAULT_OUT="Residential_Proxy"
fi

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
inject_var /etc/XrayR/custom_outbound.json

XrayR --config /etc/XrayR/config.yml