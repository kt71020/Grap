# DocumentAI to DataFrame 轉換工具

將 Google DocumentAI 的解析結果轉換成結構化的 pandas DataFrame，方便後續資料分析與處理。

## 🎯 功能特色

- **多層次資料結構化**: 將 DocumentAI 回傳的複雜物件轉成多個 DataFrame
- **智慧商品辨識**: 自動從表格中識別商品名稱和價格
- **完整 CSV 輸出**: 所有資料自動儲存為 CSV 檔案
- **詳細分析報告**: 提供菜單資料分析摘要

## 📦 安裝需求

```bash
pip install -r requirements.txt
```

### 必要套件

- `google-cloud-documentai>=2.20.1`
- `pandas>=1.5.0`
- `google-cloud-storage>=2.10.0`

## 🔧 設定

1. **Google Cloud 專案設定**

   - 啟用 Document AI API
   - 建立 Form Parser 處理器
   - 下載服務帳戶金鑰 JSON 檔案

2. **環境變數設定**

   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="path/to/your/service-account-key.json"
   ```

3. **修改設定參數**
   ```python
   # 在 parse.py 中修改以下參數
   project_id = "your-gcp-project-id"
   location = "us"  # 或其他地區
   processor_id = "your-processor-id"
   ```

## 🚀 使用方式

### 基本使用

```python
from parse import document_to_dataframes
from google.cloud import documentai

# 處理圖片並取得 DataFrames
dataframes = document_to_dataframes(document)

# 查看可用的 DataFrame
print(dataframes.keys())
# 輸出: ['tables', 'table_cells', 'form_fields', 'paragraphs', 'lines', 'tokens']
```

### 使用範例腳本

```bash
python example_usage.py
```

### 直接執行解析器

```bash
python parse.py
```

## 📊 輸出資料結構

### 1. Tables DataFrame

```csv
page,table,row,cells,cell_count
0,0,0,"['商品名稱', '價格', '備註']",3
0,0,1,"['牛肉麵', '120', '大碗']",3
```

### 2. Table Cells DataFrame

```csv
page,table,row,column,content
0,0,0,0,商品名稱
0,0,0,1,價格
0,0,1,0,牛肉麵
0,0,1,1,120
```

### 3. Form Fields DataFrame

```csv
page,field_index,key,value
0,0,店名,老地方牛肉麵
0,1,電話,02-12345678
0,2,地址,台北市士林區xxx路
```

### 4. Menu Items DataFrame (自動產生)

```csv
item_name,price,extra_info
牛肉麵,120,大碗
排骨麵,110,小碗
```

## 📁 輸出檔案

執行後會產生以下 CSV 檔案：

- `menu_data_tables.csv` - 表格結構資料
- `menu_data_table_cells.csv` - 展開的表格內容
- `menu_data_form_fields.csv` - 表單欄位
- `menu_data_paragraphs.csv` - 段落文字
- `menu_data_lines.csv` - 行文字
- `menu_data_tokens.csv` - 字詞文字
- `menu_items.csv` - 自動識別的商品清單
- `price_analysis.csv` - 價格分析 (如果有)

## 🔍 進階使用

### 自訂檔案前綴

```python
from parse import save_dataframes_to_csv

# 使用自訂前綴儲存檔案
save_dataframes_to_csv(dataframes, prefix="my_restaurant")
```

### 篩選特定資料

```python
# 只取得有價格資訊的表格行
if 'table_cells' in dataframes:
    cells_df = dataframes['table_cells']
    price_cells = cells_df[cells_df['content'].str.contains(r'\d+', na=False)]
```

### 商店資訊提取

```python
# 從 form_fields 提取商店基本資訊
if 'form_fields' in dataframes:
    fields_df = dataframes['form_fields']
    shop_info = fields_df[fields_df['key'].str.contains('店名|電話|地址', na=False)]
```

## 🐛 常見問題

### 1. 認證錯誤

```
google.auth.exceptions.DefaultCredentialsError
```

**解決方法**: 確認 `GOOGLE_APPLICATION_CREDENTIALS` 環境變數設定正確

### 2. 處理器不存在

```
google.api_core.exceptions.NotFound: 404 The processor does not exist
```

**解決方法**: 檢查 `project_id`、`location`、`processor_id` 是否正確

### 3. 檔案格式不支援

```
ValueError: 不支援的檔案格式
```

**解決方法**: 確認檔案為 JPG、PNG 或 PDF 格式

## 📈 效能優化建議

1. **批次處理**: 對多個檔案使用迴圈處理
2. **記憶體管理**: 處理大檔案時適時清理 DataFrame
3. **快取結果**: 儲存中間結果避免重複處理

## 🤝 貢獻

歡迎提交 Issue 或 Pull Request 來改善此工具！

## 📄 授權

此專案採用 MIT 授權條款。
