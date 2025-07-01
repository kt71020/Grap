# Familymart 更新商品分類代碼程序

處理 hq_org_no=1964 商品分類代碼 category_code 200/300 只有部分分店有販售此一種類商品。

## category_code 200/300 定義

1. 搜尋 shop hq_org_no=1964 ，取得符合條件的分店編號 @sid_list
2. 根據 @sid_list 的 sid 將資料表 catagory category_code= 200 更新 category_active=false,category_code= 300 更新 category_active=false

## 哪些分店有販售 200 /300

### 資料來源定義

- FamilyMart/catagroy/Family_catagory.csv 定義有販售 200 或 300 的商店
- 檔案標題列 name,address,lite,c-200,c-300
- name:商店名稱
- address：地址
- lite：輕食（沒有用到）
- c-200：1 表示有販售 category_code= 200 更新 category_active=ture
- c-300：1 表示有販售 category_code= 300 更新 category_active=ture

## 資料檔案處理

1. 讀取 FamilyMart/catagroy/Family_catagory.csv 篩選 c-200=1 or c-300=1
2. shop_name='FamilyMart 全家'+name
3. 搜尋 shop 資料表 name=shop_name and hq_org_no=1964,取得要更新商店的 sid
4. c-200=1 表示有販售 category_code= 200 更新 catagroy 資料表 sid category_active=ture
5. c-200=1 shop 資料 introduction 將 ' 「仿手沖單品」' 附加在 introduction
6. c-300=1 表示有販售 category_code= 300 更新 catagroy 資料表 sid category_active=ture
7. c-200=1 shop 資料 introduction 將 ' 「義式單品」' 附加在 introduction
8. 更新 shop 資料 introduction 欄位

## 輸出程式

update_catagroy.pl
