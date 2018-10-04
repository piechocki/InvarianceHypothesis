import pandas as pd

def get_last_row(source, first_row):

    date = pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', nrows=1, skiprows=first_row)["Date[G]"][0]
    for chunk in pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', chunksize=10000, skiprows=first_row):
        if date != chunk["Date[G]"][10000]:
            for i in range(10000):
                if date != chunk["Date[G]"][i]:
                    chunk[i-1]
    return