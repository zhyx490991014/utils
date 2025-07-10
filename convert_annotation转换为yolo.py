import json
import os

# 图像路径
image_dir = "train_images"

#检查图片分辨率是否都为1280x720
def check_image_resolution(image_dir, expected_size=(1280, 720)):
    for filename in os.listdir(image_dir):
        if filename.endswith(('.jpg', '.jpeg', '.png')):
            img_path = os.path.join(image_dir, filename)
            from PIL import Image
            with Image.open(img_path) as img:
                if img.size != expected_size:
                    print(f"Image {filename} has size {img.size}, expected {expected_size}.")
                    return False
    return True
# 检查图像分辨率
if not check_image_resolution(image_dir):
    print("image_dir: {} contains images with incorrect resolution. Expected 1280x720.".format(image_dir))
    exit(1)

# 输入JSON文件路径
json_path = "train.json"

# 输出YOLO标签目录
output_dir = "labels"

#挑选的图片目录
selected_image_dir = "selected_images"

# 类别映射字典（根据实际修改）
class_map = {"PersonSitting": 0, "Pedestrian": 0}  # 确保与data.yaml一致
# class_map = {"PersonSitting": 0}

# 创建输出目录
os.makedirs(output_dir, exist_ok=True)

# 读取JSON文件
with open(json_path) as f:
    data = json.load(f)

# 按文件名分组标注
annotations = {}
for item in data["annotations"]:
    if item['label'] not in class_map:
        continue
    filename = item["filename"].replace("\\", "/").split("/")[-1]  # 处理路径
    base_name = os.path.splitext(filename)[0]  # 去掉扩展名（如00002）
    if base_name not in annotations:
        annotations[base_name] = []

    # 转换坐标：xyxy绝对像素 → xywh归一化
    img_width, img_height = 1280, 720  # 需替换为实际图像尺寸！
    xmin, ymin, xmax, ymax = item["box"].values()
    if None in (xmin, ymin, xmax, ymax) or xmin < 0 or ymin < 0 or xmax > img_width or ymax > img_height:
        print(f"Warning: Bounding box {item['box']} for {filename} is out of image bounds.")
        continue

    # print("filename: {}".format(filename))
    # print("xmin: {}, ymin: {}, xmax: {}, ymax: {}".format(xmin, ymin, xmax, ymax))
    # print("xmin + xmax: {}, ymin + ymax: {}".format(xmin + xmax, ymin + ymax))
    # continue

    x_center = (xmin + xmax) / 2 / img_width
    y_center = (ymin + ymax) / 2 / img_height
    width = (xmax - xmin) / img_width
    height = (ymax - ymin) / img_height

    annotations[base_name].append(
        f"{class_map[item['label']]} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"
    )

# 写入YOLO标签文件并拷贝图片
for base_name, lines in annotations.items():
    with open(f"{output_dir}/{base_name}.txt", "w") as f:
        f.write("\n".join(lines))
    # 拷贝图片到选定目录
    src_image_path = os.path.join(image_dir, f"{base_name}.jpg")
    if os.path.exists(src_image_path):
        os.makedirs(selected_image_dir, exist_ok=True)
        dst_image_path = os.path.join(selected_image_dir, f"{base_name}.jpg")
        if not os.path.exists(dst_image_path):
            import shutil
            shutil.copy(src_image_path, dst_image_path)
