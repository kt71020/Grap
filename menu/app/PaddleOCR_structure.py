from paddleocr import PaddleOCR
import os
import json

# 對於結構化分析，你需要使用不同的初始化方式
# 注意：在 3.x 版本中，結構化分析的 API 已經改變

try:
    # 嘗試使用結構化分析
    # 在 3.x 版本中，可能需要安裝額外的依賴
    ocr = PaddleOCR(
        lang='ch',
        use_angle_cls=True,
        show_log=False
    )
    
    img_path = 'IMG_6795.jpg'
    
    # 普通 OCR 識別
    result = ocr.predict(img_path)
    
    # 創建輸出目錄
    os.makedirs('out', exist_ok=True)
    
    # 保存結果為 JSON 格式
    output_data = []
    for idx, res in enumerate(result):
        if res:
            page_data = {
                'page': idx + 1,
                'content': []
            }
            for line in res:
                page_data['content'].append({
                    'bbox': line[0],  # 邊界框座標
                    'text': line[1][0],  # 識別文字
                    'confidence': line[1][1]  # 置信度
                })
            output_data.append(page_data)
    
    # 保存為 JSON
    with open('out/ocr_result.json', 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
    
    # 保存為簡單的文本格式
    with open('out/ocr_result.txt', 'w', encoding='utf-8') as f:
        for page in output_data:
            f.write(f"=== 第 {page['page']} 頁 ===\n")
            for item in page['content']:
                f.write(f"{item['text']}\n")
            f.write("\n")
    
    print("識別完成！")
    print("結果已保存到：")
    print("- out/ocr_result.json (詳細結果)")
    print("- out/ocr_result.txt (純文字)")
    
except Exception as e:
    print(f"錯誤：{e}")
    print("\n如果需要結構化分析（表格識別），請考慮：")
    print("1. 降級到 PaddleOCR 2.x")
    print("2. 或者使用其他替代方案") 
