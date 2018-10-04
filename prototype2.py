import os
import utility

input_folder = "C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/Masterarbeit/Daten/DAX Xetra/"
files = []
for file in os.listdir(input_folder):
    if file.endswith(".csv.gz"):
        files.append(file)

for i in range(0, len(files)):
    source = input_folder + files[i]
    ticker = files[i].split('_')[1]
    date = ""
    first_row = 0
    last_row = 0
    bookmark = 0

    while True:
        first_row = 0 if last_row == 0 else last_row + 1
        last_row = utility.get_last_row(source, first_row)
        