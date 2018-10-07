import pandas as pd

names = ['#RIC', 'Date[G]', 'Time[G]', 'GMT Offset', 'Type', 'Ex/Cntrb.ID', 'Price', 'Volume', 'Bid Price', 'Bid Size', 'Ask Price', 'Ask Size', 'Qualifiers']    
chunk_size = 20000
header = 0
compression = "gzip" # "infer"
na_filter = False
low_memory = True
engine = "c"
#f = lambda x: float(x)
#i = lambda x: int(x)
#n = lambda x: pd.to_numeric(x)
#d = lambda x: pd.to_datetime(x)
converters=None #{'Price': n, 'Volume': n}

def get_dates_with_first_row(source):

    chunksize = 5000
    reader = pd.read_csv(source, iterator=True, engine="c", low_memory = False, chunksize=chunksize, header=0, compression="gzip", na_filter=False, usecols=["Date[G]"])
    dates = {}
    date = ""
    for row in reader:
        if row["Date[G]"].iloc[-1] != date:
            for i in range(chunksize):
                if date != row["Date[G]"].iloc[i]:
                    date = row["Date[G]"].iloc[i]
                    dates[str(date)] = int(row.index.values.astype(int)[i])
                    break
    return dates

def get_dataframe_by_rows(source, first_row, last_row):
    
    return pd.read_csv(source, compression=compression, header=header, sep=',', quotechar='"', nrows=(last_row-first_row+1 if last_row > 0 else None), na_filter=na_filter, low_memory=low_memory, names=names, engine=engine, skiprows=first_row-1, converters=converters)

def get_empty_aggregation():

    return pd.DataFrame({
        'ticker': [],
        'date': [],
        'V': [],
        'sigma': [],
        'W': [],
        'P': [],
        'N': [],
        'X': []
        })

def get_new_aggregation(df):
    
    print(df["Date[G]"].iloc[0])
    print(df["Date[G]"].iloc[-1])
    ticker = df["#RIC"].iloc[0]
    date = str(df["Date[G]"].iloc[0])
    df["V"] = df["Price"] * df["Volume"]
    V = df["V"].sum()
    sigma = df["Price"].sem()
    W = V * sigma
    P = df["Price"].iloc[-1]
    N = len(df)
    X = df["Volume"].mean()

    return pd.DataFrame({
        'ticker': [ticker],
        'date': [date],
        'V': [V],
        'sigma': [sigma],
        'W': [W],
        'P': [P],
        'N': [N],
        'X': [X]
        })

def concat_dfs(df1, df2):
    
    return pd.concat([df1, df2])