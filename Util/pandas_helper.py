import pandas as pd
import numpy as np

names = ['#RIC', 'Date[G]', 'Time[G]', 'GMT Offset', 'Type',
         'Ex/Cntrb.ID', 'Price', 'Volume', 'Bid Price',
         'Bid Size', 'Ask Price', 'Ask Size', 'Qualifiers']
chunk_size = 20000
header = 0
compression = "gzip"  # "infer"
rows_limit_per_iter = 10000000
na_filter = False
low_memory = True
engine = "c"
converters = None


def f(x): return np.NaN if x == "" else float(x)


def i(x): return np.NaN if x == "" else int(x)


def n(x): return pd.to_numeric(x, errors='coerce')


def d(x): return pd.to_datetime(x, format="%H:%M:%S.%f")


def get_dates_with_first_row(source):

    chunksize = 5000
    reader = pd.read_csv(source, iterator=True, engine="c", low_memory=False,
                         chunksize=chunksize, header=0, compression="gzip",
                         na_filter=False, usecols=["Date[G]"])
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
    return pd.read_csv(source, engine="c", header=None, compression="gzip",
                       na_filter=False, nrows=nrows, skiprows=skiprows,
                       names=names, converters=converters,
                       low_memory=False)


def get_dataframe_by_iter(source, iter):

    skiprows = iter * rows_limit_per_iter + 1
    nrows = rows_limit_per_iter
    return pd.read_csv(source, engine="c", header=None, compression="gzip",
                       na_filter=False, nrows=nrows, skiprows=skiprows,
                       names=names, converters=converters,
                       low_memory=False)


def get_dataframe_by_chunks(source):

    return pd.read_csv(source, engine="c", iterator=True,
                       chunksize=rows_limit_per_iter, header=None,
                       skiprows=1, compression="gzip", na_filter=False,
                       names=names, converters=converters,
                       low_memory=False)


def get_empty_aggregation_trades():

    return pd.DataFrame({
        'ticker': [],
        'date': [],
        'V': [],
        'sigma_r': [],
        'sigma_p': [],
        'P': [],
        'N': [],
        'X': [],
        'Open': [],
        'Close': [],
        'High': [],
        'Low': []
        })


def get_empty_aggregation_quotes():

    return pd.DataFrame({
        'ticker': [],
        'date': [],
        'N': [],
        'sigma_s': [],
        'sigma_m': [],
        'bid_price': [],
        'bid_size': [],
        'ask_price': [],
        'ask_size': [],
        'rel_spread': []
        })


def get_new_aggregation_quotes(df):

    df["Time[G]+1"] = df["Time[G]"].shift(-1)
    tails = df.groupby("Date[G]").tail(1).index.tolist()
    for i in range(len(tails)):
        df.at[tails[i], "Time[G]+1"] = np.NaN

    df["Time delta"] = (df["Time[G]+1"]-df["Time[G]"]).astype(
        'timedelta64[ms]')

    df["Bid Price"] = df["Bid Price"].fillna(method="ffill")
    df["Bid Size"] = df["Bid Size"].fillna(method="ffill")
    df["Ask Price"] = df["Ask Price"].fillna(method="ffill")
    df["Ask Size"] = df["Ask Size"].fillna(method="ffill")

    df["Absolute spread"] = df["Ask Price"] - df["Bid Price"]
    df["Mid quote"] = (df["Ask Price"] + df["Bid Price"]) / 2
    df["Relative spread"] = df["Absolute spread"] / df["Mid quote"] * 10000
    df["Time delta * Relative spread"] = df["Time delta"] * \
        df["Relative spread"]
    df["Time delta * Bid Price"] = df["Time delta"] * df["Bid Price"]
    df["Time delta * Bid Size"] = df["Time delta"] * df["Bid Size"]
    df["Time delta * Ask Price"] = df["Time delta"] * df["Ask Price"]
    df["Time delta * Ask Size"] = df["Time delta"] * df["Ask Size"]

    grouped = df.groupby("Date[G]")

    ticker = grouped["#RIC"].agg(lambda x: x.iloc[-1])
    sigma_s = grouped["Absolute spread"].agg([np.std])["std"]
    sigma_m = grouped["Mid quote"].agg([np.std])["std"]
    divisor = grouped["Time delta"].agg([np.sum])["sum"]
    bid_price = grouped["Time delta * Bid Price"].agg([np.sum])["sum"] \
        / divisor
    bid_size = grouped["Time delta * Bid Size"].agg([np.sum])["sum"] \
        / divisor
    ask_price = grouped["Time delta * Ask Price"].agg([np.sum])["sum"] \
        / divisor
    ask_size = grouped["Time delta * Ask Size"].agg([np.sum])["sum"] \
        / divisor
    rel_spread = grouped["Time delta * Relative spread"].\
        agg([np.sum])["sum"] / divisor
    date = grouped["Date[G]"].agg(lambda x: x.iloc[-1])
    N = grouped["#RIC"].agg(lambda x: len(x))

    return pd.DataFrame({
        'ticker': ticker.tolist(),
        'date': date.tolist(),
        'N': N.tolist(),
        'sigma_s': sigma_s.tolist(),
        'sigma_m': sigma_m.tolist(),
        'bid_price': bid_price.tolist(),
        'bid_size': bid_size.tolist(),
        'ask_price': ask_price.tolist(),
        'ask_size': ask_size.tolist(),
        'rel_spread': rel_spread.tolist()
        })


def get_new_aggregation_trades(df):

    df["Price-1"] = df["Price"].shift(1)
    heads = df.groupby("Date[G]").head(1).index.tolist()
    for i in range(len(heads)):
        df.at[heads[i], "Price-1"] = np.NaN

    df["Time[G]+1"] = df["Time[G]"].shift(-1)
    tails = df.groupby("Date[G]").tail(1).index.tolist()
    for i in range(len(tails)):
        df.at[tails[i], "Time[G]+1"] = np.NaN

    df["V"] = df["Price"] * df["Volume"]
    df["Return"] = df["Price"] / df["Price-1"]
    df["Time delta"] = (df["Time[G]+1"]-df["Time[G]"]).astype(
        'timedelta64[ms]')
    df["Time delta * P"] = df["Time delta"] * df["Price"]

    grouped = df.groupby("Date[G]")

    ticker = grouped["#RIC"].agg(lambda x: x.iloc[-1])
    V = grouped["V"].agg([np.sum])["sum"]
    sigma_r = grouped["Return"].agg([np.std])["std"]
    sigma_p = grouped["Price"].agg([np.std])["std"]
    X = grouped["Volume"].agg([np.sum])["sum"]
    P = grouped["Time delta * P"].agg([np.sum])["sum"] \
        / grouped["Time delta"].agg([np.sum])["sum"]
    Open = grouped["Price"].agg(lambda x: x.iloc[0])
    Close = grouped["Price"].agg(lambda x: x.iloc[-1])
    High = grouped["Price"].agg([np.amax])["amax"]
    Low = grouped["Price"].agg([np.amin])["amin"]
    date = grouped["Date[G]"].agg(lambda x: x.iloc[-1])
    N = grouped["#RIC"].agg(lambda x: len(x))

    return pd.DataFrame({
        'ticker': ticker.tolist(),
        'date': date.tolist(),
        'V': V.tolist(),
        'sigma_r': sigma_r.tolist(),
        'sigma_p': sigma_p.tolist(),
        'P': P.tolist(),
        'N': N.tolist(),
        'X': X.tolist(),
        'Open': Open.tolist(),
        'Close': Close.tolist(),
        'High': High.tolist(),
        'Low': Low.tolist()
        })


def concat_dfs(df1, df2):

    return pd.concat([df1, df2])


# converters = {'Price': n, 'Volume': n, 'Time[G]': d, 'Bid Price': n,
#               'Bid Size': n, 'Ask Price': n, 'Ask Size': n}
