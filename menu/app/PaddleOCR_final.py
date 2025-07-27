#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PaddleOCR 3.x 菜單識別腳本
修復了所有版本兼容性問題
"""

from paddleocr import PaddleOCR
import os
import json
from datetime import datetime

def create_html_output(results, output_path):
    """創建 HTML 格式的輸出文件"""
    html_content = """
    <!DOCTYPE html>
    <html lang="zh-TW">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>菜單識別結果</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .result-item { margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
            .confidence { color: #666; font-size: 0.9em; }
            .text-content { font-weight: bold; color: #333; }
        </style>
    </head>
    <body>
        <h1>菜單識別結果</h1>
        <p>生成時間：{}</p>
    """.format(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    
    for idx, page_result in enumerate(results):
        if page_result:
            html_content += f"<h2>第 {idx+1} 頁</h2>\n"
            for i, line in enumerate(page_result):
                text = line[1][0]
                confidence = line[1][1]
                html_content += f'<div class="result-item">'
                html_content += f'<div class="text-content">{text}</div>'
                html_content += f'<div class="confidence">置信度: {confidence:.3f}</div>'
                html_content += '</div>\n'
    
    html_content += """
    </body>
    </html>
    """
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html_content)

def main():
    print("🚀 PaddleOCR 3.x 菜單識別工具")
    print("=" * 50)
    
    try:
        # 初始化 PaddleOCR（3.x 版本）
        print("📝 正在初始化 PaddleOCR...")
        ocr = PaddleOCR(lang='ch')
        print("✅ 初始化完成")
        
        # 設定圖片路徑
        img_path = 'IMG_6795.jpg'
        
        # 檢查圖片文件
        if not os.path.exists(img_path):
            print(f"❌ 找不到圖片文件：{img_path}")
            return
        
        print(f"📸 找到圖片：{img_path}")
        print(f"📊 文件大小：{os.path.getsize(img_path):,} bytes")
        
        # 創建輸出目錄
        os.makedirs('out', exist_ok=True)
        
        # 執行 OCR 識別
        print("🔍 開始識別...")
        result = ocr.predict(img_path)
        
        if not result:
            print("❌ 沒有識別到任何內容")
            return
        
        print("✅ 識別完成！")
        print("=" * 50)
        
        # 處理和顯示結果
        all_texts = []
        for page_idx, page_result in enumerate(result):
            print(f"📄 第 {page_idx + 1} 頁:")
            
            if page_result:
                page_texts = []
                for line_idx, line in enumerate(page_result):
                    text = line[1][0]
                    confidence = line[1][1]
                    
                    print(f"  {line_idx + 1:2d}. {text} (置信度: {confidence:.3f})")
                    page_texts.append(text)
                    all_texts.append(text)
                
                # 保存每頁結果
                with open(f'out/page_{page_idx + 1}.txt', 'w', encoding='utf-8') as f:
                    for text in page_texts:
                        f.write(f"{text}\n")
                
                print(f"💾 第 {page_idx + 1} 頁結果保存到：out/page_{page_idx + 1}.txt")
            else:
                print(f"  ⚠️  第 {page_idx + 1} 頁沒有內容")
        
        # 保存所有結果
        if all_texts:
            # 文本格式
            with open('out/all_menu_text.txt', 'w', encoding='utf-8') as f:
                for text in all_texts:
                    f.write(f"{text}\n")
            
            # JSON 格式
            json_data = {
                'timestamp': datetime.now().isoformat(),
                'image': img_path,
                'total_lines': len(all_texts),
                'results': []
            }
            
            for page_idx, page_result in enumerate(result):
                if page_result:
                    page_data = {
                        'page': page_idx + 1,
                        'lines_count': len(page_result),
                        'content': []
                    }
                    for line in page_result:
                        page_data['content'].append({
                            'text': line[1][0],
                            'confidence': line[1][1],
                            'bbox': line[0]
                        })
                    json_data['results'].append(page_data)
            
            with open('out/menu_data.json', 'w', encoding='utf-8') as f:
                json.dump(json_data, f, ensure_ascii=False, indent=2)
            
            # HTML 格式（類似原來的功能）
            create_html_output(result, 'out/menu.html')
            
            print("=" * 50)
            print("📁 所有結果已保存到 out/ 目錄：")
            print("   • all_menu_text.txt - 純文字格式")
            print("   • menu_data.json - JSON 格式詳細數據")
            print("   • menu.html - HTML 格式（可在瀏覽器查看）")
            print(f"   • page_X.txt - 各頁文字 (共 {len(result)} 頁)")
            
            print("🎉 處理完成！")
        else:
            print("⚠️  沒有識別到任何文字")
    
    except Exception as e:
        print(f"❌ 發生錯誤：{e}")
        import traceback
        print("🔍 詳細錯誤信息：")
        traceback.print_exc()

if __name__ == "__main__":
    main() 
