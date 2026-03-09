# UM Sesame

![Uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F2%2F5dc8204f-c053-4711-a9b4-c912ac52476c.shields)

> 上方徽章顯示作者路由器的即時連線狀態，由 [Healthchecks.io](https://healthchecks.io) 監測——綠色表示網路正常（腳本正常運作），紅色表示離線或認證失敗。

自動化校園網 Captive Portal 登入腳本。偵測網路是否被門戶攔截，自動提交帳號密碼完成認證，搭配 cron 可實現斷線自動重連。

> [简体中文版](README_CN.md) | [English version](README_EN.md)

## 為什麼需要這個？

部分物聯網設備（如智慧家電、印表機等）不支援 WPA2-Enterprise 的 MSCHAPv2/PEAP 認證方式，無法連接類似 `UM_SECURED_WLAN` 這類企業級加密的校園 Wi-Fi。退而求其次只能連接 Portal 認證的開放網路（如 `UM_WLAN_PORTAL`），但每次斷線都要手動開瀏覽器登入。

這個腳本就是為了解決這個問題——部署在路由器上，讓路由器自動完成 Portal 認證，下掛的所有設備直接上網。

## 運作原理

1. 訪問公開的連線測試 URL（Firefox / Microsoft），檢查是否被重導向至門戶頁面
2. 追蹤重導向鏈，取得最終認證頁面的 URL
3. 從 URL 中解析動態參數（`pushPageId`、`ssid`、`uaddress` 等）
4. 構建 POST 請求，向門戶伺服器提交登入憑證
5. 檢查回應中的 `"success":true` 確認登入結果

## 需求

- POSIX 相容的 shell（`sh`、`bash`、`ash` 等）
- `curl`
- `logger`（用於寫入 syslog，大多數 Linux 發行版內建）

## 安裝與設定

腳本設計在路由器（OpenWrt 等）或任何 Linux 設備上運行。路由器通常沒有 `git`，直接下載即可：

```sh
# 方法一：直接下載
wget https://github.com/Victor-Quqi/um-sesame/archive/refs/heads/main.tar.gz
tar xzf main.tar.gz
mv um-sesame-main um-sesame
cd um-sesame

# 方法二：如果有 git
git clone https://github.com/Victor-Quqi/um-sesame.git
cd um-sesame
```

```sh
# 建立設定檔
cp .env.example .env

# 編輯你的帳號密碼與登入 URL
vi .env

# 賦予執行權限
chmod +x portal_login.sh check_connection.sh
```

`.env` 範例：

```
USERNAME=你的帳號
PASSWORD=你的密碼
LOGIN_URL=https://your.portal.server/portalauth/login
```

## 使用方式

### 自動重連（cron）

`check_connection.sh` 會檢查網路連線，斷線時自動觸發登入。透過 cron 定期執行即可實現自動重連：

```sh
crontab -e
```

加入以下內容（每 5 分鐘檢查一次）：

```
*/5 * * * * /path/to/um-sesame/check_connection.sh
```

儲存退出後立即生效。

或者，你也可以直接編輯 crontab 檔案，一般位於 `/var/spool/cron/crontabs/<使用者名稱>`（Debian/Ubuntu）或 `/var/spool/cron/<使用者名稱>`（RHEL/CentOS/OpenWrt），編輯完後執行 `service cron reload` 或 `systemctl reload cron` 使其生效。

### 手動執行

```sh
./portal_login.sh
```

### 查看日誌

```sh
# 登入記錄（OpenWrt）
logread | grep "PortalLogin"

# 登入記錄（Debian/Ubuntu 等）
grep "PortalLogin" /var/log/syslog

# 詳細的除錯日誌
cat /tmp/portal_debug.log
```

## 適配其他學校

本腳本最初為華為 Captive Portal 認證系統開發。如果你的學校使用不同的門戶系統，可能需要修改 `portal_login.sh` 中的 POST 請求參數以匹配你的門戶頁面表單欄位。

## 安全注意事項

- **TLS 驗證**：腳本依賴 curl 的標準憑證校驗與主機名校驗。如果系統不信任你的門戶憑證，認證可能會失敗；如果改回 insecure 模式，則會重新引入中間人攻擊風險。
- **密碼儲存**：帳號密碼以明文存放在 `.env` 中。請確保 `.env` 的檔案權限為 `600`（`chmod 600 .env`）。
- **除錯日誌**：日誌檔案 `/tmp/portal_debug.log` 已自動設為 `600` 權限，僅檔案擁有者可讀取。日誌中的密碼會以 `***` 遮蔽。
- **路由器環境**：路由器通常為單用戶（root）環境，上述檔案權限的風險較低，但若有其他使用者透過 SSH 存取路由器，仍應留意。

## 授權條款

[MIT License](LICENSE)
