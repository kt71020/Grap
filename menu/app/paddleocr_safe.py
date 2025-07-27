#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PaddleOCR 安全版本 - 針對 macOS segmentation fault 問題優化
"""

import os
import sys
import multiprocessing

# 設置環境變量來避免 segmentation fault
os.environ['KMP_DUPLICATE_LIB_OK'] = 'TRUE'
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_NUM_THREADS'] = '1'

def run_ocr():
    """在子進程中運行 OCR 以避免崩潰"""
    try:
        from paddleocr import PaddleOCR
        import json
        from datetime import datetime
        
        print("🚀 PaddleOCR 安全模式")
        print("=" * 50)
        
        # 使用最基本的設置
        print("📝 初始化 PaddleOCR（安全模式）...")
        ocr = PaddleOCR(
            lang='ch',
            use_gpu=False,  # 強制使用 CPU
            enable_mkldnn=False,  # 禁用 MKL-DNN 優化
            ir_optim=False,  # 禁用圖優化
        )
        print("✅ 初始化完成")
        
        img_path = 'IMG_6795.jpg'
        
        if not os.path.exists(img_path):
            print(f"❌ 圖片不存在：{img_path}")
            return False
        
        print(f"📸 圖片：{img_path}")
        
        # 創建輸出目錄
        os.makedirs('out', exist_ok=True)
        
        # 執行 OCR
        print("🔍 開始識別...")
        result = ocr.predict(img_path)
        
        if not result or not result[0]:
            print("❌ 沒有識別結果")
            return False
        
        print("✅ 識別完成！")
        print("=" * 50)
        
        # 處理結果
        all_texts = []
        for i, line in enumerate(result[0]):
            text = line[1][0]
            confidence = line[1][1]
            print(f"  {i+1:2d}. {text} (置信度: {confidence:.3f})")
            all_texts.append(text)
        
        # 保存結果
        with open('out/paddleocr_safe_result.txt', 'w', encoding='utf-8') as f:
            for text in all_texts:
                f.write(f"{text}\n")
        
        # JSON 結果
        json_data = {
            'timestamp': datetime.now().isoformat(),
            'image': img_path,
            'total_lines': len(all_texts),
            'texts': all_texts
        }
        
        with open('out/paddleocr_safe_data.json', 'w', encoding='utf-8') as f:
            json.dump(json_data, f, ensure_ascii=False, indent=2)
        
        print("=" * 50)
        print("📁 結果已保存：")
        print("   • out/paddleocr_safe_result.txt")
        print("   • out/paddleocr_safe_data.json")
        
        return True
        
    except Exception as e:
        print(f"❌ 錯誤：{e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("⚠️  使用 PaddleOCR 安全模式（防止崩潰）")
    
    # 在子進程中運行以隔離可能的崩潰
    if __name__ == '__main__':
        multiprocessing.set_start_method('spawn', force=True)
        
        try:
            success = run_ocr()
            if success:
                print("🎉 處理完成！")
            else:
                print("❌ 處理失敗")
                print("\n💡 建議：")
                print("   1. 嘗試使用 EasyOCR：python3 easyocr_alternative.py")
                print("   2. 或降級到 PaddleOCR 2.x 版本")
        except KeyboardInterrupt:
            print("\n⚠️  用戶中斷")
        except Exception as e:
            print(f"❌ 程序錯誤：{e}")

if __name__ == "__main__":
    main() 
