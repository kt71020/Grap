# 正忠排骨飯 門市爬蟲

## 網站資訊

- 目標網站：http://www.jengjong.tw/mobile/branch.php
- 品牌名稱：正忠排骨飯
- 資料來源：官方門市查詢頁面

## 檔案說明

### grap.pl

- 用途：主要爬蟲程式
- 功能：
  - 爬取門市資訊
  - 處理分頁資料
  - 輸出個別城市的 CSV 檔案
  - 自動處理電話號碼格式化
- 網址: http://www.jengjong.tw/mobile/branch.php

  - 回應：由以下 HTML 取得：商店名稱：[高雄市]正忠店、電話：07-385-3850、地址：高雄市三民區正忠路 63 號
  - 由網頁中符合以下區段取得每一家分公司資料

  ```HTML
  <div class="branch_list">
                            <div class="title">[高雄市]正忠店</div>
                            <div class="imgbox">
                                <img src="../upload/location/20100428123742444.jpg" width="175" height="176"/>
                            </div>
                            <div class="infobox">
                                <div class="list">
                                    <div class="left">訂購專線：</div>
                                    <div class="right">07-385-3850</div>
                                </div>
                                <div class="list">
                                    <div class="left">傳真電話：</div>
                                    <div class="right">07-386-9139</div>
                                </div>
                                <div class="list">
                                    <div class="left">地　　址：</div>
                                    <div class="right">
                                        <a href="http://maps.google.com.tw/maps?f=q&source=s_q&hl=zh-TW&geocode=&q=%E9%AB%98%E9%9B%84%E5%B8%82%E4%B8%89%E6%B0%91%E5%8D%80%E6%AD%A3%E5%BF%A0%E8%B7%AF63%E8%99%9F&sll=22.642294,120.330217&sspn=0.001879,0.002728&brcurrent=3,0x346e051e1f1d35d7:0xe6d0eb950fb496a3,0,0x346e04bf6cb74463:0xd266fce264dae085&ie=UTF8&hq=&hnear=807%E9%AB%98%E9%9B%84%E5%B8%82%E4%B8%89%E6%B0%91%E5%8D%80%E6%AD%A3%E5%BF%A0%E8%B7%AF63%E8%99%9F&z=17" target="_blank">807高雄市三民區正忠路63號</a>
                                    </div>
                                </div>
                                <div class="list">
                                    <div class="left">營業時間：</div>
                                    <div class="right">AM10:30-PM08:00（除夕至農曆初四公休）</div>
                                </div>
                            </div>
                        </div>

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

- **name**: 門市名稱（格式：正忠排骨飯 + 原始店名）
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

## 城市覆蓋範圍

## 輸出檔案

- `Shop_menu.csv` - 合併後的完整資料
