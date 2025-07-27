#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
標準格式 CSV 生成器
根據 requirement.md 格式從 menu_final_verification.csv 生成標準化輸出
"""

import pandas as pd
import os

def generate_standard_csv(verification_csv_path="menu_final_verification.csv", output_path="menu_standard_format.csv"):
    """根據 requirement.md 格式生成標準化 CSV"""
    
    try:
        # 檢查輸入檔案是否存在
        if not os.path.exists(verification_csv_path):
            print(f"❌ 找不到檔案: {verification_csv_path}")
            return None
            
        # 讀取驗證資料
        df = pd.read_csv(verification_csv_path)
        print(f"📖 讀取驗證資料: {len(df)} 筆商品")
        
        # 系列名稱對應編號
        category_mapping = {
            '醬香三杯': 1,
            '秘製醬燒': 2, 
            '麻辣濃香': 3
        }
        
        # 準備輸出資料
        output_lines = []
        
        # 1. 商品分類代碼區段
        output_lines.append("---,分隔線,商品分類代碼,---")
        output_lines.append("商品分類編號,商品分類名稱")
        
        # 2. 商品分類清單
        for category, code in category_mapping.items():
            output_lines.append(f"{code},{category}")
        
        # 3. 空行分隔
        output_lines.append("")
        
        # 4. 商品資料區段
        output_lines.append("---,分隔線,商品資料---")
        output_lines.append("商品分類編號,選項,價格,名稱,簡單描述,詳細描述")
        
        # 5. 商品資料 - 按分類編號排序
        items_added = 0
        for category_name, category_code in category_mapping.items():
            print(f"\n🔍 處理 {category_name} 系列 (編號: {category_code})")
            
            # 找到該系列的商品 (處理可能的字體差異)
            category_items = df[df['系列'].str.contains(category_name.replace('醬', '[醬醣]'), na=False)].copy()
            
            if len(category_items) == 0:
                print(f"  ⚠️  沒有找到 {category_name} 系列的商品")
                continue
            
            # 按商品名稱排序
            category_items = category_items.sort_values('商品名稱')
            
            print(f"  📝 找到 {len(category_items)} 項商品:")
            for _, item in category_items.iterrows():
                # 格式：商品分類編號,選項,價格,名稱,簡單描述,詳細描述
                line = f"{category_code},,{item['價格']},{item['商品名稱']},,"
                output_lines.append(line)
                items_added += 1
                print(f"    • {item['商品名稱']}: ${item['價格']}")
        
        # 寫入檔案
        with open(output_path, 'w', encoding='utf-8-sig') as f:
            for line in output_lines:
                f.write(line + '\n')
        
        print(f"\n✅ 已產生標準格式檔案: {output_path}")
        print(f"📊 共處理 {items_added} 項商品")
        
        # 顯示檔案預覽
        print(f"\n📋 檔案內容預覽:")
        with open(output_path, 'r', encoding='utf-8-sig') as f:
            lines = f.readlines()
            for i, line in enumerate(lines[:15]):  # 顯示前15行
                print(f"  {i+1:2d}: {line.strip()}")
            if len(lines) > 15:
                print(f"  ... (還有 {len(lines)-15} 行)")
        
        return output_path
        
    except Exception as e:
        print(f"❌ 產生標準格式檔案時發生錯誤: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """主程式"""
    print("🚀 標準格式 CSV 生成器")
    print("=" * 50)
    
    # 檢查是否存在驗證檔案
    verification_file = "menu_final_verification.csv"
    if not os.path.exists(verification_file):
        print(f"❌ 找不到驗證檔案: {verification_file}")
        print("請確認 menu_final_verification.csv 存在於當前目錄")
        return
    
    # 生成標準格式 CSV
    result = generate_standard_csv()
    
    if result:
        print(f"\n🎯 成功產生標準格式檔案: {result}")
        print("📁 可用於匯入系統或進一步處理")
    else:
        print("\n❌ 生成失敗")

if __name__ == "__main__":
    main() 
