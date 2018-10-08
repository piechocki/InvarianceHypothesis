import pandas as pd
import numpy as np

names = ['#RIC', 'Date[G]', 'Time[G]', 'GMT Offset', 'Type', 'Ex/Cntrb.ID', 'Price', 'Volume', 'Bid Price', 'Bid Size', 'Ask Price', 'Ask Size', 'Qualifiers']    
chunk_size = 20000
header = 0
compression = "gzip" # "infer"
rows_limit_per_iter = 10000000
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
    reader = pd.read_csv(source, iterator=True, engine="c", low_memory=False, chunksize=chunksize, header=0, compression="gzip", na_filter=False, usecols=["Date[G]"])
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
    
    skiprows = first_row + 1
    nrows = (last_row - first_row + 1) if last_row > 0 else None
    return pd.read_csv(source, engine="c", header=None, compression="gzip", na_filter=False, nrows=nrows, skiprows=skiprows, names=names, converters=converters, low_memory=False)
    
def get_dataframe_by_iter(source, iter):

    skiprows = iter * rows_limit_per_iter + 1
    nrows = rows_limit_per_iter
    return pd.read_csv(source, engine="c", header=None, compression="gzip", na_filter=False, nrows=nrows, skiprows=skiprows, names=names, converters=converters, low_memory=False)

def get_dataframe_by_chunks(source):

    return pd.read_csv(source, engine="c", iterator=True, chunksize=rows_limit_per_iter, header=None, skiprows=1, compression="gzip", na_filter=False, names=names, converters=converters, low_memory=False)

def get_empty_aggregation():

    return pd.DataFrame({
        'ticker': [],
        'date': [],
        'V': [],
        'sigma_r': [],
        'sigma_p': [],
        'p': [],
        'P': [],
        'N': [],
        'X': []
        })

def get_new_aggregation(df):    
    
    df["Price-1"] = df["Price"].shift(1)
    df["Time[G]+1"] = df["Time[G]"].shift(-1)
    
    heads = df.groupby("Date[G]").head(1).index.tolist()
    for i in range(len(heads)):
        df.at[heads[i], "Price-1"] = np.NaN

    tails = df.groupby("Date[G]").tail(1).index.tolist()
    for i in range(len(tails)):
        df.at[tails[i], "Time[G]+1"] = np.NaN

    df["V"] = df["Price"] * df["Volume"]
    df["Return"] = df["Price"] / df["Price-1"]
    df["Time delta"] = (df["Time[G]+1"]-df["Time[G]"]).astype('timedelta64[ms]')    
    df["Time delta * P"] = df["Time delta"] * df["Price"]

    grouped = df.groupby("Date[G]")

    ticker = grouped["#RIC"].agg(lambda x: x.iloc[-1])
    V = grouped["V"].agg([np.sum])["sum"]
    sigma_r = grouped["Return"].agg([np.std])["std"]
    sigma_p = grouped["Price"].agg([np.std]) ["std"]
    X = grouped["Volume"].agg([np.sum])["sum"]
    p = grouped["Time delta * P"].agg([np.sum])["sum"] / grouped["Time delta"].agg([np.sum])["sum"]
    P = grouped["Price"].agg(lambda x: x.iloc[-1])
    date = grouped["Date[G]"].agg(lambda x: x.iloc[-1])
    N = grouped["#RIC"].agg(lambda x: len(x))
    
    return pd.DataFrame({
        'ticker': ticker.tolist(),
        'date': date.tolist(),
        'V': V.tolist(),
        'sigma_r': sigma_r.tolist(),
        'sigma_p': sigma_p.tolist(),
        'p': p.tolist(),
        'P': P.tolist(),
        'N': N.tolist(),
        'X': X.tolist()
        })

def concat_dfs(df1, df2):
    
    return pd.concat([df1, df2])

def to_datetime(df, format=None):
    
    return pd.to_datetime(df, format=format) #astype(datetime)