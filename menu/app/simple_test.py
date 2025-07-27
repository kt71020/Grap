#!/usr/bin/env python3
# -*- coding: utf-8 -*-

print("=== PaddleOCR 簡單測試 ===")

try:
    print("1. 嘗試導入 PaddleOCR...")
    from paddleocr import PaddleOCR
    print("   ✅ 導入成功")
    
    print("2. 嘗試初始化...")
    ocr = PaddleOCR(lang='ch')
    print("   ✅ 初始化成功")
    
    print("3. 檢查圖片文件...")
    import os
    img_path = 'IMG_6795.jpg'
    if os.path.exists(img_path):
        print(f"   ✅ 圖片文件存在：{img_path}")
        print(f"   📊 文件大小：{os.path.getsize(img_path)} bytes")
    else:
        print(f"   ❌ 圖片文件不存在：{img_path}")
        exit(1)
    
    print("4. 嘗試執行 OCR...")
    result = ocr.predict(img_path)
    print("   ✅ OCR 執行完成")
    
    print("5. 檢查結果...")
    if result:
        print(f"   ✅ 有結果，共 {len(result)} 頁")
        for i, page in enumerate(result):
            if page:
                print(f"   📄 第 {i+1} 頁有 {len(page)} 行文字")
                for j, line in enumerate(page[:3]):  # 只顯示前3行
                    print(f"      {j+1}. {line[1][0]}")
                if len(page) > 3:
                    print(f"      ... 還有 {len(page)-3} 行")
            else:
                print(f"   📄 第 {i+1} 頁沒有內容")
    else:
        print("   ❌ 沒有結果")
    
    print("🎉 測試完成！")
    
except ImportError as e:
    print(f"❌ 導入錯誤：{e}")
except Exception as e:
    print(f"❌ 錯誤：{e}")
    import traceback
    traceback.print_exc() 
