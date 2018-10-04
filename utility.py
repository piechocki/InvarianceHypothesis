import pandas as pd

def get_next_date_row(source, bookmark):

    if date == "":
        df = pd.read_csv(source, compression='gzip', nrows=2, header=0, sep=',', quotechar='"')
        next_date = df["Date[G]"][0]
    else:
        for chunk in pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', chunksize=10000, skiprows=bookmark):
            if next_date = ""
    return next_date