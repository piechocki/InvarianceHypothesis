import pandas as pd

path = "C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/Masterarbeit/Testdaten/DAX_20170925.csv"
iter_csv = pd.read_csv(path)
tickers = pd.read_csv(path, usecols=["#RIC"])["#RIC"].unique()
data = {}
for ticker in tickers:
    data[ticker] = iter_csv[iter_csv["#RIC"] == ticker]
    data[ticker] = data[ticker][data[ticker]["Type"] == "Trade"]
print(data["VOWG_p.DE"]["Type"])