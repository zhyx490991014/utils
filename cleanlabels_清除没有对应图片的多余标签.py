import json
import os

image_dir = "images"
label_dir = "labels"

#删除labels下无对应images的标签文件
def clean_labels(image_dir, label_dir):
	# 获取所有图像文件的主文件名（不含扩展名）
	image_files = set(os.path.splitext(f)[0] for f in os.listdir(image_dir))

	# 遍历标签目录中的所有标签文件
	for label_file in os.listdir(label_dir):
		if os.path.splitext(label_file)[0] not in image_files:
			# 如果对应的图像文件不存在，删除该标签文件
			os.remove(os.path.join(label_dir, label_file))
			print(f"Removed label file: {label_file}")

if __name__ == "__main__":
	clean_labels(image_dir, label_dir)
	print("Label cleaning completed.")

# This script cleans up the labels directory by removing label files that do not have corresponding images in the images directory.
# It assumes that label files have the same base name as their corresponding image files, with a ".txt" extension for labels and ".jpg" for images.
# Adjust the image file extension in the script if your images are in a different format (e.g., ".png").