# xiaov2bXray - 现代化高可用多协议节点服务端

基于 **Xray + Sing-box 双内核** 的新一代 V2board 节点服务端，融合了 V2bX 的协议扩展性与 v2node 的极简自适应架构。

---

## 一、 核心特点与架构优势

1. **双内核架构（去糟粕，留精华）**：
   * **Xray 核心**：承载 VLESS (Vision/Reality/XHTTP/后量子 PQ)、VMess、Trojan、Shadowsocks 等主流高性能直连。
   * **Sing-box 核心**：承载 Hysteria 2、TUIC、AnyTLS 等特殊协议，按需自动分发。
   * **移除冗余**：彻底砍掉臃肿无用的孤岛 `hy2` 内核，体积立减 34MB，依赖大幅精简。
2. **零配置协议自适应（面板云端驱动）**：
   * 采用统一的 `node_type: v2node` 面板通讯协议。
   * 本地 `config.json` 极简，无需指定节点协议类型。面板后台改协议，节点拉取后**自动热重载生效，无需连 SSH**。
3. **审计与分流全由面板接管**：
   * 支持面板下发 `Routes` 规则：
     * `block` / `block_ip` / `block_port`：拦截指定域名、恶意 IP、25 邮件端口、BT 协议。
     * `route` / `default_out`：针对特定流媒体或全局出站套落地机 Socks5 / SS / WARP。
4. **全面排雷修复**：
   * 修复原版 Sing-box TCP 流量覆盖式计费 Bug（`Store -> Add`）。
   * 修复 Xray LinkManager 高并发断流时的 map 并发 Panic 崩溃。
   * 修复节点变更时 Limiter 重建失效导致的拒连 Bug。
   * 支持 `compareUserList` 拆分 `modified` 状态：用户修改限速/设备数**不断流、不踢下线**。
   * 支持 `DeviceOnlineMinTraffic` 流量门槛过滤，探针、Ping 测试不计入在线设备。
   * 原生兼容 Multi-SNI 与 Multi-ShortID 切片解析。

---

## 二、 编译指南（Windows 本地）

项目根目录下已准备好 `build.bat`，在 Windows 终端中执行：

```powershell
$env:GOOS="linux"; $env:GOARCH="amd64"; $env:GOEXPERIMENT="jsonv2"; go build -v -tags "sing xray" -trimpath -ldflags "-s -w -buildid=" -o xiaov2bXray .
```
或者直接双击运行 `build.bat`，即可一键生成 Linux amd64 平台的单文件可执行二进制 `xiaov2bXray`。

---

## 三、 安装与部署（Linux VPS）

### 方式 1：本地编译后直接上传安装（离线自建，最方便）
1. 在本地 Windows 编译生成 `xiaov2bXray` 二进制文件。
2. 将项目中的 `xiaov2bXray` 文件和 `script/` 文件夹上传到 VPS 同一目录下。
3. 在 VPS 上执行：
   ```bash
   bash script/install.sh
   ```
4. 脚本会自动识别本地二进制，交互式引导输入：
   * 面板域名（如 `https://panel.example.com`）
   * 节点 ID（如 `1`）
   * 节点 API 密钥（ApiKey）
5. 脚本自动安装 systemd 服务并启动，完成部署！

### 方式 2：推送到 GitHub 后一键联网安装
将本项目推送到你自己的 GitHub 仓库后，在任意 VPS 上执行：
```bash
curl -Ls https://raw.githubusercontent.com/你的用户名/xiaov2bXray/main/script/install.sh | bash
```

---

## 四、 节点服务日常管理

安装完成后，可通过系统全局命令快捷管理：

```bash
xiaov2bXray status   # 查看运行状态
xiaov2bXray log      # 查看实时运行日志
xiaov2bXray restart  # 重启服务
xiaov2bXray start    # 启动服务
xiaov2bXray stop     # 停止服务
```

* 配置文件路径：`/etc/xiaov2bXray/config.json`
* 程序安装路径：`/usr/local/xiaov2bXray/`
