import os
import re
import json
import Util.pandas_helper as pandas_helper

class PreProcessor:

    def __init__(self, input_folder):

        self.input_folder = input_folder if input_folder[-1:] == "/" else input_folder + "/"
        self.files = []
        for file in os.listdir(self.input_folder):
            if file.endswith(".csv.gz"):
                self.files.append(file)
        self.rows = {}
        self.aggregations = pandas_helper.get_empty_aggregation()

    def init_rows_per_date(self):

        rows = {}
        for i in range(len(self.files)):
            source = self.input_folder + self.files[i]
            ticker = self.files[i].split('_')[1]
            rows[ticker] = pandas_helper.get_dates_with_first_row(source)                
        self.rows = rows

    def get_dataframe_per_date(self, ticker, date, date_next):
        
        if self.rows is None:
            return None
        r = re.compile(r"(\w*)_" + ticker + "_(\w*)")
        file = list(filter(r.match, self.files))[0]
        source = self.input_folder + file
        first_row = self.rows.get(ticker, None).get(date, None)
        last_row = (self.rows.get(ticker, None).get(date_next, None) - 1) if date_next is not None else (-1)
        return pandas_helper.get_dataframe_by_rows(source, first_row, last_row)

    def get_filtered_dataframe(self, df):
        
        df.query("Type=='Trade'", inplace=True)
        #df.query("Qualifiers==' [ACT_FLAG1]'", inplace=True)
        df.loc[:,"Price"] = df["Price"].astype(float)
        df.loc[:,"Volume"] = df["Volume"].astype(int)
        return df

    def get_aggregations(self):

        for i in range(len(self.rows)):
            ticker = list(self.rows)[i]
            for j in range(len(self.rows[ticker])):
                print("Processing date " + str(j+1) + " of " + str(len(self.rows[ticker])) + " in file " + str(i+1) + " of " + str(len(self.rows)) + " ...")
                date = list(self.rows[ticker])[j]
                date_next = list(self.rows[ticker])[j+1] if j+1 < len(self.rows[ticker]) else None
                df = self.get_dataframe_per_date(ticker, date, date_next)
                df = self.get_filtered_dataframe(df)
                self.get_aggregation(df)

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

    def save_aggregations_to_csv(self):

        self.aggregations.to_csv("aggregations.csv")