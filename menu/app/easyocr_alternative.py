#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EasyOCR 替代方案 - 更適合 macOS
安裝：pip install easyocr
"""

try:
    import easyocr
    import os
    import json
    from datetime import datetime
    
    def main():
        print("🚀 EasyOCR 菜單識別工具（macOS 穩定版）")
        print("=" * 50)
        
        # 初始化 EasyOCR（支援繁體中文和英文）
        print("📝 正在初始化 EasyOCR...")
        reader = easyocr.Reader(['ch_tra', 'en'])  # 繁體中文 + 英文
        # 如果要簡體中文，使用：['ch_sim', 'en']
        print("✅ 初始化完成")
        
        img_path = 'IMG_6795.jpg'
        
        if not os.path.exists(img_path):
            print(f"❌ 找不到圖片文件：{img_path}")
            return
        
        print(f"📸 找到圖片：{img_path}")
        print(f"📊 文件大小：{os.path.getsize(img_path):,} bytes")
        
        # 創建輸出目錄
        os.makedirs('out', exist_ok=True)
        
        # 執行 OCR
        print("🔍 開始識別...")
        results = reader.readtext(img_path)
        
        if not results:
            print("❌ 沒有識別到任何內容")
            return
        
        print("✅ 識別完成！")
        print("=" * 50)
        
        # 處理結果
        all_texts = []
        json_data = {
            'timestamp': datetime.now().isoformat(),
            'image': img_path,
            'total_lines': len(results),
            'results': []
        }
        
        print("📄 識別結果：")
        for i, (bbox, text, confidence) in enumerate(results):
            print(f"  {i+1:2d}. {text} (置信度: {confidence:.3f})")
            all_texts.append(text)
            
            json_data['results'].append({
                'line': i+1,
                'text': text,
                'confidence': confidence,
                'bbox': bbox
            })
        
        # 保存結果
        # 純文字
        with open('out/easyocr_result.txt', 'w', encoding='utf-8') as f:
            for text in all_texts:
                f.write(f"{text}\n")
        
        # JSON 格式
        with open('out/easyocr_data.json', 'w', encoding='utf-8') as f:
            json.dump(json_data, f, ensure_ascii=False, indent=2)
        
        # HTML 格式
        html_content = f"""
        <!DOCTYPE html>
        <html lang="zh-TW">
        <head>
            <meta charset="UTF-8">
            <title>菜單識別結果 - EasyOCR</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .result-item {{ margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }}
                .confidence {{ color: #666; font-size: 0.9em; }}
                .text-content {{ font-weight: bold; color: #333; }}
            </style>
        </head>
        <body>
            <h1>菜單識別結果</h1>
            <p>生成時間：{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
            <p>識別工具：EasyOCR</p>
            <p>總共識別到 {len(results)} 項內容</p>
        """
        
        for i, (bbox, text, confidence) in enumerate(results):
            html_content += f'''
            <div class="result-item">
                <div class="text-content">{i+1}. {text}</div>
                <div class="confidence">置信度: {confidence:.3f}</div>
            </div>
            '''
        
        html_content += """
        </body>
        </html>
        """
        
        with open('out/easyocr_result.html', 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print("=" * 50)
        print("📁 結果已保存到 out/ 目錄：")
        print("   • easyocr_result.txt - 純文字格式")
        print("   • easyocr_data.json - JSON 格式詳細數據")
        print("   • easyocr_result.html - HTML 格式（可在瀏覽器查看）")
        print("🎉 處理完成！")

    if __name__ == "__main__":
        main()

except ImportError:
    print("❌ EasyOCR 未安裝")
    print("💡 請執行以下命令安裝：")
    print("    pip install easyocr")
    print("\n或者使用其他替代方案：")
    print("    pip install pytesseract  # Tesseract OCR")
except Exception as e:
    print(f"❌ 發生錯誤：{e}")
    import traceback
    traceback.print_exc() 
