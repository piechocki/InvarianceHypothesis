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
            print("Processing file " + str(i + 1) + " of " +
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

    def get_dataframe_per_iter(self, ticker, iterations):

        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        return pandashelper.get_dataframe_by_iter(source, iterations)

    def get_filtered_dataframes(self, df):

        df.loc[:, "Time[G]"] = pandashelper.pd.to_datetime(
            df["Time[G]"], format="%H:%M:%S.%f")

        df.loc[:, "Time[G]"] = df["Time[G]"] + pandashelper.pd.Timedelta(hours=df["GMT Offset"].iloc[0])
        bod = pandashelper.pd.Timestamp("1900-01-01 09:00:00.000")
        eod = pandashelper.pd.Timestamp("1900-01-01 16:30:00.000")
        df = df.loc[(df["Time[G]"] >= bod) & (df["Time[G]"] <= eod)]

        df_trades = df.query("Type=='Trade' and " +
                             "Qualifiers.str.startswith(' [ACT_FLAG1]')")
        df_quotes = df.query("Type=='Quote'")

        pandashelper.convert_column_to_numeric(df_trades, "Price")
        pandashelper.convert_column_to_numeric(df_trades, "Volume")
        pandashelper.convert_column_to_numeric(df_quotes, "Bid Price")
        pandashelper.convert_column_to_numeric(df_quotes, "Bid Size")
        pandashelper.convert_column_to_numeric(df_quotes, "Ask Price")
        pandashelper.convert_column_to_numeric(df_quotes, "Ask Size")
        df_quotes = self.drop_quotes_prolog(df_quotes)

        return df_trades, df_quotes

    def drop_quotes_prolog(self, df):

        remove = []
        dates = list(df.groupby("Date[G]").groups.keys())
        for date in dates:
            rows_of_day = df.index[df["Date[G]"] == date].tolist()
            valid_rows = df.index[(df["Date[G]"] == date) &
                             (df["Bid Price"] > 0) &
                             (df["Bid Size"] > 0) &
                             (df["Ask Price"] > 0) &
                             (df["Ask Size"] > 0)].tolist()            
            first_valid = valid_rows[0]
            for row in rows_of_day:
                if row < first_valid:
                    remove.append(row)
                else:
                    break
        return df.drop(remove)

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
            df_tail = pandashelper.pd.DataFrame()
            for df in pandashelper.get_dataframe_by_chunks(source):
                print("Processing iteration " + str(j + 1) + " of " +
                      str(max_iter) + " in file " + str(i + 1) + " of " +
                      str(len(self.rows)) + " ...")
                df = pandashelper.concat_dfs(df_tail, df)
                if j < max_iter - 1:
                    last_tail_length = len(df_tail)
                    df, df_tail = self.get_splitted_dataframes(
                        df, ticker, last_tail_length)
                df_trades, df_quotes = self.get_filtered_dataframes(df)
                self.init_aggregation(df_trades, df_quotes)
                j += 1

    def init_aggregation(self, df_trades, df_quotes):

        # distribution = pandashelper.get_distribution(
        #    df_trades, 60, df_trades["Date[G]"].iloc[0])
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
