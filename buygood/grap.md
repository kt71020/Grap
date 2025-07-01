# 梁社漢排骨 門市爬蟲

## 網站資訊

- 目標網站：https://www.wu-tau.com/store.php
- 品牌名稱：梁社漢排骨
- 資料來源：官方門市查詢頁面

## 檔案說明

### get_city.pl

- 用途：分析網站結構，取得城市代碼對照表
- 功能：列印城市映射表，確認抓取範圍
- 網址：https://www.buygood.com.tw/StoreList.asp?t=4
- 由 HTM 原始檔取得 city_list

```HTML
<select id="citySelect" name="citySelect" onchange="onCityChange()" class="form-control" style="width:120px;">
    <option value="">請選擇縣市</option>
    <option value="基隆市">基隆市</option>
	<option value="台北市">台北市</option>
	<option value="新北市">新北市</option>
	<option value="桃園市">桃園市</option>
	<option value="新竹市">新竹市</option>
	<option value="新竹縣">新竹縣</option>
	<option value="苗栗縣">苗栗縣</option>
	<option value="台中市">台中市</option>
	<option value="彰化縣">彰化縣</option>
	<option value="南投縣">南投縣</option>
	<option value="雲林縣">雲林縣</option>
	<option value="嘉義市">嘉義市</option>
	<option value="嘉義縣">嘉義縣</option>
	<option value="台南市">台南市</option>
	<option value="高雄市">高雄市</option>
	<option value="屏東縣">屏東縣</option>
	<option value="宜蘭縣">宜蘭縣</option>
	<option value="台東縣">台東縣</option>
	<option value="花蓮縣">花蓮縣</option>
	<option value="金門縣">金門縣</option>

  </select>

```

### grap.pl

- 用途：主要爬蟲程式
- 功能：
  - 爬取各城市的門市資訊
  - 處理分頁資料
  - 輸出個別城市的 CSV 檔案
  - 自動處理電話號碼格式化
- 網址: https://www.buygood.com.tw/StoreList.asp

  - 酬載： cotyselect:台北市 SArea:台北市全區
  - 回應：由以下 HTML 取得：商店名稱：中正南昌店、電話：02-23432361、地址：台北市中正區南昌路一段 153 號

  ```HTML
          <h4><b><font color="#D9534F">中正南昌店 [<a href="Stores.asp?Shop_id=100001">線上訂餐</a>] </font></b></h4>

          <p class="card-text"><i class="fa fa-phone"></i>　訂購專線：<a href="tel:02-23432361">02-23432361</a><br /> <i class="fa fa-clock-o"></i>　營業時間：10:30-20:30</p>
        <p class="card-text"><i class="fa fa-map-marker"></i>台灣 台北市中正區南昌路一段153號</p>

        <a href="https://www.google.com.tw/maps/place/台北市中正區南昌路一段153號" class="btn btn-danger"  target="_blank">查看位置</a>

  ```

  - 依照 city_list 取得所有分店資料

- 將各縣市商店資料存份於 csv/city.csv

### merge.pl

- 用途：合併商店資訊與門市列表
- 功能：
- 合併 csv/\*.csv 存放於 Shop_list.csv（門市列表）
  - 合併 `Shop_info.csv`（商店基本資訊）和 `Shop_list.csv`（門市列表）
  - 產生統一的 `Shop_menu.csv` 完整檔案
  - 顯示各城市門市統計
  - 自動檢查來源檔案存在性

## 資料欄位

```
name,phone,city,region,detailed_address,latitude,longitude
```

### 欄位說明

- **name**: 門市名稱（格式：梁社漢排骨 + 原始店名）
- **phone**: 電話號碼（已格式化為 XX-XXXX-XXXX 或 XX-XXXXXXX）
- **city**: 城市名稱
- **region**: 地區名稱
- **detailed_address**: 詳細地址（已移除城市和地區前綴）
- **latitude**: 緯度（此網站未提供，為空值）
- **longitude**: 經度（此網站未提供，為空值）

## 使用方法

### 1. 執行爬蟲

```bash
perl grap.pl
```

### 2. 合併檔案

```bash
perl merge.pl
```

### 3. 檢視城市對照表

```bash
perl get_city.pl
```

## 注意事項

1. **網站限制**: 程式包含適當的延遲機制避免被封鎖
2. **編碼**: 所有檔案使用 UTF-8 編碼
3. **錯誤處理**: 包含網路錯誤和資料異常的處理
4. **測試模式**: 可在 wutau.pl 中啟用測試模式，只抓取部分城市

## 城市覆蓋範圍

## 輸出檔案

- `csv/城市代碼.csv` - 各城市門市資料
- `Shop_menu.csv` - 合併後的完整資料
