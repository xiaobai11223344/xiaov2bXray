package panel

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"reflect"
	"strconv"
	"strings"
	"time"

	"encoding/json"
)

// Security type
const (
	None    = 0
	Tls     = 1
	Reality = 2
)

type NodeInfo struct {
	Id           int
	Type         string
	Security     int
	PushInterval time.Duration
	PullInterval time.Duration
	RawDNS       RawDNS
	Rules        Rules

	// origin
	VAllss      *VAllssNode
	Shadowsocks *ShadowsocksNode
	Trojan      *TrojanNode
	Tuic        *TuicNode
	AnyTls      *AnyTlsNode
	Hysteria    *HysteriaNode
	Hysteria2   *Hysteria2Node
	Common      *CommonNode
}

type CommonNode struct {
	Host       string      `json:"host"`
	ServerPort int         `json:"server_port"`
	ServerName string      `json:"server_name"`
	Routes     []Route     `json:"routes"`
	BaseConfig *BaseConfig `json:"base_config"`
}

type Route struct {
	Id          int         `json:"id"`
	Match       interface{} `json:"match"`
	Action      string      `json:"action"`
	ActionValue string      `json:"action_value"`
}
type BaseConfig struct {
	PushInterval any `json:"push_interval"`
	PullInterval any `json:"pull_interval"`
}

// VAllssNode is vmess and vless node info
type VAllssNode struct {
	CommonNode
	Tls                 int             `json:"tls"`
	TlsSettings         TlsSettings     `json:"tls_settings"`
	TlsSettingsBack     *TlsSettings    `json:"tlsSettings"`
	Network             string          `json:"network"`
	NetworkSettings     json.RawMessage `json:"network_settings"`
	NetworkSettingsBack json.RawMessage `json:"networkSettings"`
	Encryption          string          `json:"encryption"`
	EncryptionSettings  EncSettings     `json:"encryption_settings"`
	ServerName          string          `json:"server_name"`

	// vless only
	Flow          string        `json:"flow"`
	RealityConfig RealityConfig `json:"-"`
}

type TlsSettings struct {
	ServerName  string   `json:"server_name"`
	ServerNames []string `json:"server_names"`
	Dest        string   `json:"dest"`
	ServerPort  string   `json:"server_port"`
	ShortId     string   `json:"short_id"`
	ShortIds    []string `json:"short_ids"`
	PrivateKey  string   `json:"private_key"`
	Mldsa65Seed string   `json:"mldsa65Seed"`
	Xver        uint64   `json:"xver,string"`
}

func (t TlsSettings) EffectiveServerNames() []string {
	if len(t.ServerNames) > 0 {
		return t.ServerNames
	}
	if t.ServerName == "" {
		return nil
	}
	return []string{t.ServerName}
}

func (t TlsSettings) EffectiveShortIds() []string {
	if len(t.ShortIds) > 0 {
		return t.ShortIds
	}
	if t.ShortId == "" {
		return nil
	}
	return []string{t.ShortId}
}

func (t TlsSettings) PrimaryServerName() string {
	serverNames := t.EffectiveServerNames()
	if len(serverNames) == 0 {
		return ""
	}
	return serverNames[0]
}

type EncSettings struct {
	Mode          string `json:"mode"`
	Ticket        string `json:"ticket"`
	ServerPadding string `json:"server_padding"`
	PrivateKey    string `json:"private_key"`
}

type RealityConfig struct {
	Xver         uint64 `json:"Xver"`
	MinClientVer string `json:"MinClientVer"`
	MaxClientVer string `json:"MaxClientVer"`
	MaxTimeDiff  string `json:"MaxTimeDiff"`
}

type ShadowsocksNode struct {
	CommonNode
	Cipher    string `json:"cipher"`
	ServerKey string `json:"server_key"`
}

type TrojanNode struct {
	CommonNode
	Network         string          `json:"network"`
	NetworkSettings json.RawMessage `json:"networkSettings"`
}

type TuicNode struct {
	CommonNode
	CongestionControl string `json:"congestion_control"`
	ZeroRTTHandshake  bool   `json:"zero_rtt_handshake"`
}

type AnyTlsNode struct {
	CommonNode
	PaddingScheme []string `json:"padding_scheme,omitempty"`
}

type HysteriaNode struct {
	CommonNode
	UpMbps   int    `json:"up_mbps"`
	DownMbps int    `json:"down_mbps"`
	Obfs     string `json:"obfs"`
}

type Hysteria2Node struct {
	CommonNode
	Ignore_Client_Bandwidth bool   `json:"ignore_client_bandwidth"`
	UpMbps                  int    `json:"up_mbps"`
	DownMbps                int    `json:"down_mbps"`
	ObfsType                string `json:"obfs"`
	ObfsPassword            string `json:"obfs-password"`
}

type RawDNS struct {
	DNSMap  map[string]map[string]interface{}
	DNSJson []byte
}

type Rules struct {
	Regexp   []string
	Protocol []string
}

func (c *Client) GetNodeInfo() (node *NodeInfo, err error) {
	const path = "/api/v1/server/UniProxy/config"
	r, err := c.client.
		R().
		SetHeader("If-None-Match", c.nodeEtag).
		ForceContentType("application/json").
		Get(path)

	if r.StatusCode() == 304 {
		return nil, nil
	}
	hash := sha256.Sum256(r.Body())
	newBodyHash := hex.EncodeToString(hash[:])
	if c.responseBodyHash == newBodyHash {
		return nil, nil
	}
	c.responseBodyHash = newBodyHash
	c.nodeEtag = r.Header().Get("ETag")
	if err = c.checkResponse(r, path, err); err != nil {
		return nil, err
	}

	if r != nil {
		defer func() {
			if r.RawBody() != nil {
				r.RawBody().Close()
			}
		}()
	} else {
		return nil, fmt.Errorf("received nil response")
	}
	node = &NodeInfo{
		Id:   c.NodeId,
		Type: c.NodeType,
		RawDNS: RawDNS{
			DNSMap:  make(map[string]map[string]interface{}),
			DNSJson: []byte(""),
		},
	}
	// parse protocol params
	var cm *CommonNode
	switch c.NodeType {
	case "v2node":
		type V2NodeResponse struct {
			Protocol              string          `json:"protocol"`
			ListenIP              string          `json:"listen_ip"`
			ServerPort            int             `json:"server_port"`
			Routes                []Route         `json:"routes"`
			BaseConfig            *BaseConfig     `json:"base_config"`
			Tls                   int             `json:"tls"`
			TlsSettings           TlsSettings     `json:"tls_settings"`
			Network               string          `json:"network"`
			NetworkSettings       json.RawMessage `json:"network_settings"`
			Encryption            string          `json:"encryption"`
			EncryptionSettings    EncSettings     `json:"encryption_settings"`
			ServerName            string          `json:"server_name"`
			Flow                  string          `json:"flow"`
			Cipher                string          `json:"cipher"`
			ServerKey             string          `json:"server_key"`
			CongestionControl     string          `json:"congestion_control"`
			ZeroRTTHandshake      bool            `json:"zero_rtt_handshake"`
			PaddingScheme         []string        `json:"padding_scheme,omitempty"`
			UpMbps                int             `json:"up_mbps"`
			DownMbps              int             `json:"down_mbps"`
			Obfs                  string          `json:"obfs"`
			ObfsPassword          string          `json:"obfs_password"`
			IgnoreClientBandwidth bool            `json:"ignore_client_bandwidth"`
		}
		rsp := &V2NodeResponse{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode v2node params error: %s", err)
		}
		node.Type = rsp.Protocol
		switch rsp.Protocol {
		case "vless", "vmess":
			vallss := &VAllssNode{
				CommonNode: CommonNode{
					ServerPort: rsp.ServerPort,
					ServerName: rsp.ServerName,
					Routes:     rsp.Routes,
					BaseConfig: rsp.BaseConfig,
				},
				Tls:                rsp.Tls,
				TlsSettings:        rsp.TlsSettings,
				Network:            rsp.Network,
				NetworkSettings:    rsp.NetworkSettings,
				Encryption:         rsp.Encryption,
				EncryptionSettings: rsp.EncryptionSettings,
				Flow:               rsp.Flow,
			}
			cm = &vallss.CommonNode
			node.VAllss = vallss
			node.Security = rsp.Tls
		case "trojan":
			trojan := &TrojanNode{
				CommonNode: CommonNode{
					ServerPort: rsp.ServerPort,
					ServerName: rsp.ServerName,
					Routes:     rsp.Routes,
					BaseConfig: rsp.BaseConfig,
				},
				Network:         rsp.Network,
				NetworkSettings: rsp.NetworkSettings,
			}
			cm = &trojan.CommonNode
			node.Trojan = trojan
			node.Security = rsp.Tls
		case "shadowsocks":
			ss := &ShadowsocksNode{
				CommonNode: CommonNode{
					ServerPort: rsp.ServerPort,
					ServerName: rsp.ServerName,
					Routes:     rsp.Routes,
					BaseConfig: rsp.BaseConfig,
				},
				Cipher:    rsp.Cipher,
				ServerKey: rsp.ServerKey,
			}
			cm = &ss.CommonNode
			node.Shadowsocks = ss
			node.Security = None
		case "hysteria2":
			hy2 := &Hysteria2Node{
				CommonNode: CommonNode{
					ServerPort: rsp.ServerPort,
					ServerName: rsp.ServerName,
					Routes:     rsp.Routes,
					BaseConfig: rsp.BaseConfig,
				},
				UpMbps:                  rsp.UpMbps,
				DownMbps:                rsp.DownMbps,
				ObfsType:                rsp.Obfs,
				ObfsPassword:            rsp.ObfsPassword,
				Ignore_Client_Bandwidth: rsp.IgnoreClientBandwidth,
			}
			cm = &hy2.CommonNode
			node.Hysteria2 = hy2
			node.Security = rsp.Tls
		case "tuic":
			tuic := &TuicNode{
				CommonNode: CommonNode{
					ServerPort: rsp.ServerPort,
					ServerName: rsp.ServerName,
					Routes:     rsp.Routes,
					BaseConfig: rsp.BaseConfig,
				},
				CongestionControl: rsp.CongestionControl,
				ZeroRTTHandshake:  rsp.ZeroRTTHandshake,
			}
			cm = &tuic.CommonNode
			node.Tuic = tuic
			node.Security = rsp.Tls
		case "anytls":
			anytls := &AnyTlsNode{
				CommonNode: CommonNode{
					ServerPort: rsp.ServerPort,
					ServerName: rsp.ServerName,
					Routes:     rsp.Routes,
					BaseConfig: rsp.BaseConfig,
				},
				PaddingScheme: rsp.PaddingScheme,
			}
			cm = &anytls.CommonNode
			node.AnyTls = anytls
			node.Security = rsp.Tls
		default:
			return nil, fmt.Errorf("unsupported protocol from v2node: %s", rsp.Protocol)
		}
	case "vmess", "vless":
		rsp := &VAllssNode{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode v2ray params error: %s", err)
		}
		if len(rsp.NetworkSettingsBack) > 0 {
			rsp.NetworkSettings = rsp.NetworkSettingsBack
			rsp.NetworkSettingsBack = nil
		}
		if rsp.TlsSettingsBack != nil {
			rsp.TlsSettings = *rsp.TlsSettingsBack
			rsp.TlsSettingsBack = nil
		}
		cm = &rsp.CommonNode
		node.VAllss = rsp
		node.Security = node.VAllss.Tls
	case "shadowsocks":
		rsp := &ShadowsocksNode{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode shadowsocks params error: %s", err)
		}
		cm = &rsp.CommonNode
		node.Shadowsocks = rsp
		node.Security = None
	case "trojan":
		rsp := &TrojanNode{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode trojan params error: %s", err)
		}
		cm = &rsp.CommonNode
		node.Trojan = rsp
		node.Security = Tls
	case "tuic":
		rsp := &TuicNode{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode tuic params error: %s", err)
		}
		cm = &rsp.CommonNode
		node.Tuic = rsp
		node.Security = Tls
	case "anytls":
		rsp := &AnyTlsNode{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode anytls params error: %s", err)
		}
		cm = &rsp.CommonNode
		node.AnyTls = rsp
		node.Security = Tls
	case "hysteria":
		rsp := &HysteriaNode{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode hysteria params error: %s", err)
		}
		cm = &rsp.CommonNode
		node.Hysteria = rsp
		node.Security = Tls
	case "hysteria2":
		rsp := &Hysteria2Node{}
		err = json.Unmarshal(r.Body(), rsp)
		if err != nil {
			return nil, fmt.Errorf("decode hysteria2 params error: %s", err)
		}
		cm = &rsp.CommonNode
		node.Hysteria2 = rsp
		node.Security = Tls
	}

	// parse rules and dns
	for i := range cm.Routes {
		var matchs []string
		if _, ok := cm.Routes[i].Match.(string); ok {
			matchs = strings.Split(cm.Routes[i].Match.(string), ",")
		} else if _, ok = cm.Routes[i].Match.([]string); ok {
			matchs = cm.Routes[i].Match.([]string)
		} else {
			temp := cm.Routes[i].Match.([]interface{})
			matchs = make([]string, len(temp))
			for i := range temp {
				matchs[i] = temp[i].(string)
			}
		}
		switch cm.Routes[i].Action {
		case "block":
			for _, v := range matchs {
				if strings.HasPrefix(v, "protocol:") {
					// protocol
					node.Rules.Protocol = append(node.Rules.Protocol, strings.TrimPrefix(v, "protocol:"))
				} else {
					// domain
					node.Rules.Regexp = append(node.Rules.Regexp, strings.TrimPrefix(v, "regexp:"))
				}
			}
		case "dns":
			var domains []string
			domains = append(domains, matchs...)
			if matchs[0] != "main" {
				node.RawDNS.DNSMap[strconv.Itoa(i)] = map[string]interface{}{
					"address": cm.Routes[i].ActionValue,
					"domains": domains,
				}
			} else {
				dns := []byte(strings.Join(matchs[1:], ""))
				node.RawDNS.DNSJson = dns
			}
		}
	}

	// set interval
	node.PushInterval = intervalToTime(cm.BaseConfig.PushInterval)
	node.PullInterval = intervalToTime(cm.BaseConfig.PullInterval)

	node.Common = cm

	return node, nil
}

func intervalToTime(i interface{}) time.Duration {
	switch reflect.TypeOf(i).Kind() {
	case reflect.Int:
		return time.Duration(i.(int)) * time.Second
	case reflect.String:
		i, _ := strconv.Atoi(i.(string))
		return time.Duration(i) * time.Second
	case reflect.Float64:
		return time.Duration(i.(float64)) * time.Second
	default:
		return time.Duration(reflect.ValueOf(i).Int()) * time.Second
	}
}
