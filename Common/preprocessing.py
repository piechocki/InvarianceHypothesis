import os
import re
import json
import Util.pandas_helper as pandas_helper

class PreProcessor:

    def __init__(self, input_folder):

        self.input_folder = input_folder if input_folder[-1:] == "/" else input_folder + "/"
        self.files = []
        for file in os.listdir(self.input_folder):
            if file.endswith(".csv.gz") and ".TQ_" in file:
                self.files.append(file)
        self.rows = {}
        self.aggregations = pandas_helper.get_empty_aggregation()
        # .BS_
        # .TQ_
        # .CHI_
    def init_rows_per_date(self):

        rows = {}
        for i in range(len(self.files)):
            print("Processing file " + str(i+1) + " of " + str(len(self.files)) + " ...")
            source = self.input_folder + self.files[i]
            ticker = self.files[i].split('_')[1]
            rows[ticker] = pandas_helper.get_dates_with_first_row(source)                
        self.rows = rows

    def get_dataframe_per_date(self, ticker, date):
        
        r = re.compile(r"(\w*)_" + ticker + "_(\w*)")
        file = list(filter(r.match, self.files))[0]
        source = self.input_folder + file
        rows = self.rows.get(ticker, None).get(date, None)
        return None if rows is None else pandas_helper.get_dataframe_by_rows(source, rows[0], rows[1])

    def get_filtered_dataframe(self, df):
        
        df.query("Type=='Trade'", inplace=True)
        #df.query("Qualifiers==' [ACT_FLAG1]'", inplace=True)
        df.loc[:,"Price"] = df["Price"].astype(float)
        df.loc[:,"Volume"] = df["Volume"].astype(int)
        return df

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