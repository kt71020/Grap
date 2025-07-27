#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
DocumentAI to DataFrame 修正版本 - 處理混合表格格式
"""

from google.cloud import documentai  # v1
import pandas as pd
import json
import re
import csv

# 設定參數
project_id = "225239614274" 
location = "us"
processor_id = "fb06e58fb92ec016"
file_path = "ai.png"
mime_type = "image/png"

def extract_text_from_anchor(text_anchor, full_text):
    """從 text_anchor 提取文字"""
    if not text_anchor or not text_anchor.text_segments:
        return ""
    
    segment = text_anchor.text_segments[0]
    return full_text[segment.start_index:segment.end_index].strip()

def extract_text_from_layout(layout, full_text):
    """從 layout 物件提取文字"""
    if not layout or not hasattr(layout, 'text_anchor'):
        return ""
    return extract_text_from_anchor(layout.text_anchor, full_text)

def parse_price_from_text(text):
    """從文字中提取價格"""
    # 匹配各種價格格式：$200, $ 200, 200, 200元 等
    price_patterns = [
        r'\$\s*(\d+)',        # $200, $ 200
        r'(\d+)\s*元',        # 200元
        r'(\d+)$',            # 200 (行尾數字)
        r'NT\$?\s*(\d+)',     # NT$200, NT200
    ]
    
    for pattern in price_patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1)
    return ""

def parse_item_and_price(text):
    """從單一文字中解析商品名稱和價格"""
    # 移除多餘空白
    text = text.strip()
    
    # 嘗試各種格式的分割
    patterns = [
        r'^(.+?)\s+\$\s*(\d+)$',      # 商品名 $200
        r'^(.+?)\s+(\d+)$',           # 商品名 200  
        r'^(.+?)\$(\d+)$',            # 商品名$200
        r'^(.+?)\s+(\d+)元$',         # 商品名 200元
    ]
    
    for pattern in patterns:
        match = re.match(pattern, text)
        if match:
            item_name = match.group(1).strip()
            price = match.group(2).strip() 
            return item_name, price
    
    # 如果無法分割，檢查是否只是價格
    if re.match(r'^\$?\s*\d+$', text):
        return "", text.replace('$', '').strip()
    
    # 否則當作商品名稱
    return text, ""

def generate_standard_csv(verification_csv_path="menu_final_verification.csv", output_path="menu_standard_format.csv"):
    """根據 requirement.md 格式生成標準化 CSV"""
    
    try:
        # 讀取驗證資料
        df = pd.read_csv(verification_csv_path)
        
        # 系列名稱對應編號
        category_mapping = {
            '醬香三杯': 1,
            '秘製醬燒': 2, 
            '麻辣濃香': 3
        }
        
        # 準備輸出資料
        output_lines = []
        
        # 1. 商品分類代碼區段標題
        output_lines.append("---,分隔線,商品分類代碼,---")
        output_lines.append("商品分類編號,商品分類名稱")
        
        # 2. 商品分類清單
        for category, code in category_mapping.items():
            output_lines.append(f"{code},{category}")
        
        # 3. 空行分隔
        output_lines.append("")
        
        # 4. 商品資料區段標題
        output_lines.append("---,分隔線,商品資料---")
        output_lines.append("商品分類編號,選項,價格,名稱,簡單描述,詳細描述")
        
        # 5. 商品資料
        # 按系列分組並排序
        for category in ['醣香三杯', '秘製醬燒', '麻辣濃香']:
            category_items = df[df['系列'] == category].copy()
            if len(category_items) == 0:
                # 處理可能的名稱差異
                category_items = df[df['系列'].str.contains(category.replace('醣', '醬'))].copy()
            
            category_code = category_mapping.get(category.replace('醣', '醬'), 1)
            
            # 按商品名稱排序
            category_items = category_items.sort_values('商品名稱')
            
            for _, item in category_items.iterrows():
                # 格式：商品分類編號,選項,價格,名稱,簡單描述,詳細描述
                line = f"{category_code},,{item['價格']},{item['商品名稱']},,"
                output_lines.append(line)
        
        # 寫入檔案
        with open(output_path, 'w', encoding='utf-8-sig') as f:
            for line in output_lines:
                f.write(line + '\n')
        
        print(f"✅ 已產生標準格式檔案: {output_path}")
        
        # 統計資訊
        total_items = len(df)
        categories = df['系列'].value_counts()
        
        print(f"\n📊 標準格式統計:")
        print(f"總商品數: {total_items}")
        for category, count in categories.items():
            category_code = category_mapping.get(category.replace('醣', '醬'), 0)
            print(f"  {category_code}. {category}: {count}項")
        
        return output_path
        
    except FileNotFoundError:
        print(f"❌ 找不到檔案: {verification_csv_path}")
        return None
    except Exception as e:
        print(f"❌ 產生標準格式檔案時發生錯誤: {str(e)}")
        return None

def document_to_dataframes(document):
    """將 Document 物件轉換成多個 pandas DataFrame"""
    
    dataframes = {}
    
    # 1. 提取表格資料
    tables_data = []
    for page_idx, page in enumerate(document.pages):
        for table_idx, table in enumerate(page.tables):
            
            # 處理表格內容
            for row_idx, row in enumerate(table.body_rows):
                cells = []
                for cell_idx, cell in enumerate(row.cells):
                    cell_text = extract_text_from_anchor(cell.layout.text_anchor, document.text)
                    cells.append(cell_text)
                
                tables_data.append({
                    'page': page_idx,
                    'table': table_idx,
                    'row': row_idx,
                    'cells': cells,
                    'cell_count': len(cells)
                })
    
    if tables_data:
        dataframes['tables'] = pd.DataFrame(tables_data)
        
        # 創建展開的表格資料
        expanded_tables = []
        for _, row in dataframes['tables'].iterrows():
            for cell_idx, cell_content in enumerate(row['cells']):
                expanded_tables.append({
                    'page': row['page'],
                    'table': row['table'],
                    'row': row['row'],
                    'column': cell_idx,
                    'content': cell_content
                })
        
        if expanded_tables:
            dataframes['table_cells'] = pd.DataFrame(expanded_tables)
    
    # 2. 提取表單欄位 (Key-Value pairs) - 修正版本
    form_fields_data = []
    for page_idx, page in enumerate(document.pages):
        for field_idx, kv in enumerate(page.form_fields):
            key = ""
            value = ""
            
            # 提取 key
            if hasattr(kv, 'field_name') and kv.field_name:
                if hasattr(kv.field_name, 'text_anchor'):
                    key = extract_text_from_anchor(kv.field_name.text_anchor, document.text)
                elif hasattr(kv.field_name, 'layout') and kv.field_name.layout:
                    key = extract_text_from_layout(kv.field_name.layout, document.text)
            
            # 提取 value  
            if hasattr(kv, 'field_value') and kv.field_value:
                if hasattr(kv.field_value, 'text_anchor'):
                    value = extract_text_from_anchor(kv.field_value.text_anchor, document.text)
                elif hasattr(kv.field_value, 'layout') and kv.field_value.layout:
                    value = extract_text_from_layout(kv.field_value.layout, document.text)
            
            form_fields_data.append({
                'page': page_idx,
                'field_index': field_idx,
                'key': key,
                'value': value
            })
    
    if form_fields_data:
        dataframes['form_fields'] = pd.DataFrame(form_fields_data)
    
    return dataframes

def extract_menu_items_advanced(table_cells_df):
    """進階菜單項目提取 - 處理混合格式"""
    
    menu_items = []
    
    # 按表格分組處理
    for (page, table), group in table_cells_df.groupby(['page', 'table']):
        print(f"\n🔍 處理表格 {page}-{table}:")
        
        # 按行分組
        for row, row_group in group.groupby('row'):
            row_data = row_group.sort_values('column')
            cells = row_data['content'].tolist()
            
            print(f"  行 {row}: {cells}")
            
            # 跳過空行或只有一個空值的行
            if not cells or all(not cell.strip() for cell in cells):
                continue
            
            # 格式1: 兩欄格式 (商品名 | 價格)
            if len(cells) >= 2 and cells[0].strip() and cells[1].strip():
                item_name = cells[0].strip()
                price = cells[1].strip().replace('$', '').strip()
                
                # 確認第二欄是價格格式
                if re.match(r'^\$?\s*\d+', cells[1]):
                    menu_items.append({
                        'item_name': item_name,
                        'price': price,
                        'extra_info': ' | '.join(cells[2:]) if len(cells) > 2 else '',
                        'source': f'table_{table}_2col'
                    })
                    print(f"    ✅ 兩欄格式: {item_name} - {price}")
                    continue
            
            # 格式2: 單欄格式 (商品名和價格在同一格)
            if len(cells) >= 1 and cells[0].strip():
                cell_text = cells[0].strip()
                
                # 嘗試解析商品名和價格
                item_name, price = parse_item_and_price(cell_text)
                
                if item_name and price:
                    menu_items.append({
                        'item_name': item_name,
                        'price': price,
                        'extra_info': '',
                        'source': f'table_{table}_1col'
                    })
                    print(f"    ✅ 單欄格式: {item_name} - {price}")
                elif item_name and not re.match(r'^\$?\s*\d+$', item_name):
                    # 可能是只有商品名沒有價格的情況
                    print(f"    ⚠️  只有商品名: {item_name}")
    
    return menu_items

def save_dataframes_to_csv(dataframes, prefix="menu_data_fixed"):
    """將 DataFrames 儲存為 CSV 檔案"""
    for name, df in dataframes.items():
        filename = f"{prefix}_{name}.csv"
        df.to_csv(filename, index=False, encoding='utf-8-sig')
        print(f"已儲存 {filename}: {len(df)} 筆資料")

# 主程式執行
if __name__ == "__main__":
    # 建立 DocumentAI 客戶端
    client = documentai.DocumentProcessorServiceClient()
    name = f"projects/{project_id}/locations/{location}/processors/{processor_id}"
    
    # 讀取檔案
    with open(file_path, "rb") as f:
        raw = f.read()
    
    # 建立請求
    request = documentai.ProcessRequest(
        name=name,
        raw_document=documentai.RawDocument(content=raw, mime_type=mime_type),
    )
    
    # 處理文件
    result = client.process_document(request=request)
    document = result.document
    
    # 轉換成 DataFrames
    dataframes = document_to_dataframes(document)
    
    # 顯示結果摘要
    print("=== DocumentAI 解析結果 (修正版) ===")
    print(f"文件全文字數: {len(document.text)}")
    print(f"頁數: {len(document.pages)}")
    
    # 儲存基本 DataFrames
    save_dataframes_to_csv(dataframes, "fixed")
    
    # 進階菜單項目提取
    if 'table_cells' in dataframes:
        print("\n=== 進階菜單項目提取 ===")
        menu_items = extract_menu_items_advanced(dataframes['table_cells'])
        
        if menu_items:
            menu_df = pd.DataFrame(menu_items)
            menu_df.to_csv("menu_items_fixed.csv", index=False, encoding='utf-8-sig')
            
            print(f"\n✅ 已產生修正版商品清單: menu_items_fixed.csv ({len(menu_df)} 項商品)")
            
            # 按來源統計
            source_stats = menu_df['source'].value_counts()
            print("\n📊 解析來源統計:")
            for source, count in source_stats.items():
                print(f"  {source}: {count} 項")
            
            print("\n🍽️ 完整商品清單:")
            for _, item in menu_df.iterrows():
                print(f"  • {item['item_name']}: ${item['price']} ({item['source']})")
        else:
            print("❌ 沒有找到菜單項目")
    
    # 產生標準格式 CSV
    print("\n=== 產生標準格式 CSV ===")
    standard_csv = generate_standard_csv()
    
    if standard_csv:
        print(f"🎯 標準格式檔案已產生完成!")
        print(f"📁 檔案位置: {standard_csv}")
    
    print("\n✅ 修正版處理完成！") 
