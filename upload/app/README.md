# CSV 檔案上傳程式

此程式用於將 CSV 檔案上傳到商店 API 系統。

## 功能特色

- ✅ 支援命令行參數
- ✅ **安全的設定檔管理** (從設定檔讀取 Token)
- ✅ 多重認證方式 (設定檔/命令行/環境變數)
- ✅ 完整的錯誤處理
- ✅ JSON 回應解析
- ✅ 詳細的上傳結果顯示
- ✅ 支援詳細模式 (verbose)
- ✅ 完整的幫助信息

## 系統需求

需要安裝以下 Perl 模組：

```bash
cpan LWP::UserAgent HTTP::Request::Common JSON Getopt::Long
```

## 設定檔配置

### 1. 複製設定檔範例

```bash
cp config.json.example config.json
```

### 2. 編輯設定檔

```json
{
  "auth_token": "your-actual-api-token",
  "api_url": "http://127.0.0.1:5120/api/v1/upload/add_shop"
}
```

## 使用方法

### 基本用法 (推薦)

```bash
perl upload_csv.pl -f shop_data.csv
```

### 使用自訂設定檔

```bash
perl upload_csv.pl -f shop_data.csv -c my_config.json
```

### 覆蓋設定檔參數

```bash
perl upload_csv.pl -f shop_data.csv -a "override-token" -v
```

### 使用環境變數

```bash
export API_TOKEN="your-token"
perl upload_csv.pl -f shop_data.csv
```

## 參數說明

| 參數 | 長參數      | 說明                           | 必要 |
| ---- | ----------- | ------------------------------ | ---- |
| `-f` | `--file`    | CSV 檔案路徑                   | ✅   |
| `-c` | `--config`  | 設定檔路徑 (預設：config.json) | ❌   |
| `-a` | `--auth`    | API 認證 Token (覆蓋設定檔)    | ❌   |
| `-u` | `--url`     | API 端點 (覆蓋設定檔)          | ❌   |
| `-v` | `--verbose` | 顯示詳細執行資訊               | ❌   |
| `-h` | `--help`    | 顯示幫助信息                   | ❌   |

## 認證 Token 優先權

程式會依照以下順序尋找認證 Token：

1. **命令行參數** (`-a`, `--auth`) - 最高優先權
2. **設定檔** (`auth_token` 欄位) - 推薦方式
3. **環境變數** (`API_TOKEN`) - 備選方案

## 安全性建議

- ✅ **推薦**：使用設定檔存放 Token
- ✅ **可接受**：使用環境變數
- ❌ **不推薦**：在命令行直接輸入 Token (會被記錄在 shell 歷史中)

## 檔案結構

```
upload/app/
├── upload_csv.pl          # 主程式
├── config.json.example    # 設定檔範例
├── config.json           # 實際設定檔 (需自行創建)
└── README.md             # 說明文檔
```

## 回應格式

程式會解析 API 回應並顯示：

- 上傳狀態
- 商店 ID
- 詳細訊息
- 錯誤數量
- 分公司資料

## 錯誤處理

程式會檢查：

- 檔案是否存在
- 檔案格式是否為 CSV
- 設定檔格式是否正確
- HTTP 請求狀態
- JSON 回應格式
- **特別處理 HTTP 422 錯誤** (CSV 格式檢查失敗)

## 範例輸出

### 成功上傳

```
載入設定檔：config.json
開始上傳 CSV 檔案...
檔案：shop_data.csv
發送請求中...
==================================================
上傳結果：
==================================================
✅ 檔案上傳成功

詳細資訊：
  商店 ID：120
  狀態：成功
  訊息：商店與商品資料已成功上傳
  錯誤數：0
  分公司資料：沒有分公司資料需要新增
  分公司筆數：0

上傳完成！
```

### 設定檔錯誤

```
錯誤：缺少認證 Token！
請透過以下方式之一提供 Token：
  1. 設定檔 (config.json) 中的 auth_token 欄位
  2. 命令行參數 -a 或 --auth
  3. 環境變數 API_TOKEN
```

### CSV 格式錯誤 (422)

```
❌ HTTP 請求失敗：
狀態碼：422
錯誤訊息：Unprocessable Entity

📄 CSV 檔案格式錯誤 (422 Unprocessable Entity)
檔案內容經檢查後發現格式不符API規範

📋 詳細錯誤資訊：
  訊息：菜單檔案上傳失敗：CSV格式不正確
  錯誤類型：菜單處理錯誤

📊 檔案處理詳情：
  處理訊息：欄位格式驗證失敗
  具體錯誤：必要欄位 'shop_name' 缺失

🔧 建議檢查項目：
  • CSV 檔案編碼是否為 UTF-8
  • 欄位分隔符號是否正確 (通常為逗號)
  • 必要欄位是否缺失或格式錯誤
  • 資料內容是否符合 API 規範
  • 檔案是否有非法字符或格式問題
```
