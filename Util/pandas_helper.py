import pandas as pd
chunk_size = 10000

def get_date_with_last_row(source, first_row):

    date = pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', nrows=1, skiprows=first_row-1, usecols=["Date[G]"])["Date[G]"].head(1)

    #while True:
    #    first_row += chunk_size
    #    date_new = pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', nrows=1, skiprows=first_row-1, usecols=["Date[G]"])["Date[G]"].head(1)
    #    if date != date_new:
    #        break
    #chunk = pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', chunksize=chunk_size, skiprows=first_row-1-chunk_size, usecols=["Date[G]"])
    #for i in range(chunk_size):
    #    if date != chunk["Date[G]"][i]:
    #        last_row = chunk.index[chunk[i]] - 1
    #        return date, last_row

    for chunk in pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', chunksize=chunk_size, skiprows=first_row, usecols=["Date[G]"]):
        if date != chunk["Date[G]"].tail(1):
            for i in range(chunk_size):
                if date != chunk["Date[G]"][i]:
                    last_row = chunk.index[chunk[i]] - 1
                    return date, last_row
    return None, None

def get_dataframe_by_rows(source, first_row, last_row):
    # converters={'salary': lambda x: float(x.replace('$', ''))}
    return pd.read_csv(source, compression='gzip', header=0, sep=',', quotechar='"', nrows=last_row-first_row+1, skiprows=first_row-1)

def get_empty_aggregation():

    return pd.DataFrame({'date': [], 'number_trades': []})

def get_new_aggregation(df):
    
    date = df["Date[G]"].head(0)
    number_trades = len(df)
    number_shares_sum = df["Quantity"].sum()
    number_shares_avg = df["Quantity"].mean()
    return pd.DataFrame({'date': date, 'number_trades': number_trades})

def concat_dfs(df1, df2):
    
    return pd.concat([df1, df2])