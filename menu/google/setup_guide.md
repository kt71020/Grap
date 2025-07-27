# Google Cloud DocumentAI 認證設定指南

## 🚨 **為什麼會出現認證錯誤？**

```
google.auth.exceptions.DefaultCredentialsError: Your default credentials were not found.
```

這個錯誤代表你還沒有設置 Google Cloud 的認證憑證。DocumentAI 是付費 API，需要正確的身份驗證才能使用。

## 🛠️ **解決方案**

### 方案一：使用測試版本（推薦先試這個）

```bash
cd menu/google
python3 test_parse.py
```

這會使用模擬資料測試程式邏輯，不需要 Google Cloud 認證。

### 方案二：正確設置 Google Cloud 認證

#### 步驟 1: 建立 Google Cloud 專案

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 建立新專案或選擇現有專案
3. 記下你的 **Project ID**

#### 步驟 2: 啟用 Document AI API

```bash
# 使用 gcloud CLI (如果有安裝的話)
gcloud services enable documentai.googleapis.com

# 或者到 Console 手動啟用
# https://console.cloud.google.com/apis/library/documentai.googleapis.com
```

#### 步驟 3: 建立 Document AI 處理器

1. 前往 [Document AI Console](https://console.cloud.google.com/ai/document-ai)
2. 建立新的 **Form Parser** 處理器
3. 選擇地區（例如：us、eu）
4. 記下 **Processor ID**

#### 步驟 4: 建立服務帳戶

1. 前往 [IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
2. 點擊「**建立服務帳戶**」
3. 填入基本資訊：
   - 服務帳戶名稱：例如 `documentai-service`
   - 說明：DocumentAI API 存取用
4. 授予角色：
   - `Document AI API User`
   - 或 `Editor`（更廣泛的權限）
5. 點擊「**完成**」

#### 步驟 5: 下載金鑰檔案

1. 點擊剛建立的服務帳戶
2. 切換到「**金鑰**」標籤
3. 點擊「**新增金鑰**」> 「**建立新金鑰**」
4. 選擇 **JSON** 格式
5. 下載金鑰檔案，例如：`documentai-service-key.json`

#### 步驟 6: 設定環境變數

**MacOS/Linux:**

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/Users/kt/kcode/key/DocumentAI/documentai-service-key.json"

# 加入到 ~/.zshrc 或 ~/.bashrc 讓設定永久生效
echo 'export GOOGLE_APPLICATION_CREDENTIALS="/Users/kt/kcode/key/DocumentAI/documentai-service-key.json"' >> ~/.zshrc
```

**Windows:**

```cmd
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\your\documentai-service-key.json

# 或使用 PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your\documentai-service-key.json"
```

#### 步驟 7: 更新程式設定

修改 `parse.py` 中的設定：

```python
# 替換為你的實際值
project_id = "your-actual-project-id"
location = "us"  # 或你選擇的地區
processor_id = "your-actual-processor-id"
```

#### 步驟 8: 測試連線

```bash
# 測試認證是否正確
python3 -c "from google.cloud import documentai; client = documentai.DocumentProcessorServiceClient(); print('認證成功！')"
```

## 💰 **費用考量**

Document AI Form Parser 收費標準（2024）：

- 前 1,000 頁/月：免費
- 超過部分：每頁 $0.05 USD

對於測試用途，免費額度通常足夠。

## 🧪 **現在可以做什麼**

### 1. 先測試程式邏輯

```bash
python3 test_parse.py
```

### 2. 確認認證後使用真實 API

```bash
python3 parse.py
```

## 🔧 **替代方案**

如果不想設置 Google Cloud，可以考慮：

1. **使用開源 OCR**：

   - Tesseract + OpenCV
   - EasyOCR
   - PaddleOCR

2. **其他商業 API**：
   - Microsoft Azure Computer Vision
   - AWS Textract
   - IBM Watson Visual Recognition

## ❗ **常見錯誤排解**

### 錯誤 1: 找不到憑證檔案

```
FileNotFoundError: [Errno 2] No such file or directory
```

**解決**：確認 `GOOGLE_APPLICATION_CREDENTIALS` 路徑正確

### 錯誤 2: 權限不足

```
google.api_core.exceptions.PermissionDenied: 403
```

**解決**：檢查服務帳戶是否有 Document AI API User 權限

### 錯誤 3: 處理器不存在

```
google.api_core.exceptions.NotFound: 404 The processor does not exist
```

**解決**：檢查 project_id、location、processor_id 是否正確

## 💡 **專業建議**

1. **先用測試版本**驗證程式邏輯
2. **小批量測試**真實 API 避免超額收費
3. **備份金鑰檔案**但不要放在版本控制系統中
4. **定期檢查使用量**避免意外費用

現在先執行 `python3 test_parse.py` 看看程式邏輯是否正確吧！
