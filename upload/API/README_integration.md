# UploadAPI 整合說明

## 概述

已將你的原始 `UploadAPI.pm` 與 `dancer2_api_example.pm` 整合，建立了 `UploadAPI_integrated.pm`。

## 主要改進

### ✅ 已完成的改進

1. **簡化錯誤處理機制**

   - 移除過度複雜的錯誤代碼常數系統
   - 統一使用 `create_error_response()` 和 `create_success_response()`
   - 支援陣列和字串格式的訊息

2. **建立 JWT 驗證中介層**

   - 統一的 `validate_jwt()` 函數
   - 避免每個端點重複驗證邏輯
   - 目前使用模擬驗證（需要啟用真實 JWT）

3. **新增非同步處理能力**

   - 大檔案（>500 行或>50 個分公司）自動切換非同步模式
   - 背景處理程序使用 fork
   - 即時進度追蹤
   - 狀態查詢 API

4. **保留所有原有功能**
   - `/add_shop` - 商店資料上傳
   - `/add_menu` - 菜單 CSV 上傳
   - `/upload_menu` - 圖片菜單上傳與 OCR 處理
   - `/generate_shop_csv` - CSV 生成
   - `/shop_csv/:csv_id` - CSV 下載

### 🔧 需要手動啟用的功能

由於模組依賴問題，以下功能目前被註解，需要手動啟用：

```perl
# 1. 取消註解這些 use 語句
use Schema::Upload;
use Helpers::Utils;
use Helpers::UploadHelper;
use Helpers::ShopHelper;
use Dancer2::Plugin::JWT;

# 2. 取消註解初始化程式碼
my $utils  = new Utils();
my $upload = new Upload(database);

# 3. 替換模擬的 JWT 驗證邏輯
sub validate_jwt {
    my $JWT = jwt;  # 取消註解
    # ... 使用真實的 JWT 驗證邏輯
}
```

## API 端點

### 現有端點（保留原功能）

- `POST /api/v1/upload/add_shop` - 商店資料上傳
- `POST /api/v1/upload/add_menu` - 菜單上傳
- `POST /api/v1/upload/upload_menu` - 圖片菜單上傳
- `POST /api/v1/upload/generate_shop_csv` - 生成 CSV
- `GET /api/v1/upload/shop_csv/:csv_id` - 下載 CSV

### 新增端點

- `POST /api/v1/upload/add_shop_sync` - 商店資料非同步處理上傳
- `GET /api/v1/upload/status/:process_id` - 查詢非同步處理狀態

## 非同步處理流程

### 觸發條件

- 分公司數量 > 50 筆
- CSV 總行數 > 500 行

### 處理階段

1. **20%** - 準備檔案處理
2. **40%** - 處理商店資料
3. **70%** - 執行資料上傳處理
4. **100%** - 完成處理

### 狀態碼

- `status: 1` - 處理完成
- `status: 2` - 處理中
- `status: 0` - 處理失敗

## 使用範例

### 上傳大檔案（自動非同步）

```bash
curl -X POST \
  -H "Authorization: Bearer your-jwt-token" \
  -F "file=@large_shop_data.csv" \
  http://localhost:3000/api/v1/upload/add_shop_csv
```

回應：

```json
{
  "status": 2,
  "process_id": "1640995200_1234",
  "message": ["偵測到大量資料需要處理", "已啟動背景處理程序"],
  "progress": "0%",
  "estimated_time": "2.5 分鐘"
}
```

### 查詢處理狀態

```bash
curl -H "Authorization: Bearer your-jwt-token" \
  http://localhost:3000/api/v1/upload/status/1640995200_1234
```

## 部署注意事項

1. **模組依賴**

   - 確保所有自訂模組存在並可正常載入
   - 安裝 `Dancer2::Plugin::JWT` 如果使用 JWT 驗證

2. **記憶體管理**

   - 目前使用記憶體儲存工作狀態
   - 生產環境建議改用 Redis 或資料庫

3. **檔案權限**

   - 確保上傳目錄可寫入
   - 檢查 `/app/database` 和 `/app/downloads` 權限

4. **程序管理**
   - 背景程序使用 fork，確保系統支援
   - 考慮使用 supervisor 或 systemd 管理服務

## 你原本的問題

> **你的錯誤代碼設計太複雜了** - 用常數定義錯誤代碼，然後又要維護錯誤訊息對應表，這是過度工程化

✅ **已修正**：簡化為直接傳入錯誤訊息，不再使用複雜的常數對應表。

> **JWT 驗證邏輯重複** - 每個端點都在重複同樣的驗證邏輯

✅ **已修正**：建立統一的 `validate_jwt()` 中介層函數。

> **缺乏非同步處理機制** - 對於大檔案上傳，你的程式會阻塞

✅ **已修正**：新增智能判斷機制，大檔案自動使用非同步處理。

現在你的程式碼更簡潔、更有效率，也更容易維護！
