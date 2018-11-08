import pandas as pd
import numpy as np
import math

names = ['#RIC', 'Date[G]', 'Time[G]', 'GMT Offset', 'Type',
         'Ex/Cntrb.ID', 'Price', 'Volume', 'Bid Price',
         'Bid Size', 'Ask Price', 'Ask Size', 'Qualifiers']
chunk_size = 20000
header = 0
compression = "gzip"  # "infer"
rows_limit_per_iter = 1000000
na_filter = False
low_memory = True
engine = "c"
converters = None


def f(x): return np.NaN if x == "" else float(x)


def i(x): return np.NaN if x == "" else int(x)


def n(x): return pd.to_numeric(x, errors='coerce')


def d(x): return pd.to_datetime(x, format="%H:%M:%S.%f")


def round_seconds_up(x, seconds = 10): return int(math.ceil(x / float(seconds))) * seconds


def round_seconds_down(x, seconds = 10): return x - x%seconds


def round_time(x): return pd.Timestamp(year=1900,
                                       month=1,
                                       day=1,
                                       hour=x.hour,
                                       minute=x.minute,
                                       second=round_seconds_down(x.second))


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
        'sigma_m_log': [],
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
    df["Log Bid"] = np.log(df["Bid Price"])
    df["Log Ask"] = np.log(df["Ask Price"])
    df["Log midpoint"] = (df["Log Bid"] + df["Log Ask"]) / 2

    grouped = df.groupby("Date[G]")
    days = list(grouped.groups.keys())
    
    opening = grouped["Time[G]"].agg(lambda x: x.iloc[0])
    closing = grouped["Time[G]"].agg(lambda x: x.iloc[-1])

    time_even = pd.DataFrame({"Date[G]":[], "Time[G]":[], "Log midpoint":[]})

    for i in range(len(days)):
        day = days[i]
        day_open = pd.Timestamp(year=1900,
                                month=1,
                                day=1,
                                hour=opening[day].hour,
                                minute=opening[day].minute,
                                second=round_seconds_up(opening[day].second))
        day_close = pd.Timestamp(year=1900,
                                 month=1,
                                 day=1,
                                 hour=closing[day].hour,
                                 minute=closing[day].minute,
                                 second=round_seconds_down(closing[day].second))
        ten_sec_series = pd.date_range(day_open, day_close, freq="10S").values
        time_even_day = pd.DataFrame({"Date[G]":day, "Time[G]":ten_sec_series, "Log midpoint":np.nan})
        time_even = time_even.append(time_even_day, ignore_index=True)

    time_all = pd.concat([df[["Date[G]","Time[G]","Log midpoint"]], time_even], ignore_index=True)
    time_all = time_all.sort_values(["Date[G]","Time[G]"])
    realised_stderr = []

    for i in range(len(days)):
        day = days[i]
        # save all midpoints of one day in a new series inclusive all even timestamps with null values
        logs = pd.Series(time_all.loc[time_all['Date[G]'] == day]["Log midpoint"].values, index=time_all.loc[time_all['Date[G]'] == day]["Time[G]"])
        # intepolate all midpoints for even timestamps
        logs.interpolate(method="time", limit_area="inside", inplace=True)
        # prepare a new dataframe with same columns for merging with time_even
        time_even_day = pd.DataFrame({"Date[G]":day, "Time[G]":logs.index.values, "Log midpoint":logs.values})
        # extract only the midpoints for even timestamps and drop all the others
        time_even_day = pd.merge(time_even, time_even_day, on=["Date[G]", "Time[G]"])
        # drop nulls
        time_even_day = time_even_day['Log midpoint_y'].dropna()
        # drop consecutive duplicates (with variance of zero)
        time_even_day = time_even_day.loc[time_even_day.shift() != time_even_day]
        # compute realised standard error and append result to list
        realised_stderr.append(np.std(time_even_day)) # TODO fix error with stderror = nan

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
        'sigma_m_log': realised_stderr,
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

def get_distribution(df, seconds, date):

    df = df[df["Date[G]"]==date]
    df["Time[G]_today"] = df["Time[G]"] + pd.Timedelta("25567 days")
    df["groupby_intervall"] = pd.to_timedelta(df["Time[G]_today"])
    df["groupby_intervall"] = df["groupby_intervall"].dt.total_seconds().astype(int)
    df["groupby_intervall"] = (df["groupby_intervall"] / seconds).apply(np.floor)

    opening = df["Time[G]"].iloc[0]
    closing = df["Time[G]"].iloc[-1]
    day_open = pd.Timestamp(year=1900,
                            month=1,
                            day=1,
                            hour=opening.hour,
                            minute=opening.minute + int(np.floor(round_seconds_up(opening.second, seconds) / 60)),
                            second=round_seconds_up(opening.second, seconds) if seconds < 60 else 0)
    day_close = pd.Timestamp(year=1900,
                                month=1,
                                day=1,
                                hour=closing.hour,
                                minute=closing.minute,
                                second=round_seconds_down(closing.second, seconds))
    df.loc[df["groupby_intervall"]==df["groupby_intervall"].iloc[0], "groupby_intervall"] = np.nan
    df.loc[df["groupby_intervall"]==df["groupby_intervall"].iloc[-1], "groupby_intervall"] = np.nan
    df = df[~np.isnan(df["groupby_intervall"])]
    grouped = df.groupby("groupby_intervall")
    counter = grouped.size().value_counts()    
    
    intervall_series = pd.date_range(day_open, day_close, freq=(str(seconds) + "S")).values
    time_even_day = pd.DataFrame({"Date[G]":date, "Time[G]":intervall_series, "groupby_intervall":np.nan})
    time_all = pd.concat([df[["Date[G]","Time[G]","groupby_intervall"]], time_even_day], ignore_index=True)
    time_all = time_all.sort_values(["Date[G]","Time[G]"])
    counter_zero_intervalls = 0
    for i in range(len(time_all) - 1):
        if np.isnan(time_all["groupby_intervall"].iloc[i]) and np.isnan(time_all["groupby_intervall"].iloc[i + 1]):
            counter_zero_intervalls += 1
    counter[0] = counter_zero_intervalls

    return counter
