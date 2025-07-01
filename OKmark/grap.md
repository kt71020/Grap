我要爬蟲一個新的網頁，抓取資料與產生檔案的邏輯與先前大致一樣。
網址：https://www.okmart.com.tw/convenient_shopSearch

1. 先從「台北市」 開始，由城市取得「鄉鎮市區」
2. 「台北市」 「鎮市區」 取得,商店資料
3. 產生 CS 檔案

步驟 1
取得 $city 每個 『鄉鎮市區』 Area
[酬載]

https://www.okmart.com.tw/GetZipCode?city=%E5%8F%B0%E5%8C%97%E5%B8%82&ajax=true

city=台北市
ajax=storeTownList

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
[
{
"Area": "中正區"
},
{
"Area": "大同區"
},
{
"Area": "中山區"
},
{
"Area": "松山區"
},
{
"Area": "大安區"
},
{
"Area": "萬華區"
},
{
"Area": "信義區"
},
{
"Area": "士林區"
},
{
"Area": "北投區"
},
{
"Area": "內湖區"
},
{
"Area": "南港區"
},
{
"Area": "文山區"
}
]

步驟 2
由 R $area 取得該地區商店編號連結
[酬載]
https://www.okmart.com.tw/convenient_shopSearch_Result.aspx?city=%E5%8F%B0%E5%8C%97%E5%B8%82&zipcode=%E4%B8%AD%E6%AD%A3%E5%8D%80&key=&service=&service2=&_=1750911885770

searchType=ShopList
type=
city=台北市
zipcode=士林區
fun=showStoreList&
key=6F30E8BF706D653965BDE302661D1241F8BE9EBC

[reponse]

<h1>台北市</h1>
<ul>
    <li>
        <h2>士林芝東店           </h2>
        <span>台北市士林區士東路200巷21號1樓</span>
        <div>
            <a href="javascript:showshop('0389','台北市士林區士東路200巷21號1樓');">詳細資料</a>
        </div>
    </li>
    <li>
        <h2>士林和豐店           </h2>
        <span>台北市士林區和豐街39巷2號</span>
        <div>
            <a href="javascript:showshop('0954','台北市士林區和豐街39巷2號');">詳細資料</a>
        </div>
    </li>
    <li>
        <h2>士林基河店           </h2>
        <span>台北市士林區基河路250號</span>
        <div>
            <a href="javascript:showshop('1142','台北市士林區基河路250號');">詳細資料</a>
        </div>
    </li>
    <li>
        <h2>士林芝山店           </h2>
        <span>台北市士林區福華路155號</span>
        <div>
            <a href="javascript:showshop('1259','台北市士林區福華路155號');">詳細資料</a>
        </div>
    </li>
    <li>
        <h2>士林監理站門市         </h2>
        <span>台北市士林區承德路５段80號</span>
        <div>
            <a href="javascript:showshop('1520','台北市士林區承德路５段80號');">詳細資料</a>
        </div>
    </li>
</ul>

由 <a href="javascript:showshop('xxxx',);">詳細資料</a> ， 取得每一家店的連結編號 'xxxx'並存入矩陣

步驟 3

由商店連結編號取得商店資訊
[酬載]

https://www.okmart.com.tw/convenient_shopSearch_ShopResult.aspx?id=0389&_=1750912248819

id=xxxx

[Reponse]

<form name="form1" method="post" action="./convenient_shopSearch_ShopResult.aspx?id=0389&amp;_=1750912248819" id="form1">
<div>
<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="/wEPDwUJNzM0NjYwNzc5D2QWAmYPZBYUZg8WAh4EVGV4dAUa5aOr5p6X6Iqd5p2x5bqXICAgICAgICAgICBkAgEPFgIfAAXIAeWPsOWMl+W4guWjq+ael+WNgOWjq+adsei3rzIwMOW3tzIx6JmfMeaokzxhIGhyZWY9Imh0dHBzOi8vd3d3Lmdvb2dsZS5jb20vbWFwcy9zZWFyY2gvP2FwaT0xJnF1ZXJ5PeWPsOWMl+W4guWjq+ael+WNgOWjq+adsei3rzIwMOW3tzIx6JmfMeaokyIgdGFyZ2V0ID0iX2JsYW5rIiIgPjxpbWcgc3JjPSJpbWFnZXMvcGxhY2Vob2xkZXIuc3ZnIj48L2E+ZAICDxYCHwAFCzAyLTY2MTcxMDg5ZAIDDxYCHwAFBDAzODlkAgQPFgIfAGVkAgUPFgIfAAUJMDcwMH4wMDAwZAIHDxYCHwAFYeW4uOa6q+OAgeWGt+iXj+OAgeWGt+WHjTxicj7igLvjgIzlhrfol4/jgIHlhrflh43jgI3ljIXoo7nlr4Tlj5bku6XlupfoiJblr6bpmpvnqbrplpPni4Dms4HngrrkuLtkAgoPFgIfAAXSASA8c3BhbiBjbGFzcz0iZm9vZCIgc3R5bGU9ImJhY2tncm91bmQtY29sb3I6IzlFMDcxMSI+54eS55Wq6JavPC9zcGFuPiA8c3BhbiBjbGFzcz0iZm9vZCIgc3R5bGU9ImJhY2tncm91bmQtY29sb3I6IzVFMDcwRiI+54++54Wu5ZKW5ZWhPC9zcGFuPiA8c3BhbiBjbGFzcz0iZm9vZCIgc3R5bGU9ImJhY2tncm91bmQtY29sb3I6I0ZGMDM5QSI+6Iy26JGJ6JuLPC9zcGFuPmQCCw8WAh8AZWQCDA8WAh8AZWRkCHikKLIOQtkAaBlqSQhXmbmcq6e4SZC5F3wI0NZXOeg=" />
</div>

<div>

    <input type="hidden" name="__VIEWSTATEGENERATOR" id="__VIEWSTATEGENERATOR" value="6ACF053F" />

</div>
<h1 style="position:relative">士林芝東店           <a href="javascript:showshoplist();" style="position:absolute;right:0;top:0; font-size:0.8em; font-weight:normal;">回清單</a></h1>
<ul>
<li><span>門市地址：</span>台北市士林區士東路200巷21號1樓<a href="https://www.google.com/maps/search/?api=1&query=台北市士林區士東路200巷21號1樓" target ="_blank"" ><img src="images/placeholder.svg"></a>
    </li>
<li><span>門市電話：</span>02-66171089
    </li>
<li><span>門市店號：</span>0389
    </li>

<li><span>營業時間：</span>0700~0000</li>

    <li><span>網購服務：</span>常溫、冷藏、冷凍<br>※「冷藏、冷凍」包裹寄取以店舖實際空間狀況為主</li>

<li><span>其他服務項目：</span></li>
<li> <span class="food" style="background-color:#9E0711">燒番薯</span> <span class="food" style="background-color:#5E070F">現煮咖啡</span> <span class="food" style="background-color:#FF039A">茶葉蛋</span></li>
<li></li>
   
</ul>
</form>

[處理資料]
name=士林芝東店
phone=02-66171089
city=台北市
region=士林區
detailed_address=士東路 200 巷 21 號 1 樓

CSV 格式
name,phone,city,region,detailed_address,latitude,longitude
Okmart 士林芝東店,02-6617-1089,台北市,士林區,士東路 200 巷 21 號 1 樓,,

格式說明
name: "NAME" 前加上 'Okmart'
phone：dd-dddd-dd 若有 2 組電話，只取第一組電話
city ： $city
region ： $area
detailed_address："addr" 將 「城市」、「鄉鎮市區」去除，指保留路名與其他地址相關資料
