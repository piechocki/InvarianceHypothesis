import os
import re
import json
import math
import Util.pandas_helper as pandas_helper


class PreProcessor:

    def __init__(self, input_folder, additional_filter = ""):

        self.input_folder = input_folder if input_folder[-1:] == "/" else input_folder + "/"
        self.files = []
        for file in os.listdir(self.input_folder):
            if file.endswith(".csv.gz") and additional_filter in file:
                self.files.append(file)
        self.rows = {}
        self.aggregations_trades = pandas_helper.get_empty_aggregation_trades()
        self.aggregations_quotes = pandas_helper.get_empty_aggregation_quotes()

    def init_rows_per_date(self):

        print("Getting rows (indices) per ticker and day ... ")
        rows = {}
        for i in range(len(self.files)):
            print("Processing file " + str(i+1) + " of " + str(len(self.files)) + " ...")
            source = self.input_folder + self.files[i]
            ticker = self.files[i].split('_')[1]
            rows[ticker] = pandas_helper.get_dates_with_first_row(source)                
        self.rows = rows

    def get_dataframe_per_date(self, ticker, date, date_next):
        
        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        first_row = self.rows.get(ticker, None).get(date, None)
        last_row = (self.rows.get(ticker, None).get(date_next, None) - 1) if date_next is not None else (-1)
        return pandas_helper.get_dataframe_by_rows(source, first_row, last_row)

    def get_source_by_ticker(self, ticker):

        r = re.compile(r"(\w*)_" + ticker + "_(\w*)")
        file = list(filter(r.match, self.files))[0]
        return self.input_folder + file

    def get_dataframe_per_iter(self, ticker, iter):

        if not self.rows:
            return None
        source = self.get_source_by_ticker(ticker)
        return pandas_helper.get_dataframe_by_iter(source, iter)

    def get_filtered_dataframes(self, df):
        
        df.loc[:,"Time[G]"] = pandas_helper.pd.to_datetime(df["Time[G]"], format="%H:%M:%S.%f")

        df_trades = df.query("Type=='Trade' and Qualifiers.str.startswith(' [ACT_FLAG1]')")
        df_quotes = df.query("Type=='Quote'")

        df_trades.loc[:,"Price"] = pandas_helper.pd.to_numeric(df_trades["Price"], errors="coerce")
        df_trades.loc[:,"Volume"] = pandas_helper.pd.to_numeric(df_trades["Volume"], errors="coerce")
        df_quotes.loc[:,"Bid Price"] = pandas_helper.pd.to_numeric(df_quotes["Bid Price"], errors="coerce")
        df_quotes.loc[:,"Bid Size"] = pandas_helper.pd.to_numeric(df_quotes["Bid Size"], errors="coerce")
        df_quotes.loc[:,"Ask Price"] = pandas_helper.pd.to_numeric(df_quotes["Ask Price"], errors="coerce")
        df_quotes.loc[:,"Ask Size"] = pandas_helper.pd.to_numeric(df_quotes["Ask Size"], errors="coerce")        

        #df.reset_index(inplace=True, drop=True)

        return df_trades, df_quotes

    def get_splitted_dataframes(self, df, ticker, last_tail_length):

        date = str(df["Date[G]"].iloc[-1])
        index = self.rows[ticker][date]
        row = index % pandas_helper.rows_limit_per_iter + last_tail_length
        return df.iloc[:row, :], df.iloc[row:, :]

    def init_aggregations(self):

        print("Getting aggregations per ticker and day ...")
        for i in range(len(self.rows)):
            ticker = list(self.rows)[i]
            source = self.get_source_by_ticker(ticker)
            count_rows = self.rows[ticker][list(self.rows[ticker].keys())[-1]]
            max_iter = math.ceil(count_rows / pandas_helper.rows_limit_per_iter)
            j = 0
            for df in pandas_helper.get_dataframe_by_chunks(source):
                print("Processing iteration " + str(j+1) + " of " + str(max_iter) + " in file " + str(i+1) + " of " + str(len(self.rows)) + " ...")
                if j == 0:
                    df_tail = pandas_helper.pd.DataFrame()
                df = pandas_helper.concat_dfs(df_tail, df)
                if j < max_iter-1:
                    last_tail_length = len(df_tail)
                    df, df_tail = self.get_splitted_dataframes(df, ticker, last_tail_length)
                df_trades, df_quotes = self.get_filtered_dataframes(df)
                self.init_aggregation(df_trades, df_quotes)
                j += 1

    def init_aggregation(self, df_trades, df_quotes):

        aggregation_trades = pandas_helper.get_new_aggregation_trades(df_trades)
        #aggregation_quotes = pandas_helper.get_new_aggregation_quotes(df_quotes)
        self.aggregations_trades = pandas_helper.concat_dfs(self.aggregations_trades, aggregation_trades)
        #self.aggregations_quotes = pandas_helper.concat_dfs(self.aggregations_quotes, aggregation_quotes)

    def save_rows_to_json(self):

        j = json.dumps(self.rows)
        f = open("rows.json","w")
        f.write(j)
        f.close()
    
    def load_rows_per_date(self):
        
        f = open("rows.json")
        self.rows = json.load(f)
        f.close()

    def save_aggregations_to_csv(self):

        self.aggregations_trades.to_csv("trades.csv")
        self.aggregations_quotes.to_csv("quotes.csv")