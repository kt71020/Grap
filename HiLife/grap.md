# HiLife 門市爬蟲

## 網站資訊

- 目標網站：https://www.hilife.com.tw/storeInquiry_street.aspx
- 品牌名稱：Hilife
- 資料來源：官方門市查詢頁面

```c
curl 'https://www.hilife.com.tw/storeInquiry_street.aspx' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
  -H 'accept-language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
  -b 'ASP.NET_SessionId=ypsormq03n3lxd14j5jbeqq1' \
  -H 'priority: u=0, i' \
  -H 'referer: https://www.hilife.com.tw/storeInquiry_shopNo.aspx' \
  -H 'sec-ch-ua: "Google Chrome";v="137", "Chromium";v="137", "Not/A)Brand";v="24"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: document' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-site: same-origin' \
  -H 'sec-fetch-user: ?1' \
  -H 'upgrade-insecure-requests: 1' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
```

由原始檔 HTML 解析

```HTML
  <strong>縣市</strong>
<select name="CITY" onchange="javascript:setTimeout(&#39;__doPostBack(\&#39;CITY\&#39;,\&#39;\&#39;)&#39;, 0)" id="CITY">
	<option selected="selected" value="台北市">台北市</option>
	<option value="基隆市">基隆市</option>
	<option value="新北市">新北市</option>
	<option value="宜蘭縣">宜蘭縣</option>
	<option value="新竹縣">新竹縣</option>
	<option value="桃園市">桃園市</option>
	<option value="苗栗縣">苗栗縣</option>
	<option value="台中市">台中市</option>
	<option value="彰化縣">彰化縣</option>
	<option value="南投縣">南投縣</option>
	<option value="嘉義縣">嘉義縣</option>
	<option value="雲林縣">雲林縣</option>
	<option value="台南市">台南市</option>
	<option value="高雄市">高雄市</option>
	<option value="屏東縣">屏東縣</option>
	<option value="新竹市">新竹市</option>
	<option value="嘉義市">嘉義市</option>

</select>
          <strong>鄉鎮市區</strong>
<select name="AREA" onchange="javascript:setTimeout(&#39;__doPostBack(\&#39;AREA\&#39;,\&#39;\&#39;)&#39;, 0)" id="AREA">
	<option selected="selected" value="中正區">中正區</option>
	<option value="大同區">大同區</option>
	<option value="中山區">中山區</option>
	<option value="松山區">松山區</option>
	<option value="大安區">大安區</option>
	<option value="萬華區">萬華區</option>
	<option value="信義區">信義區</option>
	<option value="士林區">士林區</option>
	<option value="北投區">北投區</option>
	<option value="內湖區">內湖區</option>
	<option value="南港區">南港區</option>
	<option value="文山區">文山區</option>

</select>
```

解析上面的 HTML 取得 CITY 列表，並取得 CITY=台北市的 AREA List 。

模擬切換 id=CITY 讓 onChange 可以驅動，

```HTML
<select name="CITY" onchange="javascript:setTimeout(&#39;__doPostBack(\&#39;CITY\&#39;,\&#39;\&#39;)&#39;, 0)" id="CITY">

```

要求網址 ；https://www.hilife.com.tw/storeInquiry_street.aspx
要求方法：POST
狀態碼：200 OK
遠端位址：[2600:1417:1b::cb45:8d10]:443
參照網址政策：strict-origin-when-cross-origin

fetch("https://www.hilife.com.tw/storeInquiry_street.aspx", {
"headers": {
"accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,_/_;q=0.8,application/signed-exchange;v=b3;q=0.7",
"accept-language": "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7",
"cache-control": "max-age=0",
"content-type": "application/x-www-form-urlencoded",
"priority": "u=0, i",
"sec-ch-ua": "\"Google Chrome\";v=\"137\", \"Chromium\";v=\"137\", \"Not/A)Brand\";v=\"24\"",
"sec-ch-ua-mobile": "?0",
"sec-ch-ua-platform": "\"macOS\"",
"sec-fetch-dest": "document",
"sec-fetch-mode": "navigate",
"sec-fetch-site": "same-origin",
"sec-fetch-user": "?1",
"upgrade-insecure-requests": "1"
},
"referrer": "https://www.hilife.com.tw/storeInquiry_street.aspx",
"referrerPolicy": "strict-origin-when-cross-origin",
"body": "**EVENTTARGET=CITY&**EVENTARGUMENT=&**LASTFOCUS=&**VIEWSTATE=%2FwEPDwUKMTQ5MDc2Mzc5OA9kFgICBw9kFgwCAQ9kFgICAQ8WAh4EVGV4dAUuJCgnI3N0b3JlSW5xdWlyeV9zdHJlZXQnKS5hdHRyKCdjbGFzcycsJ3NlbCcpO2QCAw8QDxYGHg1EYXRhVGV4dEZpZWxkBQljaXR5X25hbWUeDkRhdGFWYWx1ZUZpZWxkBQljaXR5X25hbWUeC18hRGF0YUJvdW5kZ2QQFREJ5Y%2Bw5YyX5biCCeWfuumahuW4ggnmlrDljJfluIIJ5a6c6Jit57ijCeaWsOeruee4ownmoYPlnJLluIIJ6IuX5qCX57ijCeWPsOS4reW4ggnlvbDljJbnuKMJ5Y2X5oqV57ijCeWYiee%2Bqee4ownpm7LmnpfnuKMJ5Y%2Bw5Y2X5biCCemrmOmbhOW4ggnlsY%2FmnbHnuKMJ5paw56u55biCCeWYiee%2BqeW4ghURCeWPsOWMl%2BW4ggnln7rpmobluIIJ5paw5YyX5biCCeWunOiYree4ownmlrDnq7nnuKMJ5qGD5ZyS5biCCeiLl%2Bagl%2Be4ownlj7DkuK3luIIJ5b2w5YyW57ijCeWNl%2BaKlee4ownlmInnvqnnuKMJ6Zuy5p6X57ijCeWPsOWNl%2BW4ggnpq5jpm4TluIIJ5bGP5p2x57ijCeaWsOerueW4ggnlmInnvqnluIIUKwMRZ2dnZ2dnZ2dnZ2dnZ2dnZ2cWAWZkAgUPEA8WBh8BBQl0b3duX25hbWUfAgUJdG93bl9uYW1lHwNnZBAVDAnkuK3mraPljYAJ5aSn5ZCM5Y2ACeS4reWxseWNgAnmnb7lsbHljYAJ5aSn5a6J5Y2ACeiQrOiPr%2BWNgAnkv6HnvqnljYAJ5aOr5p6X5Y2ACeWMl%2BaKleWNgAnlhafmuZbljYAJ5Y2X5riv5Y2ACeaWh%2BWxseWNgBUMCeS4reato%2BWNgAnlpKflkIzljYAJ5Lit5bGx5Y2ACeadvuWxseWNgAnlpKflronljYAJ6JCs6I%2Bv5Y2ACeS%2Foee%2BqeWNgAnlo6vmnpfljYAJ5YyX5oqV5Y2ACeWFp%2Ba5luWNgAnljZfmuK%2FljYAJ5paH5bGx5Y2AFCsDDGdnZ2dnZ2dnZ2dnZxYBZmQCBw8PFgIfAAUJ5Y%2Bw5YyX5biCZGQCCQ8PFgIfAAUJ5Lit5q2j5Y2AZGQCCw8WAh4LXyFJdGVtQ291bnQCDhYcZg9kFgJmDxUSBDQyMjcP5Lit5q2j56eL6JGJ5Y6fLjEwMOWPsOWMl%2BW4guS4reato%2BWNgOWFq%2BW%2Bt%2Bi3r%2BS4gOautTgy5be3MTDomZ8uMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5YWr5b636Lev5LiA5q61ODLlt7cxMOiZn1Q8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2F0bS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BaPkOasvuacjeWLmScgLz4AVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfY29mZmVlLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5ZKW5ZWh5qmfJyAvPgAAYDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfbGlmZUV0LmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0nTGlmZS1FVCjos7znpagp5pyN5YuZJyAvPgAAAAAAAAALMDItODk3ODMxNDJkAgEPZBYCZg8VEgQzNjI1D%2BS4reato%2BerpemGq%2BW6lycxMDDlj7DljJfluILkuK3mraPljYDkuK3lsbHljZfot6846JmfQjEnMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5Lit5bGx5Y2X6LevOOiZn0IxVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfYXRtLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5o%2BQ5qy%2B5pyN5YuZJyAvPgBUPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9jb2ZmZWUuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSflkpbllaHmqZ8nIC8%2BAABgPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9saWZlRXQuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSdMaWZlLUVUKOizvOelqCnmnI3li5knIC8%2BAFE8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2JicS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BeHkueDpOapnycgLz4AAAAAAAswMi0yMzcwMjQ4NmQCAg9kFgJmDxUSBDM1NzYS5Lit5q2j5YWJ6I%2Bv5ZWG5aC0KzEwMOWPsOWMl%2BW4guS4reato%2BWNgOW4guawkeWkp%2BmBk%2BS4ieautTjomZ8rMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5biC5rCR5aSn6YGT5LiJ5q61OOiZnwAAVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfY29mZmVlLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5ZKW5ZWh5qmfJyAvPlc8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX3BpYy5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BebuOeJh%2Baylua0l%2BapnycgLz4AYDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfbGlmZUV0LmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0nTGlmZS1FVCjos7znpagp5pyN5YuZJyAvPgBRPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9iYnEuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfnh5Lng6TmqZ8nIC8%2BAAAAAAALMDItMjM5MTM2NDVkAgMPZBYCZg8VEgQ1MzAzD%2BS4reato%2BatpuaYjOW6ly0xMDDlj7DljJfluILkuK3mraPljYDmrabmmIzooZfkuIDmrrU0NeiZnzHmqJMtMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5q2m5piM6KGX5LiA5q61NDXomZ8x5qiTVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfYXRtLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5o%2BQ5qy%2B5pyN5YuZJyAvPgBUPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9jb2ZmZWUuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSflkpbllaHmqZ8nIC8%2BAABgPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9saWZlRXQuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSdMaWZlLUVUKOizvOelqCnmnI3li5knIC8%2BAFE8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2JicS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BeHkueDpOapnycgLz4AAAAAVzxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfc21vb3RoaWUucG5nJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfmnpxD5p6c5piUJyAvPgswMi0yMzEyMjY5MGQCBA9kFgJmDxUSBDQ4OTgP5Lit5q2j5aSn5b%2Bg6ZaAMzEwMOWPsOWMl%2BW4guS4reato%2BWNgOS%2Foee%2Bqei3r%2BS4gOautTEz5LmLMeiZn%2BS4gOaokzMxMDDlj7DljJfluILkuK3mraPljYDkv6Hnvqnot6%2FkuIDmrrUxM%2BS5izHomZ%2FkuIDmqJNUPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9hdG0uZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfmj5DmrL7mnI3li5knIC8%2BAFQ8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2NvZmZlZS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BWSluWVoeapnycgLz4AAGA8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2xpZmVFdC5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J0xpZmUtRVQo6LO856WoKeacjeWLmScgLz4AAAAAAAAACzAyLTIzMjI0NjE0ZAIFD2QWAmYPFRIEMjQ1Nw%2FkuK3mraPmraPms4nlupdDMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5rOJ5bee6KGXMzHjgIEzM%2BiZn%2BOAgeWvp%2Bazouilv%2BihlzEwNOiZn%2BS4gOaok0MxMDDlj7DljJfluILkuK3mraPljYDms4nlt57ooZczMeOAgTMz6Jmf44CB5a%2Bn5rOi6KW%2F6KGXMTA06Jmf5LiA5qiTVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfYXRtLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5o%2BQ5qy%2B5pyN5YuZJyAvPgBUPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9jb2ZmZWUuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSflkpbllaHmqZ8nIC8%2BAABgPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9saWZlRXQuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSdMaWZlLUVUKOizvOelqCnmnI3li5knIC8%2BAFE8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2JicS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BeHkueDpOapnycgLz4AAAAAAAswMi0yMzM5NDE4NmQCBg9kFgJmDxUSBDIyODQP5Lit5q2j5Y%2Bw5aSn6YarIjEwMOWPsOWMl%2BW4guS4reato%2BWNgOW4uOW%2Bt%2BihlzHomZ8iMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5bi45b636KGXMeiZnwAAAAAAAAAAAAAAAAALMDItMjMxMTIxNTVkAgcPZBYCZg8VEgQzOTM2DuS4reato%2BWPsOmGq0IxJDEwMOWPsOWMl%2BW4guS4reato%2BWNgOW4uOW%2Bt%2BihlzHomZ9CMSQxMDDlj7DljJfluILkuK3mraPljYDluLjlvrfooZcx6JmfQjEAAFQ8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2NvZmZlZS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BWSluWVoeapnycgLz4AAGA8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2xpZmVFdC5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J0xpZmUtRVQo6LO856WoKeacjeWLmScgLz4AUTxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfYmJxLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n54eS54Ok5qmfJyAvPgAAAABXPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9zbW9vdGhpZS5wbmcnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BaenEPmnpzmmJQnIC8%2BCzAyLTIzMTQ2MjE4ZAIID2QWAmYPFRIENDA5NhLkuK3mraPlloTlsI7lr7rnq5lLMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5qKF6Iqx6YeM77yY6YSw5b%2Bg5a2d5p2x6Lev5LiA5q6177yT77yV6Jmf5LiA5qiT5YWo6YOoSzEwMOWPsOWMl%2BW4guS4reato%2BWNgOaiheiKsemHjO%2B8mOmEsOW%2FoOWtneadsei3r%2BS4gOaute%2B8k%2B%2B8leiZn%2BS4gOaok%2BWFqOmDqFQ8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2F0bS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BaPkOasvuacjeWLmScgLz4AVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfY29mZmVlLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5ZKW5ZWh5qmfJyAvPlc8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX3BpYy5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BebuOeJh%2Baylua0l%2BapnycgLz4AYDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfbGlmZUV0LmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0nTGlmZS1FVCjos7znpagp5pyN5YuZJyAvPgAAAFc8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2dyb2Nlci5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BaXpeeUqOmbnOiyqCcgLz4AVTxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfc29jay5wbmcnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BilquWtkOWwiOizoycgLz5XPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9zbW9vdGhpZS5wbmcnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BaenEPmnpzmmJQnIC8%2BCzAyLTg5NzgxNjM0ZAIJD2QWAmYPFRIEMjg5NQ%2FkuK3mraPntLnoiIjljZcqMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A57S56IiI5Y2X6KGXNOS5izEy6JmfKjEwMOWPsOWMl%2BW4guS4reato%2BWNgOe0ueiIiOWNl%2BihlzTkuYsxMuiZn1Q8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2F0bS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BaPkOasvuacjeWLmScgLz4AVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfY29mZmVlLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5ZKW5ZWh5qmfJyAvPgAAYDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfbGlmZUV0LmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0nTGlmZS1FVCjos7znpagp5pyN5YuZJyAvPgBRPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9iYnEuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfnh5Lng6TmqZ8nIC8%2BAAAAAAALMDItMjMyMjQwMDlkAgoPZBYCZg8VEgQ0MzIxD%2BS4reato%2BmrmOmZouW6lyQxMDDlj7DljJfluILkuK3mraPljYDljZrmhJvot68xMjfomZ8kMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5Y2a5oSb6LevMTI36JmfVDxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfYXRtLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n5o%2BQ5qy%2B5pyN5YuZJyAvPgBUPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9jb2ZmZWUuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSflkpbllaHmqZ8nIC8%2BAABgPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9saWZlRXQuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSdMaWZlLUVUKOizvOelqCnmnI3li5knIC8%2BAFE8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2JicS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BeHkueDpOapnycgLz4AAAAAAAswMi04OTc4MDg1NGQCCw9kFgJmDxUSBDM3NjgP5Lit5q2j5Y%2B45rOV5bqXJjEwMOWPsOWMl%2BW4guS4reato%2BWNgOWNmuaEm%2Bi3rzEzMeiZn0IxJjEwMOWPsOWMl%2BW4guS4reato%2BWNgOWNmuaEm%2Bi3rzEzMeiZn0IxAABUPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9jb2ZmZWUuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSflkpbllaHmqZ8nIC8%2BAABgPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9saWZlRXQuZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSdMaWZlLUVUKOizvOelqCnmnI3li5knIC8%2BAFE8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2JicS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BeHkueDpOapnycgLz4AAAAAVzxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfc21vb3RoaWUucG5nJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfmnpxD5p6c5piUJyAvPgswMi0yMzcwNDE4OGQCDA9kFgJmDxUSBDM2MTEP5Lit5q2j6KW%2F6ZaA56uZJDEwMOWPsOWMl%2BW4guS4reato%2BWNgOihoemZvei3rzEwM%2BiZnyQxMDDlj7DljJfluILkuK3mraPljYDooaHpmb3ot68xMDPomZ9UPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9hdG0uZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfmj5DmrL7mnI3li5knIC8%2BAFQ8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2NvZmZlZS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BWSluWVoeapnycgLz4AAGA8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2xpZmVFdC5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J0xpZmUtRVQo6LO856WoKeacjeWLmScgLz4AAAAAAAAACzAyLTIzNzA1NDYxZAIND2QWAmYPFRIENTE4Mw%2FkuK3mraPmh7flr6flupcjMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5oe35a%2Bn6KGXMjHomZ8jMTAw5Y%2Bw5YyX5biC5Lit5q2j5Y2A5oe35a%2Bn6KGXMjHomZ9UPGltZyBzcmM9J2ltYWdlcy9pY29uL21hcmtlZF9hdG0uZ2lmJyB3aWR0aD0nMjUnIGhlaWdodD0nMjUnIHRpdGxlPSfmj5DmrL7mnI3li5knIC8%2BAFQ8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2NvZmZlZS5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J%2BWSluWVoeapnycgLz4AAGA8aW1nIHNyYz0naW1hZ2VzL2ljb24vbWFya2VkX2xpZmVFdC5naWYnIHdpZHRoPScyNScgaGVpZ2h0PScyNScgdGl0bGU9J0xpZmUtRVQo6LO856WoKeacjeWLmScgLz4AUTxpbWcgc3JjPSdpbWFnZXMvaWNvbi9tYXJrZWRfYmJxLmdpZicgd2lkdGg9JzI1JyBoZWlnaHQ9JzI1JyB0aXRsZT0n54eS54Ok5qmfJyAvPgAAAAAACzAyLTIzMTE1NDgzZGRdXFgJZqXXQztttcGRXlKYfdOjpxsj3zpRbTdH2zECrQ%3D%3D&\_\_VIEWSTATEGENERATOR=B77476FC&CITY=%E5%9F%BA%E9%9A%86%E5%B8%82&AREA=%E4%B8%AD%E6%AD%A3%E5%8D%80",
"method": "POST",
"mode": "cors",
"credentials": "include"
});

```
由原始HTML中解析 CITY＝基隆市的 AREA List

由此邏輯取得所有城市的 AREA。



## 檔案說明

### get_city.pl

- 用途：分析網站結構，取得城市代碼對照表
- 功能：列印城市映射表，確認抓取範圍

### hilife.pl (舊版本)

- 用途：簡單版本的爬蟲程式
- 限制：僅支援直接查詢，不支援階層式選擇

### hilife_v2.pl (推薦使用)

- 用途：階層式查詢爬蟲程式
- 功能：
  - **階層式查詢**：先選縣市 → 再選地區 → 最後取得門市
  - **AJAX 支援**：模擬網站的動態載入機制
  - 爬取各城市各地區的門市資訊
  - 處理 ASP.NET 表單和 ViewState
  - 輸出個別城市的 CSV 檔案
  - 自動處理電話號碼格式化

### merge.pl

- 用途：合併各城市 CSV 檔案
- 功能：
  - 合併所有 csv/\*.csv 檔案
  - 產生統一的 Shop_list.csv
  - 顯示各城市門市統計

## 資料欄位

```

name,phone,city,region,detailed_address,latitude,longitude

````

### 欄位說明

- **name**: 門市名稱（格式：HiLife + 原始店名）
- **phone**: 電話號碼（已格式化為 XX-XXXX-XXXX 或 XX-XXXXXXX）
- **city**: 城市名稱
- **region**: 地區名稱
- **detailed_address**: 詳細地址（已移除城市和地區前綴）
- **latitude**: 緯度（此網站未提供，為空值）
- **longitude**: 經度（此網站未提供，為空值）

## 使用方法

### 1. 執行爬蟲

**推薦使用階層式查詢版本：**

```bash
perl hilife_v2.pl
````

**或使用舊版本（可能無法正常工作）：**

```bash
perl hilife.pl
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

1. **階層式查詢**: HiLife 網站使用「縣市 → 地區 → 門市」的階層式查詢架構
2. **AJAX 支援**: hilife_v2.pl 支援網站的 AJAX 動態載入機制
3. **網站限制**: 程式包含適當的延遲機制避免被封鎖（地區間 2 秒，城市間 5 秒）
4. **編碼**: 所有檔案使用 UTF-8 編碼
5. **錯誤處理**: 包含網路錯誤和資料異常的處理
6. **測試模式**: 可在 hilife_v2.pl 中啟用測試模式，只抓取部分城市
7. **表單處理**: 支援 ASP.NET ViewState、EventValidation 和 ViewStateGenerator 處理
8. **地區識別**: 程式會自動識別每個城市的地區列表，然後逐一查詢

## 城市覆蓋範圍

涵蓋全台灣 17 個縣市：

- 直轄市：台北市、新北市、桃園市、台中市、台南市、高雄市
- 省轄市：基隆市、新竹市、嘉義市
- 縣：宜蘭縣、新竹縣、苗栗縣、彰化縣、南投縣、雲林縣、嘉義縣、屏東縣

## 輸出檔案

- `csv/城市名稱.csv` - 各城市門市資料（如：台北.csv、台中.csv）
- `Shop_list.csv` - 合併後的完整資料
