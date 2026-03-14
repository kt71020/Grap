#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
50嵐-中區門市據點爬蟲
從 Google My Maps KML 匯出資料，解析門市名稱、地址、經緯度
"""

import csv
import re
import sys
import time
import requests
from xml.etree import ElementTree as ET

# Google My Maps ID
MAP_ID = "1uCbn8IMtFQY-6GRbJlzw0ACDC54"
KML_URL = f"https://www.google.com/maps/d/kml?mid={MAP_ID}&forcekml=1"

OUTPUT_FILE = "50lan_中區.csv"

# KML namespace
KML_NS = "{http://www.opengis.net/kml/2.2}"

# 台灣城市與鄉鎮市區對照（用於從地址解析）
CITIES = [
    "基隆市", "台北市", "臺北市", "新北市", "桃園市", "桃園縣",
    "新竹市", "新竹縣", "苗栗縣", "苗栗市",
    "台中市", "臺中市", "台中縣", "臺中縣",
    "彰化縣", "彰化市", "南投縣", "南投市",
    "雲林縣", "嘉義市", "嘉義縣",
    "台南市", "臺南市", "台南縣", "臺南縣",
    "高雄市", "高雄縣", "屏東縣", "宜蘭縣",
    "花蓮縣", "台東縣", "臺東縣",
    "澎湖縣", "金門縣", "連江縣",
    "台北縣", "臺北縣",
]

# 舊地名→新地名對照
CITY_RENAME = {
    "台中縣": "台中市", "臺中縣": "台中市",
    "台南縣": "台南市", "臺南縣": "台南市",
    "台北縣": "新北市", "臺北縣": "新北市",
    "高雄縣": "高雄市", "桃園縣": "桃園市",
}

DISTRICT_PATTERN = re.compile(
    r"([\u4e00-\u9fff]{1,4}(?:區|鎮|鄉|市|島))"
)


def normalize_city(city):
    """統一城市名稱（臺→台）"""
    return city.replace("臺", "台")


def parse_address(address_text):
    """從地址字串解析城市、鄉鎮市區、詳細地址"""
    if not address_text:
        return "", "", ""

    address_text = address_text.strip()
    # 移除各種前綴（ADD:、店址：、住址：等）、郵遞區號、「台灣」
    address_text = re.sub(r"^(ADD|店址|住址|地址)\s*[:：]\s*", "", address_text, flags=re.IGNORECASE)
    address_text = re.sub(r"^[:：]\s*", "", address_text)
    address_text = re.sub(r"^\d{3,5}\s*", "", address_text)
    address_text = re.sub(r"^台灣\s*", "", address_text)
    address_text = re.sub(r"^\d{1,2}/\d{1,2}開幕\s*", "", address_text)
    address_text = re.sub(r"^\d{3,5}\s*", "", address_text)
    city = ""
    district = ""
    detail = address_text

    # 嘗試匹配城市
    for c in sorted(CITIES, key=len, reverse=True):  # 長的優先匹配
        if address_text.startswith(c):
            city = normalize_city(CITY_RENAME.get(c, c))
            detail = address_text[len(c):]
            break

    # 沒有匹配到城市，嘗試用數字開頭的郵遞區號後接城市
    if not city:
        m = re.match(r"\d{3,5}\s*", address_text)
        if m:
            rest = address_text[m.end():]
            for c in sorted(CITIES, key=len, reverse=True):
                if rest.startswith(c):
                    city = normalize_city(CITY_RENAME.get(c, c))
                    detail = rest[len(c):]
                    break
            if not city:
                detail = rest

    # 嘗試匹配鄉鎮市區
    if detail:
        m = DISTRICT_PATTERN.match(detail)
        if m:
            district = m.group(1)
            detail = detail[len(district):]

    return city, district, detail.strip()


def parse_description(desc_html):
    """從 KML description 中提取地址和電話

    格式變化：
    1. 地址:XXX<br>電話:XXX
    2. 地址<br>電話 (無標籤)
    3. 電話<br>地址 (順序相反)
    4. 電話 地址 (同一行無分隔)
    """
    if not desc_html:
        return "", ""

    # 移除 HTML 標籤
    text = re.sub(r"<[^>]+>", "\n", desc_html)
    text = text.replace("&nbsp;", " ").replace("&amp;", "&")
    text = re.sub(r"\n+", "\n", text).strip()

    address = ""
    phone = ""

    lines = [l.strip() for l in text.split("\n") if l.strip()]

    for line in lines:
        # 移除「地址:」「電話:」等前綴標籤
        cleaned = re.sub(r"^(地址|電話|addr|address|tel|phone)\s*[:：]\s*", "", line, flags=re.IGNORECASE).strip()

        # 嘗試提取電話（支援 03-1234567, (03)1234567, 082-337010, (06)926-3838 等）
        phone_match = re.search(r"\(?(0\d{1,3})\)?[\s\-]?\d{3,4}[\s\-]?\d{3,4}", cleaned)

        # 嘗試提取地址（含路/街/巷/弄/號等關鍵字）
        has_address = bool(re.search(r"[路街巷弄號樓]", cleaned))

        if phone_match and has_address and not phone and not address:
            # 同一行包含電話和地址（如 "03-4818881 桃園市楊梅區..."）
            p = phone_match.group(0).strip()
            phone = re.sub(r"[()（）\s]", "", p)  # 正規化電話
            # 移除電話部分取得地址
            addr_part = cleaned[:phone_match.start()] + cleaned[phone_match.end():]
            addr_part = re.sub(r"^[\s,、，]+|[\s,、，]+$", "", addr_part)
            if addr_part:
                address = addr_part
        elif phone_match and not has_address and not phone:
            p = phone_match.group(0).strip()
            phone = re.sub(r"[()（）\s]", "", p)
        elif has_address and not address:
            address = cleaned
            # 如果地址末尾附帶電話（如多個電話），只取地址
            pm = re.search(r"\(?(0\d{1,3})\)?[\s\-]?\d{3,4}[\s\-]?\d{3,4}", address)
            if pm and not phone:
                phone = re.sub(r"[()（）\s]", "", pm.group(0).strip())

    # 從地址中移除前綴（店址：、住址：、冒號、郵遞區號）
    address = re.sub(r"^(店址|住址|地址)\s*[:：]\s*", "", address)
    address = re.sub(r"^[:：]\s*", "", address)
    address = re.sub(r"^\d{3,5}\s*", "", address)
    # 移除「台灣」前綴
    address = re.sub(r"^台灣\s*", "", address)
    # 移除開幕資訊（如 "6/23開幕 "）
    address = re.sub(r"^\d{1,2}/\d{1,2}開幕\s*", "", address)

    return address, phone


def download_kml(url):
    """下載 KML 檔案"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                      "AppleWebKit/537.36 (KHTML, like Gecko) "
                      "Chrome/120.0.0.0 Safari/537.36",
    }
    print(f"正在下載 KML 資料...")
    print(f"URL: {url}")
    resp = requests.get(url, headers=headers, timeout=30)
    resp.raise_for_status()
    print(f"下載完成，大小: {len(resp.content)} bytes")
    return resp.content


def parse_kml(kml_data):
    """解析 KML 取得門市資料"""
    root = ET.fromstring(kml_data)
    stores = []

    # 遞迴找所有 Placemark
    for placemark in root.iter(f"{KML_NS}Placemark"):
        name_el = placemark.find(f"{KML_NS}name")
        if name_el is None:
            continue
        name = name_el.text or ""

        # 取得座標
        lat, lng = "", ""
        coords_el = placemark.find(f".//{KML_NS}coordinates")
        if coords_el is not None and coords_el.text:
            parts = coords_el.text.strip().split(",")
            if len(parts) >= 2:
                lng = parts[0].strip()
                lat = parts[1].strip()

        # 取得 description
        desc_el = placemark.find(f"{KML_NS}description")
        desc_text = desc_el.text if desc_el is not None else ""

        # 也檢查 ExtendedData
        address_from_ext = ""
        phone_from_ext = ""
        ext_data = placemark.find(f"{KML_NS}ExtendedData")
        if ext_data is not None:
            for data in ext_data.iter(f"{KML_NS}Data"):
                attr_name = data.get("name", "")
                value_el = data.find(f"{KML_NS}value")
                value = value_el.text if value_el is not None else ""
                if value:
                    if "地址" in attr_name or "address" in attr_name.lower():
                        address_from_ext = value
                    elif "電話" in attr_name or "phone" in attr_name.lower() or "tel" in attr_name.lower():
                        phone_from_ext = value

        # 從 description 解析
        address, phone = parse_description(desc_text)

        # ExtendedData 優先
        if address_from_ext:
            address = address_from_ext
        if phone_from_ext:
            phone = phone_from_ext

        # 解析地址
        city, district, detail_addr = parse_address(address)

        stores.append({
            "name": name.strip(),
            "phone": phone,
            "city": city,
            "district": district,
            "address": detail_addr,
            "lat": lat,
            "lng": lng,
        })

    return stores


def write_csv(stores, output_file):
    """輸出 CSV"""
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["分公司名稱", "電話", "城市", "鄉鎮市區", "詳細地址", "緯度", "經度"])
        for s in stores:
            writer.writerow([
                s["name"],
                s["phone"],
                s["city"],
                s["district"],
                s["address"],
                s["lat"],
                s["lng"],
            ])
    print(f"\n已輸出 {len(stores)} 筆資料到 {output_file}")


def main():
    try:
        kml_data = download_kml(KML_URL)
    except requests.RequestException as e:
        print(f"下載失敗: {e}")
        sys.exit(1)

    # 儲存原始 KML 供除錯
    kml_file = "50lan_中區.kml"
    with open(kml_file, "wb") as f:
        f.write(kml_data)
    print(f"KML 已儲存至 {kml_file}")

    stores = parse_kml(kml_data)
    print(f"\n共解析到 {len(stores)} 間門市")

    if not stores:
        print("未找到門市資料，請檢查 KML 內容")
        sys.exit(1)

    # 顯示前 5 筆
    print("\n--- 前 5 筆資料預覽 ---")
    for s in stores[:5]:
        print(f"  {s['name']} | {s['phone']} | {s['city']}{s['district']}{s['address']} | ({s['lat']}, {s['lng']})")

    write_csv(stores, OUTPUT_FILE)


if __name__ == "__main__":
    main()
