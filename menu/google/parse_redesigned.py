#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
重新設計的菜單解析器 - 能處理不同商店格式並自動提取分類
"""

from google.cloud import documentai
import pandas as pd
import json
import re
import csv
from collections import defaultdict

class SmartMenuParser:
    def __init__(self, project_id, location, processor_id):
        self.project_id = project_id
        self.location = location
        self.processor_id = processor_id
        self.client = documentai.DocumentProcessorServiceClient()
        
        # 自動提取的資料結構
        self.shop_info = {}
        self.categories = {}  # 自動發現的分類
        self.menu_items = []
        self.options = {}     # 共用選項
        self.option_prices = {}  # 選項價格
    
    def extract_text_from_anchor(self, text_anchor, full_text):
        """從 text_anchor 提取文字"""
        if not text_anchor or not text_anchor.text_segments:
            return ""
        segment = text_anchor.text_segments[0]
        return full_text[segment.start_index:segment.end_index].strip()
    
    def detect_shop_info(self, document):
        """從文件中自動提取商店資訊"""
        text = document.text
        
        # 使用正則表達式提取各種資訊
        patterns = {
            'phone': r'(\(?\d{2,3}\)?[-\s]?\d{3,4}[-\s]?\d{3,4})',
            'address': r'([台臺]北市|新北市|台中市|高雄市|台南市|基隆市|新竹市|嘉義市|宜蘭縣|新竹縣|苗栗縣|彰化縣|南投縣|雲林縣|嘉義縣|屏東縣|台東縣|花蓮縣|澎湖縣|金門縣|連江縣).*?[路街巷弄號][\d號]*',
            'name': r'^[^\n]*店|^[^\n]*餐廳|^[^\n]*小吃|^[^\n]*美食'
        }
        
        for key, pattern in patterns.items():
            matches = re.findall(pattern, text, re.MULTILINE | re.UNICODE)
            if matches:
                self.shop_info[key] = matches[0]
    
    def auto_detect_categories(self, menu_items):
        """自動偵測商品分類"""
        categories = set()
        
        # 方法1: 從表格結構推斷（如果有明確的分類標題行）
        for item in menu_items:
            if 'category_hint' in item:
                categories.add(item['category_hint'])
        
        # 方法2: 從商品名稱推斷常見分類關鍵字
        category_keywords = {
            '飲品': ['茶', '咖啡', '果汁', '奶茶', '拿鐵', '可樂', '汽水'],
            '主餐': ['飯', '麵', '排', '雞腿', '牛肉', '豬肉', '魚'],  
            '小菜': ['泡菜', '豆腐', '海帶', '筍乾', '滷蛋'],
            '湯品': ['湯', '羹', '鍋'],
            '甜點': ['蛋糕', '布丁', '冰淇淋', '奶酪'],
        }
        
        # 如果沒有明確分類，使用關鍵字分類
        if not categories:
            for item in menu_items:
                item_name = item.get('item_name', '')
                matched_category = None
                
                for category, keywords in category_keywords.items():
                    if any(keyword in item_name for keyword in keywords):
                        matched_category = category
                        break
                
                if matched_category:
                    categories.add(matched_category)
                    item['auto_category'] = matched_category
                else:
                    # 預設分類
                    categories.add('其他')
                    item['auto_category'] = '其他'
        
        # 建立分類編號對應
        self.categories = {cat: idx+1 for idx, cat in enumerate(sorted(categories))}
        return self.categories
    
    def extract_menu_items_enhanced(self, document):
        """增強版菜單項目提取 - 包含分類偵測"""
        dataframes = self.document_to_dataframes(document)
        menu_items = []
        
        if 'table_cells' in dataframes:
            table_cells_df = dataframes['table_cells']
            
            # 按表格分組處理
            for (page, table), group in table_cells_df.groupby(['page', 'table']):
                current_category = None
                
                # 按行分組
                for row, row_group in group.groupby('row'):
                    row_data = row_group.sort_values('column')
                    cells = row_data['content'].tolist()
                    
                    # 跳過空行
                    if not cells or all(not cell.strip() for cell in cells):
                        continue
                    
                    # 檢查是否為分類標題行（通常只有一欄且不包含價格）
                    if len(cells) == 1 and not re.search(r'\$?\d+', cells[0]):
                        potential_category = cells[0].strip()
                        if len(potential_category) < 20:  # 分類名稱通常較短
                            current_category = potential_category
                            continue
                    
                    # 提取商品資料
                    item_data = self.parse_menu_row(cells)
                    if item_data:
                        if current_category:
                            item_data['category_hint'] = current_category
                        menu_items.append(item_data)
        
        self.menu_items = menu_items
        return menu_items
    
    def parse_menu_row(self, cells):
        """解析菜單行資料"""
        if len(cells) >= 2:
            # 兩欄格式：商品名 | 價格
            item_name = cells[0].strip()
            price_text = cells[1].strip()
            
            if re.search(r'\$?\d+', price_text):
                price = re.search(r'\d+', price_text).group()
                return {
                    'item_name': item_name,
                    'price': price,
                    'format': '2col'
                }
        
        elif len(cells) == 1:
            # 單欄格式：商品名 + 價格
            cell_text = cells[0].strip()
            match = re.match(r'^(.+?)\s+\$?(\d+)$', cell_text)
            if match:
                return {
                    'item_name': match.group(1).strip(),
                    'price': match.group(2),
                    'format': '1col'
                }
        
        return None
    
    def document_to_dataframes(self, document):
        """將 Document 轉換為 DataFrames"""
        dataframes = {}
        
        # 提取表格資料
        expanded_tables = []
        for page_idx, page in enumerate(document.pages):
            for table_idx, table in enumerate(page.tables):
                for row_idx, row in enumerate(table.body_rows):
                    for cell_idx, cell in enumerate(row.cells):
                        cell_text = self.extract_text_from_anchor(cell.layout.text_anchor, document.text)
                        expanded_tables.append({
                            'page': page_idx,
                            'table': table_idx,
                            'row': row_idx,
                            'column': cell_idx,
                            'content': cell_text
                        })
        
        if expanded_tables:
            dataframes['table_cells'] = pd.DataFrame(expanded_tables)
        
        return dataframes
    
    def generate_complete_csv(self, output_path="menu_complete_standard.csv"):
        """生成完整的標準格式CSV"""
        
        if not self.menu_items:
            print("❌ 沒有菜單項目資料，無法生成CSV")
            return None
        
        # 自動偵測分類
        self.auto_detect_categories(self.menu_items)
        
        output_lines = []
        
        # 1. 商店資訊區段
        output_lines.append("---,分隔線,商店資訊---")
        output_lines.append(f"公司名稱,{self.shop_info.get('name', '未知商店')}")
        output_lines.append(f"城市,{self.extract_city(self.shop_info.get('address', ''))}")
        output_lines.append(f"鄉鎮市區,{self.extract_district(self.shop_info.get('address', ''))}")
        output_lines.append(f"詳細地址,{self.shop_info.get('address', '')}")
        output_lines.append(f"電話,{self.shop_info.get('phone', '')}")
        output_lines.append("介紹,")
        output_lines.append("訂購備註,")
        output_lines.append("")
        
        # 2. 商品分類代碼區段
        output_lines.append("---,分隔線,商品分類代碼,---")
        output_lines.append("商品分類編號,商品分類名稱")
        for category, code in self.categories.items():
            output_lines.append(f"{code},{category}")
        output_lines.append("")
        
        # 3. 共用選項代碼區段（暫時留空，可擴展）
        output_lines.append("---,分隔線,共用選項代碼,---")
        output_lines.append("選項編號,選項名稱,必選項目")
        output_lines.append("")
        
        # 4. 共用選項價格代碼區段（暫時留空，可擴展）
        output_lines.append("---,分隔線,共用選項價格代碼,---")
        output_lines.append("選項編號,名稱,價格")
        output_lines.append("")
        
        # 5. 商品資料區段
        output_lines.append("---,分隔線,商品資料---")
        output_lines.append("商品分類編號,選項,價格,名稱,簡單描述,詳細描述")
        
        # 按分類分組商品
        for item in self.menu_items:
            category = item.get('category_hint') or item.get('auto_category', '其他')
            category_code = self.categories.get(category, 1)
            
            line = f"{category_code},,{item['price']},{item['item_name']},,"
            output_lines.append(line)
        
        # 寫入檔案
        with open(output_path, 'w', encoding='utf-8-sig') as f:
            for line in output_lines:
                f.write(line + '\n')
        
        print(f"✅ 已產生完整標準格式檔案: {output_path}")
        return output_path
    
    def extract_city(self, address):
        """從地址中提取城市"""
        match = re.search(r'([台臺]北市|新北市|台中市|高雄市|台南市|基隆市|新竹市|嘉義市|宜蘭縣|新竹縣|苗栗縣|彰化縣|南投縣|雲林縣|嘉義縣|屏東縣|台東縣|花蓮縣|澎湖縣|金門縣|連江縣)', address)
        return match.group(1) if match else ""
    
    def extract_district(self, address):
        """從地址中提取區域"""
        match = re.search(r'([東西南北中]?[區市鎮鄉])', address)
        return match.group(1) if match else ""
    
    def process_menu_image(self, file_path, mime_type="image/png"):
        """處理菜單圖片的完整流程"""
        print(f"🔄 開始處理菜單圖片: {file_path}")
        
        # 建立處理請求
        name = f"projects/{self.project_id}/locations/{self.location}/processors/{self.processor_id}"
        
        with open(file_path, "rb") as f:
            raw = f.read()
        
        request = documentai.ProcessRequest(
            name=name,
            raw_document=documentai.RawDocument(content=raw, mime_type=mime_type),
        )
        
        # 處理文件
        result = self.client.process_document(request=request)
        document = result.document
        
        # 提取各種資訊
        print("📊 提取商店資訊...")
        self.detect_shop_info(document)
        
        print("🍽️ 提取菜單項目...")
        menu_items = self.extract_menu_items_enhanced(document)
        
        print("🏷️ 自動偵測商品分類...")
        categories = self.auto_detect_categories(menu_items)
        
        # 產生標準CSV
        print("📝 產生標準格式CSV...")
        csv_path = self.generate_complete_csv()
        
        # 顯示統計
        print(f"\n📈 處理結果統計:")
        print(f"商店資訊: {len([k for k, v in self.shop_info.items() if v])}/{len(self.shop_info)} 項")
        print(f"商品分類: {len(categories)} 類")
        print(f"商品項目: {len(menu_items)} 項")
        
        return csv_path


# 使用範例
if __name__ == "__main__":
    # 設定參數（這些應該從設定檔讀取）
    PROJECT_ID = "225239614274"
    LOCATION = "us" 
    PROCESSOR_ID = "fb06e58fb92ec016"
    FILE_PATH = "ai.png"
    
    # 建立智能解析器
    parser = SmartMenuParser(PROJECT_ID, LOCATION, PROCESSOR_ID)
    
    # 處理菜單圖片
    result_csv = parser.process_menu_image(FILE_PATH)
    
    if result_csv:
        print(f"🎉 處理完成！結果檔案: {result_csv}")
    else:
        print("❌ 處理失敗") 
