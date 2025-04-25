
import os
import zipfile

def zip_project(project_dir, output_filename):
    with zipfile.ZipFile(output_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(project_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, project_dir)
                zipf.write(file_path, arcname)

project_dir = 'educational-chatbot'
output_filename = 'educational-chatbot.zip'

zip_project(project_dir, output_filename)
print(f"Project zipped successfully: {output_filename}")
