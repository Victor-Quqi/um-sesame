# UM Sesame

![Uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F2%2F5dc8204f-c053-4711-a9b4-c912ac52476c.shields)

> 上方徽章显示作者路由器的实时连线状态，由 [Healthchecks.io](https://healthchecks.io) 监测——绿色表示网络正常（脚本正常工作），红色表示离线或认证失败。

自动化校园网 Captive Portal 登录脚本。检测网络是否被门户拦截，自动提交账号密码完成认证，搭配 cron 可实现断线自动重连。

> [繁體中文版](README.md) | [English version](README_EN.md)

## 为什么需要这个？

部分物联网设备（如智能家电、打印机等）不支持 WPA2-Enterprise 的 MSCHAPv2/PEAP 认证方式，无法连接类似 `UM_SECURED_WLAN` 这类企业级加密的校园 Wi-Fi。退而求其次只能连接 Portal 认证的开放网络（如 `UM_WLAN_PORTAL`），但每次断线都要手动开浏览器登录。

这个脚本就是为了解决这个问题——部署在路由器上，让路由器自动完成 Portal 认证，下挂的所有设备直接上网。

## 工作原理

1. 访问公开的连接测试 URL（Firefox / Microsoft），检查是否被重定向至门户页面
2. 追踪重定向链，获取最终认证页面的 URL
3. 从 URL 中解析动态参数（`pushPageId`、`ssid`、`uaddress` 等）
4. 构建 POST 请求，向门户服务器提交登录凭证
5. 检查响应中的 `"success":true` 确认登录结果

## 需求

- POSIX 兼容的 shell（`sh`、`bash`、`ash` 等）
- `curl`
- `logger`（用于写入 syslog，大多数 Linux 发行版内置）

## 安装与配置

脚本设计在路由器（OpenWrt 等）或任何 Linux 设备上运行。路由器通常没有 `git`，直接下载即可：

```sh
# 方法一：直接下载
wget https://github.com/Victor-Quqi/um-sesame/archive/refs/heads/main.tar.gz
tar xzf main.tar.gz
mv um-sesame-main um-sesame
cd um-sesame

# 方法二：如果有 git
git clone https://github.com/Victor-Quqi/um-sesame.git
cd um-sesame
```

```sh
# 创建配置文件
cp .env.example .env

# 编辑你的账号密码与登录 URL
vi .env

# 赋予执行权限
chmod +x portal_login.sh check_connection.sh
```

`.env` 示例：

```
USERNAME=你的账号
PASSWORD=你的密码
LOGIN_URL=https://your.portal.server/portalauth/login
```

## 使用方式

### 自动重连（cron）

`check_connection.sh` 会检查网络连接，断线时自动触发登录。通过 cron 定期执行即可实现自动重连：

```sh
crontab -e
```

加入以下内容（每 5 分钟检查一次）：

```
*/5 * * * * /path/to/um-sesame/check_connection.sh
```

保存退出后立即生效。

或者，你也可以直接编辑 crontab 文件，一般位于 `/var/spool/cron/crontabs/<用户名>`（Debian/Ubuntu）或 `/var/spool/cron/<用户名>`（RHEL/CentOS/OpenWrt），编辑完后执行 `service cron reload` 或 `systemctl reload cron` 使其生效。

### 手动执行

```sh
./portal_login.sh
```

### 查看日志

```sh
# 登录记录（OpenWrt）
logread | grep "PortalLogin"

# 登录记录（Debian/Ubuntu 等）
grep "PortalLogin" /var/log/syslog

# 详细的调试日志
cat /tmp/portal_debug.log
```

## 适配其他学校

本脚本最初为华为 Captive Portal 认证系统开发。如果你的学校使用不同的门户系统，可能需要修改 `portal_login.sh` 中的 POST 请求参数以匹配你的门户页面表单字段。

## 安全注意事项

- **TLS 验证**：脚本依赖 curl 的标准证书校验与主机名校验。如果系统不信任你的门户证书，认证可能会失败；如果改回 insecure 模式，则会重新引入中间人攻击风险。
- **密码存储**：账号密码以明文存放在 `.env` 中。请确保 `.env` 的文件权限为 `600`（`chmod 600 .env`）。
- **调试日志**：日志文件 `/tmp/portal_debug.log` 已自动设为 `600` 权限，仅文件所有者可读取。日志中的密码会以 `***` 遮蔽。
- **路由器环境**：路由器通常为单用户（root）环境，上述文件权限的风险较低，但若有其他用户通过 SSH 访问路由器，仍应留意。

## 许可证

[MIT License](LICENSE)
