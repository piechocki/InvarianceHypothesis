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
    
def get_empty_aggregation():

    return pd.DataFrame({
        'ticker': [],
        'date': [],
        'V': [],
        'sigma_r': [],
        'sigma_p': [],
        'W': [],
        'p': [],
        'P': [],
        'N': [],
        'x': [],
        'X': []
        })

def get_new_aggregation(df):
    
    ticker = df["#RIC"].iloc[0]
    date = str(df["Date[G]"].iloc[0])

    df["V"] = df["Price"] * df["Volume"]
    V = df["V"].sum()

    df["Price-1"] = df["Price"].shift(1)
    df["Return"] = df["Price"]/df["Price-1"]
    sigma_r = df["Return"].sem()

    sigma_p = df["Price"].sem()
    W = V * sigma_r
    P = df["Price"].iloc[-1]
    N = len(df)
    x = df["Volume"].mean()
    X = df["Volume"].sum()

    df["Time[G]+1"] = df["Time[G]"].shift(-1)
    df["Time delta"] = (df["Time[G]+1"]-df["Time[G]"]).astype('timedelta64[ms]')    
    df["Time delta * P"] = df["Time delta"] * df["Price"]
    p = df["Time delta * P"].sum() / df["Time delta"].sum()

    return pd.DataFrame({
        'ticker': [ticker],
        'date': [date],
        'V': [V],
        'sigma_r': [sigma_r],
        'sigma_p': [sigma_p],
        'W': [W],
        'p': [p],
        'P': [P],
        'N': [N],
        'x': [x],
        'X': [X]
        })

def concat_dfs(df1, df2):
    
    return pd.concat([df1, df2])

def to_datetime(df):
    
    return pd.to_datetime(df) #astype(datetime)