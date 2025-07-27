from paddleocr import PaddleOCR
import os

# 初始化 PaddleOCR，使用 3.x 版本的正確參數
ocr = PaddleOCR(
    lang='ch',
    use_angle_cls=True,
    show_log=False
)

img_path = 'IMG_6795.jpg'

# 創建輸出目錄
os.makedirs('out', exist_ok=True)

# 使用新的 predict 方法 (3.x 版本)
result = ocr.predict(img_path)

# 在 3.x 版本中，結果處理更簡單
print("識別結果：")
for idx, res in enumerate(result):
    print(f"第 {idx+1} 页：")
    if res:
        for line in res:
            print(f"位置: {line[0]}, 文字: {line[1][0]}, 置信度: {line[1][1]:.4f}")
        
        # 保存為文本文件
        with open(f'out/result_page_{idx+1}.txt', 'w', encoding='utf-8') as f:
            for line in res:
                f.write(f"{line[1][0]}\n")

print("結果已保存到 out/ 目錄")
