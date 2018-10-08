import pandas as pd
import numpy as np

names = ['#RIC', 'Date[G]', 'Time[G]', 'GMT Offset', 'Type', 'Ex/Cntrb.ID', 'Price', 'Volume', 'Bid Price', 'Bid Size', 'Ask Price', 'Ask Size', 'Qualifiers']    
chunk_size = 20000
header = 0
compression = "gzip" # "infer"
rows_limit_per_iter = 5000000
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

    skiprows = iter * rows_limit_per_iter
    nrows = rows_limit_per_iter
    return pd.read_csv(source, engine="c", header=None, compression="gzip", na_filter=False, nrows=nrows, skiprows=skiprows, names=names, converters=converters, low_memory=False)

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
        'x': [],
        'X': []
        })

def get_new_aggregation(df):
    
    #grouped = df.groupby("Date[G]")
    #ticker = grouped["#RIC"].agg(lambda x: x.iloc[-1])
    #V = grouped["V"].agg([np.sum])
    #sigma_r = grouped["Return"].agg([np.std])
    #sigma_p = grouped["Price"].agg([np.std])   
    #x = grouped["Volume"].agg([np.mean])
    #X = grouped["Volume"].agg([np.sum])
    #p = grouped["Time delta * P"].agg([np.sum]) / grouped["Time delta"].agg([np.sum])
    #P = grouped["Price"].agg([np.last])
    #date = grouped["Date[G]"].agg(lambda x: x.iloc[0])
    #N = grouped["#RIC"].agg([np.count()])

    ticker = df["#RIC"].iloc[0]

    tickers = []
    dates = []
    Vs = []
    sigma_rs = []
    sigma_ps = []
    ps = []
    Ps = []
    Ns = []
    xs = []
    Xs = []

    for name, group in grouped:
        
        group["V"] = group["Price"] * group["Volume"]
        group["Price-1"] = group["Price"].shift(1) # TODO: ersten (letzten?) wert je datum löschen
        group["Return"] = group["Price"]/group["Price-1"]
        group["Time[G]+1"] = group["Time[G]"].shift(-1) # TODO: ersten (letzten?) wert je datum löschen
        group["Time delta"] = (group["Time[G]+1"]-group["Time[G]"]).astype('timedelta64[ms]')    
        group["Time delta * P"] = group["Time delta"] * group["Price"]
        
        date = str(name)
        V = group["V"].sum()
        sigma_r = group["Return"].sem()
        sigma_p = group["Price"].sem()    
        x = group["Volume"].mean()
        X = group["Volume"].sum()
        p = group["Time delta * P"].sum() / group["Time delta"].sum()
        P = group["Price"].iloc[-1]
        date = str(group["Date[G]"].iloc[0])
        N = len(group)

        tickers.append(ticker)
        dates.append(date)
        Vs.append(V)
        sigma_rs.append(sigma_r)
        sigma_ps.append(sigma_p)
        ps.append(p)
        Ps.append(P)
        Ns.append(N)
        xs.append(x)
        Xs.append(X)

    return pd.DataFrame({
        'ticker': [tickers],
        'date': [dates],
        'V': [Vs],
        'sigma_r': [sigma_rs],
        'sigma_p': [sigma_ps],
        'p': [ps],
        'P': [Ps],
        'N': [Ns],
        'x': [xs],
        'X': [Xs]
        })

def concat_dfs(df1, df2):
    
    return pd.concat([df1, df2])

def to_datetime(df):
    
    return pd.to_datetime(df) #astype(datetime)