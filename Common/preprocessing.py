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
        self.aggregations = pandas_helper.get_empty_aggregation()

    def init_rows_per_date(self):

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

    def get_filtered_dataframe(self, df, type):
        
        if type != "Trade" and type != "Quote":
            return None
        df.query("Type=='" + type + "'", inplace=True)
        df.query("Qualifiers.str.startswith(' [ACT_FLAG1]')", inplace=True)
        df.loc[:,"Price"] = df["Price"].astype(float)
        df.loc[:,"Volume"] = df["Volume"].astype(int)
        df.loc[:,"Time[G]"] = pandas_helper.to_datetime(df["Time[G]"])
        #df.reset_index(inplace=True, drop=True)
        return df

    def get_splitted_dataframes(self, df, last_tail_length):

        date = df["Date[G]"].iloc[-1]
        ticker = df["#RIC"].iloc[0]
        index = self.rows[ticker][date]
        row = index % pandas_helper.rows_limit_per_iter + last_tail_length
        print(df["Date[G]"].iloc[row-2])
        print(df["Date[G]"].iloc[row-1])
        print(df["Date[G]"].iloc[row])
        print(df["Date[G]"].iloc[row+1])
        print(df["Date[G]"].iloc[row+2])
        return df[:row, :], df[row:, :]

    def get_aggregations(self):

        for i in range(len(self.rows)):
            ticker = list(self.rows)[i]
            count_rows = self.rows[ticker][self.rows[ticker].keys()[-1]]
            max_iter = math.ceil(count_rows / pandas_helper.rows_limit_per_iter)
            for j in range(max_iter):
                print("Processing iteration " + str(j+1) + " of " + str(max_iter) + " in file " + str(i+1) + " of " + str(len(self.rows)) + " ...")
                if j == 0:
                    df_tail = pandas_helper.pd.DataFrame()
                df = self.get_dataframe_per_iter(ticker, j)
                df = self.get_filtered_dataframe(df, "Trade")
                df = pandas_helper.concat_dfs(df, df_tail)
                if j < max_iter-1:
                    last_tail_length = len(df_tail)
                    df, df_tail = self.get_splitted_dataframes(df, last_tail_length)
                self.get_aggregation(df)

    #def get_aggregations(self):

    #    for i in range(len(self.rows)):
    #        ticker = list(self.rows)[i]
    #        for j in range(len(self.rows[ticker])):
    #            print("Processing date " + str(j+1) + " of " + str(len(self.rows[ticker])) + " in file " + str(i+1) + " of " + str(len(self.rows)) + " ...")
    #            date = list(self.rows[ticker])[j]
    #            date_next = list(self.rows[ticker])[j+1] if j+1 < len(self.rows[ticker]) else None
    #            df = self.get_dataframe_per_date(ticker, date, date_next)
    #            df = self.get_filtered_dataframe(df, "Trade")
    #            self.get_aggregation(df)

    def get_aggregation(self, df):

        aggregation = pandas_helper.get_new_aggregation(df)
        self.aggregations = pandas_helper.concat_dfs(self.aggregations, aggregation)
        return aggregation

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

        self.aggregations.to_csv("aggregations.csv")