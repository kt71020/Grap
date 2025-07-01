我要爬蟲一個新的網頁，抓取資料與產生檔案的邏輯與先前大致一樣。
網址：https://www.family.com.tw/Marketing/StoreMap/?v=1

1. 先從「台北市」 開始，由城市取得「鄉鎮市區」
2. 「台北市」 「鎮市區」 取得,商店資料
3. 產生 CS 檔案

步驟 1
[酬載]
searchType=ShowTownList&type=&city=%E5%8F%B0%E5%8C%97%E5%B8%82&fun=storeTownList&key=6F30E8BF706D653965BDE302661D1241F8BE9EBC

searchType=ShowTownList
type=
city=台北市
fun=storeTownList
key=6F30E8BF706D653965BDE302661D1241F8BE9EBC

[要求標頭]
GET /net/familyShop.aspx?searchType=ShowTownList&type=&city=%E5%8F%B0%E5%8C%97%E5%B8%82&fun=storeTownList&key=6F30E8BF706D653965BDE302661D1241F8BE9EBC HTTP/1.1
Accept: _/_
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7
Connection: keep-alive
Host: api.map.com.tw
Referer: https://www.family.com.tw/
Sec-Fetch-Dest: script
Sec-Fetch-Mode: no-cors
Sec-Fetch-Site: cross-site
Sec-Fetch-Storage-Access: active
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36
sec-ch-ua: "Chromium";v="136", "Google Chrome";v="136", "Not.A/Brand";v="99"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "macOS"

[reponse]
storeTownList([
{
"post": "100",
"town": "中正區",
"city": "台北市"
},
{
"post": "103",
"town": "大同區",
"city": "台北市"
},
{
"post": "104",
"town": "中山區",
"city": "台北市"
},
{
"post": "105",
"town": "松山區",
"city": "台北市"
},
{
"post": "106",
"town": "大安區",
"city": "台北市"
},
{
"post": "108",
"town": "萬華區",
"city": "台北市"
},
{
"post": "110",
"town": "信義區",
"city": "台北市"
},
{
"post": "111",
"town": "士林區",
"city": "台北市"
},
{
"post": "112",
"town": "北投區",
"city": "台北市"
},
{
"post": "114",
"town": "內湖區",
"city": "台北市"
},
{
"post": "115",
"town": "南港區",
"city": "台北市"
},
{
"post": "116",
"town": "文山區",
"city": "台北市"
}
])

步驟 2
[酬載]
searchType=ShopList&type=&city=%E5%8F%B0%E5%8C%97%E5%B8%82&area=%E5%A3%AB%E6%9E%97%E5%8D%80&road=&fun=showStoreList&key=6F30E8BF706D653965BDE302661D1241F8BE9EBC

searchType=ShopList
type=
city=台北市
area=士林區
fun=showStoreList&
key=6F30E8BF706D653965BDE302661D1241F8BE9EBC
[要求標頭]
GET /net/familyShop.aspx?searchType=ShopList&type=&city=%E5%8F%B0%E5%8C%97%E5%B8%82&area=%E5%A3%AB%E6%9E%97%E5%8D%80&road=&fun=showStoreList&key=6F30E8BF706D653965BDE302661D1241F8BE9EBC HTTP/1.1
Accept: _/_
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7
Connection: keep-alive
Host: api.map.com.tw
Referer: https://www.family.com.tw/
Sec-Fetch-Dest: script
Sec-Fetch-Mode: no-cors
Sec-Fetch-Site: cross-site
Sec-Fetch-Storage-Access: active
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36
sec-ch-ua: "Chromium";v="136", "Google Chrome";v="136", "Not.A/Brand";v="99"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "macOS"
[reponse]
showStoreList([
{
"NAME": "全家芝玉店",
"TEL": "02-28343943",
"POSTel": "02-77096121",
"px": 121.537537,
"py": 25.112312,
"addr": "台北市士林區士東路２６６巷５弄１６號",
"SERID": 14445.0,
"pkey": "016375",
"oldpkey": "004445",
"post": "111",
"all": "SWEETPOTATO,Photo,Toilet,Rest,dessert,CS,Smart,eco,grill,hd",
"road": "士東路",
"twoice": null
},
{
"NAME": "全家新士誠店",
"TEL": "02-28314357",
"POSTel": "02-77302120",
"px": 121.52881,
"py": 25.112016,
"addr": "台北市士林區士東路８６號壹樓",
"SERID": 57575.0,
"pkey": "022747",
"oldpkey": "017575",
"post": "111",
"all": "SWEETPOTATO,CS,eco,hd",
"road": "士東路",
"twoice": null
},
....
])
步驟 3

CSV 格式
name,phone,city,region,detailed_address
FamilyMart 全家新士誠店,02-2577-4806,台北市,松山區,八德路三段 27 號

格式說明
name: "NAME" 前加上 FamilyMart
phone：dd-dddd-dd 若有 2 組電話，只取第一組電話
city ： $city
region ： $area
detailed_address："addr" 將 「城市」、「鄉鎮市區」去除，指保留路名與其他地址相關資料
