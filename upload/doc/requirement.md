# 商店 csv 檔案上傳

呼叫 API 並上傳 CSV 檔案進行商店新增

## 執行程式 Perl

upload_csv.pl

## API

http://127.0.0.1:5120/api/v1/upload/add_shop

### API 參數

- Headers:Authorization
- Body:form-data file

### 回傳值

```json
{
  "message": "檔案上傳成功",
  "status": 1,
  "upload_shop": {
    "regional": "沒有分公司資料需要新增",
    "sid": 120,
    "status": 1,
    "message": "商店與商品資料已成功上傳",
    "error": 0,
    "regional_id_list": [],
    "rows_regional": 0
  }
}
```
