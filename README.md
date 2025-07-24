# Grap - 台灣便利商店資料爬蟲專案

這是一個用 Perl 編寫的台灣便利商店資料爬蟲專案，可以抓取各大便利商店的店鋪資訊。

## 支援的便利商店

- **7-Eleven (711/)** - 統一超商店鋪資料
- **FamilyMart (FamilyMart/)** - 全家便利商店資料
- **Hi-Life (HiLife/)** - 萊爾富便利商店資料
- **OK mart (OKmark/)** - OK 超商資料
- **WuTau (wutau/)** - 五桃超商資料
- **BuyGood (buygood/)** - 百貨資料
- **JengJong (jengjong/)** - 正忠排骨飯資料

## 項目結構

每個便利商店資料夾都包含：

- `grap.pl` - 主要爬蟲程式
- `csv/` - 輸出的 CSV 資料檔案
- `Shop_info.csv` - 店鋪基本資訊
- `merge.pl` - 資料合併程式
- `grap.md` - 該便利商店的爬蟲說明

## 共用程式庫

- `lib/MyDB.pm` - 資料庫操作模組
- `grap_template/` - 爬蟲程式範本

## 使用方法

1. 進入對應的便利商店資料夾
2. 執行 `perl grap.pl` 開始爬取資料
3. 爬取完成後執行 `perl merge.pl` 合併資料

## 注意事項

- 請遵守網站的 robots.txt 和使用條款
- 適當設置爬蟲間隔時間，避免對網站造成負擔
- 資料僅供學習研究使用

## 系統需求

- Perl 5.x
- 相關 Perl 模組（詳見各資料夾內的說明）
