from paddleocr import PaddleOCR
import os
import traceback
import sys

def main():
    try:
        print("🚀 開始初始化 PaddleOCR...")
        
        # 初始化 PaddleOCR，使用 3.x 正確的參數名稱
        ocr = PaddleOCR(
            lang='ch',
            use_textline_orientation=True
        )
        
        img_path = 'IMG_6795.jpg'
        
        # 檢查圖片是否存在
        if not os.path.exists(img_path):
            print(f"❌ 錯誤：找不到圖片文件 {img_path}")
            return
        
        print(f"📸 準備識別圖片：{img_path}")
        
        # 創建輸出目錄
        os.makedirs('out', exist_ok=True)
        
        # 執行 OCR
        print("🔍 正在執行 OCR 識別...")
        result = ocr.ocr(img_path, cls=True)
        
        if not result:
            print("❌ OCR 識別返回空結果")
            return
        
        print("✅ OCR 識別完成！")
        print("=" * 50)
        
        # 處理結果
        all_text = []
        for idx, res in enumerate(result):
            print(f"📄 第 {idx+1} 頁:")
            
            if res:
                page_text = []
                for line_idx, line in enumerate(res):
                    bbox = line[0]  # 座標
                    text = line[1][0]  # 文字
                    confidence = line[1][1]  # 置信度
                    
                    print(f"  {line_idx+1:2d}. {text} (置信度: {confidence:.3f})")
                    page_text.append(text)
                
                all_text.extend(page_text)
                
                # 保存每頁的結果
                with open(f'out/result_page_{idx+1}.txt', 'w', encoding='utf-8') as f:
                    for text in page_text:
                        f.write(f"{text}\n")
                        
                print(f"💾 第 {idx+1} 頁結果已保存到 out/result_page_{idx+1}.txt")
            else:
                print(f"  ⚠️  第 {idx+1} 頁沒有識別到文字")
        
        # 保存所有文字到一個文件
        if all_text:
            with open('out/all_text.txt', 'w', encoding='utf-8') as f:
                for text in all_text:
                    f.write(f"{text}\n")
            print("💾 所有文字已保存到 out/all_text.txt")
        
        print("=" * 50)
        print("🎉 處理完成！")
        print(f"📁 結果保存在 out/ 目錄中")
        
    except ImportError as e:
        print(f"❌ 導入錯誤：{e}")
        print("💡 請確保安裝了 PaddleOCR: pip install paddleocr")
    except Exception as e:
        print(f"❌ 發生錯誤：{e}")
        print("🔍 詳細錯誤信息：")
        traceback.print_exc()

if __name__ == "__main__":
    main() 
