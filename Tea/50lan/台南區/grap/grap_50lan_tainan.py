#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
50嵐-台南區門市爬蟲
資料來源：
  1. findcoupon.tw - 台南市門市（名稱、地址、電話）
  2. Google Search (udm=1) - 經緯度座標 + 高雄市岡山/路竹門市

篩選條件：地址包含「台南市」or「高雄市岡山」or「高雄市路竹」
"""

import csv
import re
import sys
import time
import requests
from urllib.parse import unquote

OUTPUT_FILE = "50lan_台南區.csv"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "zh-TW,zh;q=0.9,en;q=0.8",
}

# 篩選條件
FILTER_CITIES = ["台南市"]
FILTER_DISTRICTS = ["岡山", "路竹"]  # 高雄市的特定區


def normalize_phone(phone):
    """正規化電話號碼，保留數字和破折號"""
    phone = re.sub(r"[\s\(\)（）]", "", phone)
    return phone


def phone_digits(phone):
    """只取數字，用於比對"""
    return re.sub(r"[^\d]", "", phone)


def format_phone(phone):
    """格式化電話號碼為 XX-XXXXXXX 格式"""
    digits = phone_digits(phone)
    if not digits:
        return phone
    # 如果已有破折號格式，保留
    if "-" in phone:
        return phone
    # 台灣市話：區碼2碼 + 號碼7-8碼
    if len(digits) == 9 and digits.startswith("0"):
        return f"{digits[:2]}-{digits[2:]}"
    if len(digits) == 10 and digits.startswith("0"):
        return f"{digits[:2]}-{digits[2:]}"
    return phone


def parse_address(address):
    """從地址解析城市、鄉鎮市區、詳細地址"""
    address = address.strip()
    city = ""
    district = ""
    detail = address

    # 移除郵遞區號
    address = re.sub(r"^\d{3,5}\s*", "", address)

    cities = [
        "台南市", "臺南市", "高雄市",
    ]
    for c in cities:
        if address.startswith(c):
            city = c.replace("臺", "台")
            detail = address[len(c):]
            break

    if detail:
        m = re.match(r"([\u4e00-\u9fff]{1,4}(?:區|鎮|鄉))", detail)
        if m:
            district = m.group(1)
            detail = detail[len(district):]

    return city, district, detail.strip()


def scrape_findcoupon(city_name):
    """從 findcoupon.tw 爬取門市資料"""
    url = f"https://www.findcoupon.tw/showroom-1120/store/{city_name}"
    print(f"正在爬取 findcoupon.tw ({city_name})...")
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.raise_for_status()

    stores = []
    html = resp.text

    # 網頁使用 div.td 內含 <a> 連結：店名、地址(含icon)、電話(含icon)
    pattern = (
        r'<a[^>]*>([^<]+)</a></div>\s*'
        r'<div class="td"><a[^>]*>[^<]*<i[^>]*></i>\s*([^<]+)</a></div>\s*'
        r'<div class="td"><a[^>]*>[^<]*<i[^>]*></i>\s*([^<]+)</a>'
    )
    matches = re.findall(pattern, html)

    for name, address, phone in matches:
        name = name.strip()
        address = address.strip()
        phone = phone.strip()

        # 跳過表頭或空資料
        if not name or not re.search(r"[路街巷弄號]", address):
            continue

        city, district, detail = parse_address(address)
        stores.append({
            "name": f"50嵐{name}" if not name.startswith("50嵐") else name,
            "phone": normalize_phone(phone),
            "city": city,
            "district": district,
            "address": detail,
            "lat": "",
            "lng": "",
        })

    print(f"  找到 {len(stores)} 間門市")
    return stores


def scrape_google_search(query, extra_stores=None):
    """從 Google Search (udm=1) 爬取門市座標和額外門市資料

    Args:
        query: 搜尋關鍵字
        extra_stores: 如果提供，會嘗試將座標配對到這些門市（依電話匹配）

    Returns:
        (phone_to_coords, new_stores): 電話→座標對照, 新發現的門市列表
    """
    all_phone_to_coords = {}
    new_stores = []
    start = 0

    while True:
        url = "https://www.google.com/search"
        params = {
            "q": query,
            "udm": "1",
            "hl": "zh-TW",
            "start": str(start),
        }
        print(f"正在搜尋 Google: {query} (start={start})...")
        resp = requests.get(url, params=params, headers=HEADERS, timeout=15)

        if resp.status_code != 200:
            print(f"  HTTP {resp.status_code}")
            break

        html = resp.text

        # 提取門市名稱
        names = []
        for m in re.finditer(r'>50嵐[^<]*<', html):
            name = m.group(0)[1:-1].strip()
            if "店" in name:
                if "搜尋" not in name and len(name) < 40:
                    names.append(name)

        # 提取電話
        phones = re.findall(r"0[67][\s\-]?\d{3,4}[\s\-]?\d{3,4}", html)
        phones = [normalize_phone(p) for p in phones]
        # 去除重複的連續電話（Google 頁面常重複）
        unique_phones = []
        for p in phones:
            if not unique_phones or p != unique_phones[-1]:
                unique_phones.append(p)
        phones = unique_phones

        # 提取座標 [lat*1e7, lng*1e7]
        coords = re.findall(r"null,\[(2[23]\d{7}),(1[12][089]\d{7})\]", html)
        coord_pairs = [(int(c[0]) / 1e7, int(c[1]) / 1e7) for c in coords]
        # 去除重複的連續座標
        unique_coords = []
        for c in coord_pairs:
            if not unique_coords or c != unique_coords[-1]:
                unique_coords.append(c)
        coord_pairs = unique_coords

        # 提取城市區域
        search_urls = re.findall(r"/search\?[^\"]{0,500}ludocid", html)
        store_locations = []
        for u in search_urls:
            decoded = unquote(u.replace("\\u003d", "=").replace("\\u0026", "&"))
            q_match = re.search(r"q=([^&]+)", decoded)
            if q_match:
                store_locations.append(unquote(q_match.group(1)))

        print(f"  名稱: {len(names)}, 電話: {len(phones)}, 座標: {len(coord_pairs)}, 位置: {len(store_locations)}")

        # 配對電話(純數字)和座標
        min_len = min(len(phones), len(coord_pairs))
        for i in range(min_len):
            all_phone_to_coords[phone_digits(phones[i])] = coord_pairs[i]

        # 配對名稱、電話、座標、位置（用於發現新門市）
        min_all = min(len(names), len(phones), len(coord_pairs))
        for i in range(min_all):
            loc = store_locations[i] if i < len(store_locations) else ""
            # 嘗試從 location 提取城市+區
            city_match = re.search(r"([\u4e00-\u9fff]+[市縣])([\u4e00-\u9fff]+[區鎮鄉])?", loc)
            city = city_match.group(1).replace("臺", "台") if city_match else ""
            district = city_match.group(2) or "" if city_match else ""

            new_stores.append({
                "name": names[i],
                "phone": phones[i],
                "city": city,
                "district": district,
                "address": "",  # Google Search 沒有完整地址
                "lat": str(coord_pairs[i][0]),
                "lng": str(coord_pairs[i][1]),
            })

        # 檢查是否有下一頁
        if len(names) < 18 or start >= 60:
            break
        start += 20
        time.sleep(1)

    return all_phone_to_coords, new_stores


def reverse_geocode(lat, lng):
    """使用 Nominatim 反向地理編碼取得地址"""
    url = (
        f"https://nominatim.openstreetmap.org/reverse"
        f"?lat={lat}&lon={lng}&format=json&addressdetails=1&accept-language=zh-TW"
    )
    try:
        resp = requests.get(url, headers={"User-Agent": "grap-50lan/1.0"}, timeout=10)
        data = resp.json()
        addr = data.get("address", {})
        road = addr.get("road", "")
        house = addr.get("house_number", "")
        # house_number 可能已含「號」
        if house:
            detail = f"{road}{house}" if "號" in house else f"{road}{house}號"
        else:
            detail = road
        city = addr.get("city", addr.get("county", "")).replace("臺", "台")
        district = addr.get("suburb", addr.get("city_district", ""))
        return city, district, detail
    except Exception:
        return "", "", ""


def enrich_with_coords(stores, phone_to_coords):
    """用座標資料補充門市的經緯度"""
    enriched = 0
    for store in stores:
        digits = phone_digits(store["phone"])
        if digits and digits in phone_to_coords:
            lat, lng = phone_to_coords[digits]
            store["lat"] = str(lat)
            store["lng"] = str(lng)
            enriched += 1
    print(f"  已補充 {enriched}/{len(stores)} 筆座標")


def write_csv(stores, output_file):
    """輸出 CSV"""
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["分公司名稱", "電話", "城市", "鄉鎮市區", "詳細地址", "緯度", "經度"])
        for s in stores:
            writer.writerow([
                s["name"],
                format_phone(s["phone"]),
                s["city"],
                s["district"],
                s["address"],
                s["lat"],
                s["lng"],
            ])
    print(f"\n已輸出 {len(stores)} 筆資料到 {output_file}")


def main():
    all_stores = []

    # === 1. 從 findcoupon.tw 爬取台南市門市 ===
    tainan_stores = scrape_findcoupon("台南市")
    all_stores.extend(tainan_stores)

    # === 2. 從 Google Search 取得台南市座標 ===
    phone_to_coords, _ = scrape_google_search("台南50嵐門市")
    enrich_with_coords(tainan_stores, phone_to_coords)

    # === 3. 從 Google Search 爬取高雄市岡山/路竹門市 ===
    for area in ["高雄市岡山", "高雄市路竹"]:
        time.sleep(1)
        coords_map, area_stores = scrape_google_search(f"50嵐 {area}")

        for store in area_stores:
            # 篩選：只要高雄市岡山區或路竹區
            if not any(d in store["district"] for d in FILTER_DISTRICTS):
                continue
            # 用反向地理編碼補充地址
            if not store["address"] and store["lat"] and store["lng"]:
                city, district, detail = reverse_geocode(store["lat"], store["lng"])
                if city:
                    store["city"] = city
                if district:
                    store["district"] = district
                if detail:
                    store["address"] = detail
                time.sleep(1)
            # 避免重複（用純數字比對）
            store_digits = phone_digits(store["phone"])
            if not any(phone_digits(s["phone"]) == store_digits and store_digits for s in all_stores):
                all_stores.append(store)

    # === 4. 輸出 ===
    if not all_stores:
        print("未找到門市資料")
        sys.exit(1)

    # 顯示統計
    from collections import Counter
    cities = Counter(s["city"] for s in all_stores if s["city"])
    print(f"\n共 {len(all_stores)} 間門市")
    print("城市分布:")
    for c, n in cities.most_common():
        print(f"  {c}: {n}")

    has_coords = sum(1 for s in all_stores if s["lat"])
    print(f"有經緯度: {has_coords}")

    # 預覽
    print("\n--- 前 5 筆 ---")
    for s in all_stores[:5]:
        print(f"  {s['name']} | {s['phone']} | {s['city']}{s['district']}{s['address']} | ({s['lat']}, {s['lng']})")

    write_csv(all_stores, OUTPUT_FILE)


if __name__ == "__main__":
    main()
