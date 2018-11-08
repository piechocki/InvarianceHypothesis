import os
import re
import json
import math
import Util.pandashelper as pandashelper


class PreProcessor:

    def __init__(self, input_folder, additional_filter=""):

        self.input_folder = input_folder if input_folder[-1:] == \
            "/" else input_folder + "/"
        self.marketplace = self.get_marketplace() if additional_filter == \
            "" else self.get_marketplace() + " " + additional_filter[1:3]
        self.files = []
        for file in os.listdir(self.input_folder):
            if file.endswith(".csv.gz") and additional_filter in file:
                self.files.append(file)
        self.rows = {}
        self.aggregations_trades = pandashelper.get_empty_aggregation_trades()
        self.aggregations_quotes = pandashelper.get_empty_aggregation_quotes()

    def init_rows_per_date(self):

        print("Getting rows (indices) per ticker and day ... ")
        rows = {}
        for i in range(len(self.files)):
            print("Processing file " + str(i+1) + " of " +
                  str(len(self.files)) + " ...")
            source = self.input_folder + self.files[i]
            ticker = self.files[i].split('_')[1]
            rows[ticker] = pandashelper.get_dates_with_first_row(source)
        self.rows = rows

    def get_dataframe_per_date(self, ticker, date, date_next):

        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        first_row = self.rows.get(ticker, None).get(date, None)
        last_row = (self.rows.get(ticker, None).get(date_next, None) - 1) \
            if date_next is not None else (-1)
        return pandashelper.get_dataframe_by_rows(source, first_row, last_row)

    def get_source_by_ticker(self, ticker):

        r = re.compile("(\\w*)_" + ticker + "_(\\w*)")
        file = list(filter(r.match, self.files))[0]
        return self.input_folder + file

    def get_dataframe_per_iter(self, ticker, iter):

        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        return pandashelper.get_dataframe_by_iter(source, iter)

    def get_filtered_dataframes(self, df):

        df.loc[:, "Time[G]"] = pandashelper.pd.to_datetime(
            df["Time[G]"], format="%H:%M:%S.%f")

        df_trades = df.query("Type=='Trade' and " +
                             "Qualifiers.str.startswith(' [ACT_FLAG1]')")
        df_quotes = df.query("Type=='Quote'")

        df_trades.loc[:, "Price"] = pandashelper.pd.to_numeric(
            df_trades["Price"], errors="coerce")
        df_trades.loc[:, "Volume"] = pandashelper.pd.to_numeric(
            df_trades["Volume"], errors="coerce")
        df_quotes.loc[:, "Bid Price"] = pandashelper.pd.to_numeric(
            df_quotes["Bid Price"], errors="coerce")
        df_quotes.loc[:, "Bid Size"] = pandashelper.pd.to_numeric(
            df_quotes["Bid Size"], errors="coerce")
        df_quotes.loc[:, "Ask Price"] = pandashelper.pd.to_numeric(
            df_quotes["Ask Price"], errors="coerce")
        df_quotes.loc[:, "Ask Size"] = pandashelper.pd.to_numeric(
            df_quotes["Ask Size"], errors="coerce")

        return df_trades, df_quotes

    def get_splitted_dataframes(self, df, ticker, last_tail_length):

        date = str(df["Date[G]"].iloc[-1])
        index = self.rows[ticker][date]
        row = index % pandashelper.rows_limit_per_iter + last_tail_length
        return df.iloc[:row, :], df.iloc[row:, :]

    def init_aggregations(self):

        print("Getting aggregations per ticker and day ...")
        for i in range(len(self.rows)):
            ticker = list(self.rows)[i]
            source = self.get_source_by_ticker(ticker)
            count_rows = self.rows[ticker][list(self.rows[ticker].keys())[-1]]
            max_iter = math.ceil(count_rows /
                                 pandashelper.rows_limit_per_iter)
            j = 0
            for df in pandashelper.get_dataframe_by_chunks(source):
                print("Processing iteration " + str(j+1) + " of " +
                      str(max_iter) + " in file " + str(i+1) + " of " +
                      str(len(self.rows)) + " ...")
                if j == 0:
                    df_tail = pandashelper.pd.DataFrame()
                df = pandashelper.concat_dfs(df_tail, df)
                if j < max_iter-1:
                    last_tail_length = len(df_tail)
                    df, df_tail = self.get_splitted_dataframes(
                        df, ticker, last_tail_length)
                df_trades, df_quotes = self.get_filtered_dataframes(df)
                self.init_aggregation(df_trades, df_quotes)
                j += 1

    def init_aggregation(self, df_trades, df_quotes):

        distribution = pandashelper.get_distribution(df_trades, 60, df_trades["Date[G]"].iloc[0])
        distribution.to_csv("Verteilung.csv")
        aggregation_trades = pandashelper.get_new_aggregation_trades(
            df_trades)
        aggregation_quotes = pandashelper.get_new_aggregation_quotes(
            df_quotes)
        self.aggregations_trades = pandashelper.concat_dfs(
            self.aggregations_trades, aggregation_trades)
        self.aggregations_quotes = pandashelper.concat_dfs(
            self.aggregations_quotes, aggregation_quotes)

    def save_rows_to_json(self):

        j = json.dumps(self.rows)
        f = open(self.marketplace + ".json", "w")
        f.write(j)
        f.close()

    def load_rows_per_date(self):

        f = open(self.marketplace + ".json")
        self.rows = json.load(f)
        f.close()

    def load_aggregations(self):

        self.aggregations_trades = pandashelper.pd.read_csv(
            self.marketplace + " Trades.csv", header=0)
        self.aggregations_quotes = pandashelper.pd.read_csv(
            self.marketplace + " Quotes.csv", header=0)

    def save_aggregations_to_csv(self):

        self.aggregations_trades.to_csv(
            self.marketplace + " Trades.csv", index=False)
        self.aggregations_quotes.to_csv(
            self.marketplace + " Quotes.csv", index=False)

    def get_marketplace(self):

        return self.input_folder[:-1].rsplit('/', 1)[1]
