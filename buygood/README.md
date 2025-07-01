# 好購網門市爬蟲使用說明

## 🚀 執行步驟

### 1. 安裝必要的 Perl 模組

在執行爬蟲之前，請先安裝以下模組：

```bash
# 使用 cpan 安裝
cpan LWP::UserAgent
cpan HTML::TreeBuilder::XPath
cpan URI::Escape
cpan HTTP::Cookies
cpan Encode
cpan File::Glob

# 或使用 cpanm（如果已安裝）
cpanm LWP::UserAgent HTML::TreeBuilder::XPath URI::Escape HTTP::Cookies Encode File::Glob
```

### 2. 執行程式

#### 步驟一：查看城市列表

```bash
perl get_city.pl
```

#### 步驟二：執行爬蟲

```bash
perl grap.pl
```

#### 步驟三：合併資料

```bash
perl merge.pl
```

## 📋 程式說明

- **get_city.pl**: 顯示支援的城市列表
- **grap.pl**: 主要爬蟲程式，會建立 `csv/` 目錄並抓取各城市門市資料
- **merge.pl**: 合併所有 CSV 檔案為統一格式

## 📁 輸出檔案

- `csv/城市名.csv` - 各城市的門市資料
- `Shop_list.csv` - 合併後的門市列表
- `Shop_menu.csv` - 包含商店資訊的完整檔案

## ⚠️ 注意事項

1. 爬蟲程式包含延遲機制，避免對伺服器造成過大負載
2. 如果遇到網路錯誤，程式會跳過該城市並繼續執行
3. 建議在測試時先修改程式中的城市列表，只抓取少數城市

## 🛠️ 疑難排解

如果遇到模組缺失的錯誤，請確認已安裝所需模組：

```bash
perl -e "use LWP::UserAgent; use HTML::TreeBuilder::XPath; print 'All modules OK\n';"
```
